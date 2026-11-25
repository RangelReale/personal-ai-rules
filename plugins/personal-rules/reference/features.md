# personal-rules: what a repository should hold

The single definition of "correct" for `/personal-rules:check`, `/personal-rules:new-project`,
`/personal-rules:establish` and the `add-*` commands. Each item has an id, what to check, and how
to fix it. Fixes are idempotent: they add what is missing and keep the project's own additions.

Paths: `${CLAUDE_PLUGIN_ROOT}` is this plugin's folder; templates are in
`${CLAUDE_PLUGIN_ROOT}/templates/`.

**Rules ref.** Caller workflows pin this repository's reusable workflows to a tag. The ref is
`v` + the `version` in `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`; replace every
`__RULES_REF__` in a template with it (for example `v0.1.0`).

## The record: `.github/personal-rules.yml`

```yaml
version: 0.1.0        # personal-rules version last applied
stage: early          # early | established
language: rust        # android | rust | go | cpp | none
features: [release, changelog]   # any of: ci, release, changelog, dependabot, license
```

Missing: survey the repository (language from `build.gradle.kts`/`Cargo.toml`/`go.mod`/
`CMakeLists.txt`; features from the files below; stage `established` if `master` has a ruleset or
branch protection, else `early`), show the guess, and write the file only after the user confirms.

## Base items (every repository, every stage)

| id | check | fix |
|---|---|---|
| `record` | `.github/personal-rules.yml` exists and parses; `version` is not newer than the plugin | write it (see above) |
| `gitignore` | `.gitignore` has every line of `templates/repo/gitignore` | append the missing lines, with the comment |
| `gitattributes` | `.gitattributes` exists and starts with a `* text=auto` rule | copy `templates/repo/gitattributes`; if one exists, add only missing lines |
| `editorconfig` | `.editorconfig` exists | copy `templates/repo/editorconfig` |
| `claude-md` | `CLAUDE.md` (or `AGENTS.md` imported by it) exists with a Commands section | create from `templates/repo/CLAUDE.md`, filled from what the repository shows; ask the user for what you cannot tell |
| `readme` | `README.md` exists and says what the project is | write a short one: name, one paragraph, how to install or build, license |
| `local-refs` | no tracked file names a local path, LAN address or personal detail (`git grep -nIE '[A-Za-z]:\\\\(Users\|prog)\|/Users/[a-z]\|/home/[a-z]\|192\\.168\\.'`) | report each hit; move the fact to `CLAUDE.local.md` or replace it with an invented sample |
| `default-branch` | the default branch is `master` or `main` | report only |

## Language items (`language` is not `none`)

Check the basics the language skill (`skills/<language>/SKILL.md`) requires; report, do not rewrite
code.

- `android`: `gradle/libs.versions.toml`; `gradlew` executable in git (`git ls-files -s gradlew`
  shows `100755`); no hard-coded `versionName`/`versionCode` (they come from `-PappVersion`).
- `rust`: `rust-toolchain.toml` with an exact `channel`; `rust-version` equals it;
  `[workspace.package] version` (or `[package] version`); `Cargo.lock` committed for applications.
- `go`: `go.mod` with a `go` line; `gofmt -l .` prints nothing.
- `cpp`: `CMakePresets.json`; `scripts/setup.sh` and `scripts/setup.ps1`; `project(... VERSION ...)`.

## Features

### `ci`

- `.github/workflows/ci.yml` equals `templates/workflows/ci-<language>.yml` (`ci-generic.yml` for
  `none`) with the rules ref filled in, apart from the commented `with:` options the project set.
- Must have: the `run-name` expression (`PR #<n>: <title>`), `changes` → `build` gated on
  `needs.changes.outputs.code == 'true'`, and the `ci-result` job named `CI result` with
  `if: always()` needing every other job.
- The `# >>> changelog` … `# <<< changelog` block is present exactly when `changelog` is a feature.
  Without it, also remove `changelog` from `ci-result`'s `needs`.
- The ref is a tag of this repository; an older tag than the plugin's is `differs` (offer the
  upgrade, and read this repository's `CHANGELOG.md` for what changed).
- Not allowed in stage `early` unless the user asks: early projects have no CI.

### `release`

- `.github/workflows/release.yml` equals `templates/workflows/release-<language>.yml`, ref filled.
- Version files: `rust` → `Cargo.toml`; `cpp` → `CMakeLists.txt` (or a `version-define`); `go` and
  `android` → none (the tag is the version).
- Android: the four `ANDROID_*` secrets exist (`gh secret list`); report missing ones, never set
  them yourself.

### `changelog`

- `changelog.d/README.md` equals `templates/repo/changelog.d-README.md`.
- `CHANGELOG.md` exists (create the Keep a Changelog header when missing).
- With `ci`: the changelog block is in `ci.yml`.
- The `no-changelog` label exists (`gh label list`); create it with
  `gh label create no-changelog --description "No user-visible change"`.

### `dependabot`

- `.github/dependabot.yml` has the `github-actions` entry of `templates/github/dependabot.yml`;
  keep other ecosystems the project added.

### `license`

- `LICENSE` is the MIT text of `templates/repo/LICENSE-MIT` (`__YEAR__`: the year of the first
  commit, or this year for a new repository). Rust: `license = "MIT"` in `[workspace.package]`.
- An existing different license: report only; never replace it.

## Stage `established`

- `ci` is a feature.
- A ruleset protects the default branch with the content of `templates/github/ruleset-master.json`:
  `gh api repos/{owner}/{repo}/rulesets` lists it; compare its rules
  (`gh api repos/{owner}/{repo}/rulesets/<id>`). Classic branch protection with the same effect
  counts as `ok`.
- Repository settings allow merge commits (`gh api repos/{owner}/{repo} --jq .allow_merge_commit`).
- Apply or change a ruleset only through `/personal-rules:establish`, after showing the JSON and
  getting a yes.

## Report format

One line per item, grouped (Base, Language, Features, Stage):

```
✅ gitattributes        ok
⚠️ ci                   differs: run-name missing; ref v0.1.0 < v0.3.0
❌ changelog            missing: changelog.d/README.md
➖ dependabot           not a feature of this repository
```

Then ask which of the `⚠️`/`❌` items to fix (all, a list, or none). Fix, update `version` in the
record, and commit the fixes as `chore: apply personal-rules <version>` (or one commit per
feature when there are many).
