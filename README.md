# personal-ai-rules

My reusable AI coding rules, so a new repository does not start with the same setup again. It is
two things:

- a **Claude Code plugin marketplace** (`personal-ai-rules`) with one plugin, `personal-rules`:
  always-on rules for every session, per-language skills, and commands that set up, audit and
  release a repository;
- **reusable GitHub Actions workflows** that project workflows call, pinned to a tag of this
  repository.

Other AI tools can read the same rules: see [AGENTS.md](AGENTS.md).

## Install on a new machine

In Claude Code:

```
/plugin install personal-rules --marketplace RangelReale/personal-ai-rules
```

(or `/plugin marketplace add RangelReale/personal-ai-rules`, then
`/plugin install personal-rules@personal-ai-rules`). Pick the **user** scope so it applies to
every project.

The same, in `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "personal-ai-rules": {
      "source": { "source": "github", "repo": "RangelReale/personal-ai-rules" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": { "personal-rules@personal-ai-rules": true }
}
```

Updates arrive when the plugin's `version` changes (a release). Third-party marketplaces do not
auto-update by default: turn it on as above, or in `/plugin` → Marketplaces. Check that it works by
starting a session and asking "which personal rules are active?".

Move rules that used to live in `~/.claude/CLAUDE.md` into the plugin, and keep only
machine-specific notes there.

## What applies where

| Kind | Where | How it reaches a project |
|---|---|---|
| Always-on rules | [`rules/always.md`](plugins/personal-rules/rules/always.md) | A `SessionStart` hook prints it into every session, in every repository; nothing to do per project |
| Language rules | [`skills/{android,rust,go,cpp}`](plugins/personal-rules/skills) | Skills whose descriptions match the project's files; Claude loads them when it works on that kind of code |
| Optional features | [`reference/features.md`](plugins/personal-rules/reference/features.md) | Commands below, recorded per repository in `.github/personal-rules.yml` |

**Why a hook for the always-on rules:** a plugin cannot ship a `CLAUDE.md` that loads by itself,
and an `@import` from `~/.claude/CLAUDE.md` would point into the plugin cache, whose path changes
with every version. The hook needs no per-machine or per-project step and updates with the plugin.

### Main language and components

A repository has one **main language** (Android, Rust, Go, C++, or none) that holds the version and
gets the main CI and release jobs. Apps for other platforms in sub-folders are **components**: an
Android app (`apps/<name>-android`, `ports/android`) bundling a Rust or Go native library, or an iOS
port (`ports/ios`). Each component gets its own CI and release job, which runs when its folder or the
main code changed, and takes its version from the tag. iOS exists only as a component: it has no
skill of its own, and its build is the component's own script.

```yaml
# .github/personal-rules.yml
language: rust
components:
  - { name: android, language: android, path: apps/android, native: rust }
  - { name: ios, language: ios, path: ports/ios }
```

### Release environment

Signing secrets (the Android keystore, macOS certificates) live in the GitHub environment
`release` in new repositories: only jobs that declare it can read them, and it admits only `v*`
tags. Existing repositories can keep repository secrets: `release-environment: ''` in the record.
Secret values cannot be read back, so moving them means entering each one again
(`gh secret set NAME --env release`) and deleting the repository secret. The reusable signing
workflows declare the environment themselves (callers cannot pass environment secrets) and read
the secrets by name through `secrets: inherit`.

### Stages

Each repository is in one of two stages, recorded in `.github/personal-rules.yml`:

- `early` (new projects): work in a worktree, merge locally into `master` (`--no-ff`) and push. No
  pull requests, no CI, no branch protection.
- `established`: `master` accepts only pull requests that pass the `CI result` check, merged with a
  merge commit.

`/personal-rules:establish` moves a repository from one to the other, only when you ask.

## Commands

| Command | What it does |
|---|---|
| `/personal-rules:new-project [name]` | Asks the main language (android, rust, go, cpp, none), the components (Android, iOS) and the features (release and changelog preselected), writes the base files and the record, stage `early` |
| `/personal-rules:check` | Audits the repository (base files, main language and components, opted-in features, stage) and lists each item as ok, differs or missing; fixes only what you pick. Also finds unlisted components, upgrades pinned workflow refs, and lists the features not opted in |
| `/personal-rules:check standard` | The same, and also adds the **standard features** the repository lacks: `release` and `changelog` (CI comes with `establish`, or whenever you ask for `add-ci`) |
| `/personal-rules:establish` | Adds CI, then (after you confirm the JSON) creates the `master` ruleset: pull requests only, `CI result` required |
| `/personal-rules:mmp` | Merges the current worktree's work into master and pushes, by the repository's stage: a local `--no-ff` merge for `early`, a pull request merged on a green `CI result` for `established`. Commits, adds a missing changelog fragment, runs the checks, then removes the worktree and branch. Also runs when you say "mmp" |
| `/personal-rules:release [patch\|minor\|major\|X.Y.Z]` | Raises the version, merges `changelog.d/`, lands the version change, pushes the `vX.Y.Z` tag, watches the release |
| `/personal-rules:add-ci` | The language's CI caller: `PR #<n>: <title>` run names, docs-only and version-only changes skip the build, one `CI result` check |
| `/personal-rules:add-release` | The release caller: a `vX.Y.Z` tag (or `vX.Y.Z-rc.N`, a prerelease) is checked against the manifest, built and published |
| `/personal-rules:add-changelog` | `changelog.d/` fragments, the CI check, the `no-changelog` label |
| `/personal-rules:add-dependabot` | Monthly grouped GitHub Actions updates |
| `/personal-rules:add-license` | MIT license |

Every command is idempotent: on an existing repository it adds what is missing and keeps the
project's own changes.

## Reusable workflows

Project callers live in [`templates/workflows`](plugins/personal-rules/templates/workflows)
(`ci-<language>.yml`, `release-<language>.yml`, plus `-generic` for other languages, and
`ci-component-*.yml`/`release-component-*.yml`, the jobs a component adds). They call:

| Workflow | Purpose |
|---|---|
| `changes.yml` | Classifies a change as `docs`, `version` or `code`, and says whether the main code and which components changed; builds run only for what changed |
| `go-ci.yml`, `rust-ci.yml`, `android-ci.yml`, `cpp-ci.yml` | Language checks; `android-ci` also builds an Android component with its Rust or Go native library |
| `changelog-check.yml` | Fragment names, and a fragment for every code change |
| `release-check.yml` | Tag format, manifest version equals the tag, tag on the default branch |
| `go-release.yml`, `rust-release.yml`, `android-release.yml`, `cpp-release.yml` | Release files, uploaded as `release-*` artifacts |
| `release-publish.yml` | Creates the GitHub release with the changelog section as notes and attaches the files |

### Running only what a change needs

CI speed is the point of `changes.yml`; every caller gates its jobs on it:

- **Skipped entirely:** documentation and other files no build reads (built in: `*.md`, `docs/`,
  `LICENSE*`, `.claude/`, editor settings, issue templates, `dependabot.yml`; plus the repository's
  `ignore` paths such as `site/` or `tools/dev/`), and version-only changes (a release's version
  bump and changelog).
- **Per part:** a component's job runs when its folder or the main code changed; the main build
  runs only when the main code changed.
- **Per signal:** `groups` gate jobs that only some files need, such as `cargo deny` on
  `Cargo.lock`/`deny.toml`.
- **Smaller matrix on pull requests:** pull requests build on Linux; the whole platform matrix runs
  on pushes to master and on changes that can break one platform (workflows, toolchain pins,
  lockfiles, `CMakePresets.json`).
- **Caches** are written only from master (Rust, C++ ccache), so pull requests don't evict them.

`/personal-rules:add-ci` and `/personal-rules:check` survey the tree and propose the path rules
for each repository.

Callers pin a tag: `uses: RangelReale/personal-ai-rules/.github/workflows/go-ci.yml@v0.1.0`. This
repository must stay public for repositories of other owners to call them.

## Add a language

1. Write `plugins/personal-rules/skills/<language>/SKILL.md`: a `description` naming the files that
   identify the project (so it triggers on its own), then the build, check, code and release rules.
2. Add `.github/workflows/<language>-ci.yml` (and `<language>-release.yml` if releases build files)
   with `on: workflow_call`.
3. Add the language to `LANGS` in `scripts/gen-templates.py` and regenerate the templates.
4. Add its items to "Language items" and the version files to `release` in
   `plugins/personal-rules/reference/features.md`, and the name to the `language` lists in the
   `new-project` skill and `templates/repo/personal-rules.yml`.
5. Add a changelog fragment, then release.

## Development

```sh
bash tests/run.sh                 # workflow shell logic and the changelog tool
actionlint                        # workflows (on Windows: bash scripts/lint-workflows.sh)
bash scripts/lint-templates.sh    # caller templates, including component jobs
claude plugin validate .          # marketplace and plugin
```

Releases follow these same rules: the tag `v<version>` must match `plugin.json`, and the notes come
from [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE)
