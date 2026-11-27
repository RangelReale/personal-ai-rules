# Checking for a new version through GitHub Releases

Research notes (2026-11-27) on how apps usually tell their users that a newer version is out, using
the GitHub release of the app's own repository as the source of truth. The goal is a generic
approach that can be added to apps in several languages (Rust, Go, C++/Qt, Kotlin/Android, iOS),
the same way this repository already standardises CI and releases.

The notes come from general knowledge of the tools named here, not from a fresh check of each one.
Check a library's current README before depending on it.

## Summary

- **No single standard exists.** Every ecosystem has its own updater, but they nearly all use the
  same two GitHub building blocks: the "latest release" API and the stable
  `releases/latest/download/<asset>` URL.
- **Telling the user an update exists (notify-only) is the cheap, portable part.** Downloading and
  installing the update yourself (self-update) depends on the platform: signing, installer formats
  and store rules. Several platforms forbid it outright.
- **Recommended generic design:** each release publishes a small manifest asset (`update.json`).
  Each app has a thin client that fetches it at most once a day, compares versions as semver and
  shows the release notes with a download link. It is notify-only by default, with self-update only
  where a mature per-platform tool already does it.

## 1. GitHub's building blocks

| Endpoint | What it gives | Limits |
|---|---|---|
| `GET https://api.github.com/repos/{owner}/{repo}/releases/latest` | JSON: `tag_name`, `name`, `body` (release notes, Markdown), `html_url`, `published_at`, `assets[]` (`name`, `browser_download_url`, `size`, `digest` on newer releases) | Unauthenticated: 60 requests/hour per IP. Skips drafts **and prereleases**. |
| `GET https://api.github.com/repos/{owner}/{repo}/releases?per_page=N` | The newest releases, prereleases included | Same rate limit. Needed for a "beta channel". |
| `HEAD https://github.com/{owner}/{repo}/releases/latest` | A 302 redirect whose `Location` ends in `/releases/tag/<tag>` | Not part of the REST API's rate limit; not a documented API, so treat it as a fallback. |
| `https://github.com/{owner}/{repo}/releases/latest/download/<asset>` | Redirects to that asset of the latest release | Stable URL. Most manifest-based updaters use this. |
| `https://github.com/{owner}/{repo}/releases.atom` | Atom feed of releases | For feed readers; not usually used by apps. |

Notes:

- Send `Accept: application/vnd.github+json` and a `User-Agent` (the API rejects requests without
  one). Use a generic product name, never the user's details.
- Handle `403`/`429` (rate limit) and network failures quietly: a failed check must not bother the
  user.
- Never ship a GitHub token in an app. Unauthenticated access is enough for public repositories.
  For private ones, use a public mirror or a proxy instead.
- Shared NAT (offices, mobile carriers) can exhaust the 60/hour limit. The manifest-asset approach
  (below) avoids the API entirely: release asset downloads are served from a CDN.

## 2. The manifest pattern

Mature updaters do not parse asset names. They publish a **manifest** with each release and fetch
it from the stable URL:

| Ecosystem | Manifest | Fetched from |
|---|---|---|
| Tauri (updater plugin) | `latest.json`: `version`, `notes`, `pub_date`, `platforms.{os-arch}.{url,signature}` | Any URL; often `releases/latest/download/latest.json` |
| Electron (`electron-updater`, electron-builder) | `latest.yml`, `latest-mac.yml`, `latest-linux.yml`: version, files, sha512 | GitHub provider, release assets |
| Sparkle (macOS) / WinSparkle (Windows) | `appcast.xml` (RSS with Sparkle tags; EdDSA signature per item) | Any URL: GitHub Pages or a release asset |
| AppImage | Update info embedded in the AppImage: `gh-releases-zsync\|owner\|repo\|latest\|App-*-x86_64.AppImage.zsync` | Release assets; delta updates with zsync |
| Velopack (.NET, also other languages through its CLI) | `releases.{channel}.json` plus full and delta packages | `GithubSource`, release assets |
| cargo-dist / axoupdater (Rust) | dist-manifest in the release | GitHub releases |

A manifest lets one release describe every platform: a per-platform URL, a checksum, a signature,
the minimum OS and the release notes. The app then never depends on asset-naming conventions or on
the REST API.

## 3. Libraries per language

### Rust
- **`update-informer`**: notify-only. Checks GitHub (and crates.io and others), caches the result
  for an interval in a file, and compares semver. Very small.
- **`self_update`**: downloads the matching release asset and replaces the running binary. Good
  for CLIs, weak for GUI apps that ship as installers or bundles.
- **`axoupdater`**: pairs with cargo-dist releases; library and CLI.
- Rolling your own: `ureq`/`reqwest` + `serde_json` + `semver` is about 50 lines.

### Go
- **`creativeprojects/go-selfupdate`**: detects the latest release, picks the asset by OS/arch,
  verifies a checksum or signature, replaces the binary.
- Older: `rhysd/go-github-selfupdate` (unmaintained; prefer the fork above).
- Notify-only: `net/http` + `golang.org/x/mod/semver`.

### C++ / Qt
- No dominant library. Usual options: a `QNetworkAccessManager` GET of the API or of a manifest,
  then `QVersionNumber` to compare.
- Self-update: Sparkle (macOS) and WinSparkle (Windows) are the standard native choices. The Qt
  Installer Framework has its own maintenance tool and repository format.

### Electron / Tauri / .NET
- Electron: `electron-updater` (GitHub provider), or `update.electronjs.org` for public repos.
- Tauri: `tauri-plugin-updater` with a signed `latest.json` (signing is required).
- .NET: Velopack (successor to Squirrel.Windows/Clowd.Squirrel).

### Android
- **Play Store apps:** Play policy forbids an app from downloading and installing its own APKs.
  Use the Play In-App Updates API (`com.google.android.play:app-update`), or show nothing.
- **Sideloaded APKs (GitHub releases):**
  - Notify-only: fetch the manifest and open the APK's URL in the browser. This needs no
    special permission.
  - Self-install: download the APK and hand it to `PackageInstaller`. This needs
    `REQUEST_INSTALL_PACKAGES`, which the user must allow per app. The new APK must be signed
    with the same key.
  - **Obtainium** (a third-party app) tracks GitHub releases on the user's side and installs
    updates, so the app needs no code. Its users add the repository URL. Worth recommending in the
    README.
  - F-Droid does its own updates for apps it builds.
- A build flavour or flag should turn the check off for store builds.

### iOS
- Updates come from the App Store or TestFlight. An app may not install code itself.
- At most, notify: compare with the GitHub release (or the App Store lookup API,
  `https://itunes.apple.com/lookup?bundleId=...`) and link to the store. Most apps don't bother.
  Sideloaded installs (AltStore, SideStore) have their own source feeds.

### Linux packages
- Distribution packages, Flatpak and Snap update through their own managers. A built-in check
  should be off in those builds (packagers often patch it out), or limited to a notice.

## 4. Practices common to good implementations

1. **When to check:** in the background shortly after startup, at most once every 24 h. Store the
   last check time and result in the app's settings/cache, never blocking start-up or the UI.
2. **Opt-out (or opt-in):** a setting "Check for updates automatically", plus a manual "Check
   now". Some packagers and privacy-minded users require it to be off by default; decide per app,
   but always provide the switch.
3. **Version comparison:** strip a leading `v` from the tag and compare as **semver**, not as
   strings. Ignore prereleases (`-rc.N`) unless the user picked a beta channel; the `/latest`
   endpoint already skips releases marked as prerelease.
4. **Skip this version:** let the user dismiss a version so it is not shown again until a newer one
   appears.
5. **What to show:** version, date, the release notes (the GitHub `body`, or `notes` from the
   manifest, rendered as Markdown or plain text), and one button: "Download" (opens the browser)
   or "Update" (where self-update exists).
6. **Fail silently:** offline, a rate limit or a bad response means "no news". Log it, never show
   a dialog for it.
7. **Integrity:** self-update must verify a **signature** (minisign/EdDSA, platform code-signing),
   not only a checksum published next to the file: whoever can change the release can change the
   checksum. Notify-only needs neither, because the browser download goes through the normal
   OS signing and notarisation checks.
8. **Platform rules:** disable or restrict the check in store builds (Play, App Store, Microsoft
   Store, Flathub, distribution packages).
9. **Privacy:** the request carries only the app's generic User-Agent and version. No IDs or
   analytics piggy-backed on it, and no personal details in URLs.
10. **Testability:** the URL of the manifest/API should be overridable (an environment variable or
    a debug setting), so a test can point it at a local file or a fake server.

## 5. A generic design for these repositories

Repositories that follow these rules already release through a `v<version>` tag, a release
workflow and release notes taken from `CHANGELOG.md`. Building on that:

### 5.1 Release side (shared, in the reusable release workflow)
Add an optional step that generates **`update.json`** and uploads it as a release asset:

```json
{
  "schema": 1,
  "version": "1.4.0",
  "tag": "v1.4.0",
  "published": "2026-11-27T12:00:00Z",
  "prerelease": false,
  "notes": "### Added\n- ...",              // the version's CHANGELOG.md section
  "url": "https://github.com/owner/repo/releases/tag/v1.4.0",
  "assets": {
    "windows-x86_64": { "url": "...", "sha256": "...", "size": 123 },
    "macos-aarch64":  { "url": "...", "sha256": "...", "size": 123 },
    "linux-x86_64":   { "url": "...", "sha256": "...", "size": 123 },
    "android":        { "url": "...", "sha256": "...", "size": 123 }
  }
}
```

The `//` comment is only for this example; the real file is plain JSON.

- Apps fetch `https://github.com/{owner}/{repo}/releases/latest/download/update.json`. That is a
  CDN-backed download, so the REST API rate limit does not apply, and prereleases are skipped
  because "latest" excludes them.
- The platform keys are a fixed vocabulary (`{os}-{arch}` plus `android`/`ios`), mapped from asset
  names by the workflow so the apps never parse asset names.
- Optional later: a signature of `update.json` (minisign) for apps that self-update.
- Fallback for repositories without the manifest: the REST `releases/latest` endpoint, with the
  same fields mapped from `tag_name`, `body`, `html_url` and `assets`.

### 5.2 App side (one small client per language, same behaviour)
Same contract in each language:

```
check(current_version, manifest_url, state) -> NoUpdate | UpdateAvailable{version, notes, url, asset?}
```

- Respect `state.last_check` (24 h), `state.skipped_version` and `state.enabled`. Return
  `NoUpdate` on any error.
- Compare with semver. Pick the asset for the running platform; if there is none, link the
  release page.
- The UI is the app's own; the client only returns data. It takes a URL override for tests.

Implementations to write, smallest first:

| Language | Building blocks |
|---|---|
| Rust | `ureq` (blocking, in a thread) or the app's existing HTTP client, `serde_json`, `semver` |
| Go | `net/http`, `encoding/json`, `golang.org/x/mod/semver` |
| C++/Qt | `QNetworkAccessManager`, `QJsonDocument`, `QVersionNumber` |
| Kotlin/Android | `HttpURLConnection` or OkHttp, `org.json`, a small semver compare; off in Play builds; opens the APK URL with an `ACTION_VIEW` intent |
| iOS | Off by default; if wanted, `URLSession` + link to the App Store or TestFlight |

Self-update stays out of the generic part. Where an app needs it, use the platform's mature tool
(Sparkle/WinSparkle, AppImageUpdate, Velopack, `self_update`/`go-selfupdate` for CLIs,
`PackageInstaller` for sideloaded Android) and let it read the same release.

### 5.3 Fit with this repository
- Natural homes: a `features.md` entry (for example `update-check`) describing what a repository
  with the feature holds (the manifest step in the release workflow, a client in the app, a setting
  and a changelog entry), a reusable-workflow input that turns the manifest step on, and per-language
  notes in the `rust`/`go`/`cpp`/`android` skills.
- Test plan: a unit test of version comparison and the 24 h throttle in each client, and a release
  dry run that checks `update.json` against a JSON Schema.

## 6. Open questions for whoever implements it

- Opt-in or opt-out by default? It may differ between desktop apps and CLIs.
- Is a beta channel needed? That needs a second manifest (`update-beta.json`) or the
  `releases?per_page=` API, because `/latest` hides prereleases.
- Should `notes` be Markdown (needs a renderer in each app) or plain text produced by the workflow?
- Should `update.json` be signed now, or only when the first app self-updates?
- Where does a Rust/Go/Kotlin client live so apps can share it: a published crate/module/library, or
  a template the `add-*` command copies into each app?
