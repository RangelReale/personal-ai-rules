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
language: rust        # the main language: android | rust | go | cpp | none
features: [release, changelog]   # any of: ci, release, changelog, dependabot, license
release-environment: release     # environment with the signing secrets; '' = repository secrets
components:           # other parts, each in its own folder, built on the main code
  - name: android
    language: android # android | ios
    path: apps/android
    native: rust      # android only: rust | go | none
```

**Main language and components.** Most repositories have one main language at the root: it holds
the version, its CI job is `build`, and its release job builds the main files. Apps for other
platforms in sub-folders (an Android app on a Rust library, an iOS port of a Go server) are
components: each gets its own CI and release job, gated on its folder or the main code changing, and
takes its version from the tag. A component's `name` names its jobs and artifacts.

Missing record: survey the repository and show the guess; write the file only after the user
confirms.
- Main language: the manifest at the root (`Cargo.toml`, `go.mod`, `CMakeLists.txt`, or
  `settings.gradle.kts`/`build.gradle.kts` for a standalone Android app).
- Components: every folder below the root with a `gradlew` (android; `native` from the main
  language when its build copies a library into `jniLibs`), or an iOS project (`*.xcodeproj`,
  `project.yml`, `Package.swift`) with a `build.sh` (ios). Typical folders: `android/`,
  `apps/<name>-android`, `ports/android`, `ports/ios`.
- Features: from the files below. Stage: `established` if `master` has a ruleset or branch
  protection, else `early`.
- `release-environment`: `release` if the repository has that environment
  (`gh api repos/{owner}/{repo}/environments`), else `''`. An existing repository keeps its
  repository secrets unless the user chooses to move them (see "Release environment").

**Release environment.** New repositories keep their signing secrets in the GitHub environment
`release` (the record's default): only jobs that declare it can read them, and it admits only
release tags. Existing repositories may keep repository secrets (`release-environment: ''`).
Secret values cannot be read back or copied, so moving them means entering each value again
(`gh secret set <NAME> --env release`) and then deleting the repository secret; only the user can
do that. A lost value cannot be moved: it must be rotated (for Android, a new signing key breaks
updates over installed apps).

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
| `local-skills` | no `.claude/skills/<name>` duplicates a plugin command (`mmp`, `release`) | report it; the plugin's `/personal-rules:<name>` works by stage. Remove the local copy only on the user's yes, after carrying its repository-specific steps (extra checks, labels, required check names) into `CLAUDE.md` |

## Language items (the main language, and each component)

Check the basics the language skill (`skills/<language>/SKILL.md`) requires; report, do not rewrite
code. For a component, check inside its `path`.

- `android`: `gradle/libs.versions.toml`; `gradlew` executable in git (`git ls-files -s gradlew`
  shows `100755`); no hard-coded `versionName`/`versionCode` (they come from `-PappVersion`).
  As a component with `native`: the generated `jniLibs/` is gitignored, and a Taskfile task builds
  the native library and the APK in one go.
- `ios` (component only): one command that builds it without signing (a `build.sh` in its `path`
  or a Taskfile task; the CI job runs it); generated Xcode projects (`project.yml` with XcodeGen)
  and build outputs gitignored. There is no iOS skill: the repository's `CLAUDE.md` holds the iOS
  specifics.
- `rust`: `rust-toolchain.toml` with an exact `channel`; `rust-version` equals it;
  `[workspace.package] version` (or `[package] version`); `Cargo.lock` committed for applications.
- `go`: `go.mod` with a `go` line; `gofmt -l .` prints nothing.
- `cpp`: `CMakePresets.json`; `scripts/setup.sh` and `scripts/setup.ps1`; `project(... VERSION ...)`.

## Features

### `ci`

- `.github/workflows/ci.yml` equals `templates/workflows/ci-<language>.yml` (`ci-generic.yml` for
  `none`) with the rules ref filled in, apart from the options the project set in `with:` and the
  component jobs below.
- The build job passes `full` (see "Path rules" below); Rust also passes `deny` from the `deps`
  group.
- Must have: the `run-name` expression (`PR #<n>: <title>`), `pull_request` types including
  `labeled` and `unlabeled`, `changes` → `build` gated on `needs.changes.outputs.main == 'true'`,
  the `changelog` job (it passes when there is no `changelog.d/`), and the `ci-result` job named
  `CI result` with `if: always()` needing every other job.
- Components: `changes` gets `components:` with one `<name>: <path>` line per component, and each
  component has the job of `templates/workflows/ci-component-<language>.yml` (placeholders
  `__NAME__`, `__PATH__`, `__NATIVE__` filled; the commented `pre-build` set from the repository's
  own native build, for example its Taskfile), listed in `ci-result`'s `needs`.
- The ref is a tag of this repository; an older tag than the plugin's is `differs` (offer the
  upgrade, and read this repository's `CHANGELOG.md` for what changed).
- Not allowed in stage `early` unless the user asks: early projects have no CI.

**Path rules: CI runs only what a change needs.** CI time is the main cost of these repositories,
so every CI setup gets path rules fitted to the repository, and they are kept up to date (`check`
compares them with the tree). Survey the tree and propose, for the user to confirm:
- `ignore`: folders and files that no build or test reads, beyond the built-in list (`*.md`,
  `docs/`, `LICENSE*`, `.claude/`, `.vscode/`, `.idea/`, `.editorconfig`, `.gitignore`, issue
  templates, `dependabot.yml`, `personal-rules.yml`): a web site (`site/`), screenshots, design
  notes, developer scripts no job runs (`tools/dev/`), `Taskfile.yml` when CI does not use it. Read
  the workflows and build files before ignoring a path: anything a job or the build reads is code.
- `components`: every sub-project in the record, so changes there skip the main build.
- `groups`: a signal for each job that only some files need (`deps: Cargo.lock deny.toml` for
  `cargo deny`; `assets: assets/` for an asset build; `web: web/` for a front end built apart), and
  gate that job on `contains(fromJSON(needs.changes.outputs.groups), '<name>')`.
- `full-paths`: files beyond the built-in list (workflows, toolchain pins, lockfiles,
  `CMakePresets.json`, `.gitattributes`) that can break one platform and not another.
- The build jobs pass `full: ${{ needs.changes.outputs.full }}`: pull requests build on Linux only,
  and the whole platform matrix runs on pushes to the default branch and on `full` changes. A C++
  project without a `linux` preset passes its Windows entry as `quick-matrix`.
- After a change adds a folder or a job, update the rules in the same change.
`check` reports a folder that no rule covers and no build reads (`⚠️ ci  differs: site/ triggers
builds`), and a rule whose paths no longer exist.

### `release`

- `.github/workflows/release.yml` equals `templates/workflows/release-<language>.yml`, ref filled
  and `__RELEASE_ENVIRONMENT__` set to the record's `release-environment`.
- Version files: `rust` → `Cargo.toml`; `cpp` → `CMakeLists.txt` (or a `version-define`); `go` and
  `android` → none (the tag is the version). Components never hold a version of their own.
- Components: each has the job of `templates/workflows/release-component-<language>.yml`, listed
  in `publish`'s `needs`.
- Release environment (when `release-environment` is not empty and a release job signs): the
  environment exists; create it, after asking, with
  `gh api -X PUT repos/{owner}/{repo}/environments/release`, then limit it to release tags:
  `gh api -X PUT repos/{owner}/{repo}/environments/release -F "deployment_branch_policy[protected_branches]=false" -F "deployment_branch_policy[custom_branch_policies]=true"`
  and `gh api -X POST repos/{owner}/{repo}/environments/release/deployment-branch-policies -f name='v*' -f type=tag`.
- Android (main or component): the four `ANDROID_*` secrets exist where the record says
  (`gh secret list --env release`, or `gh secret list` for repository secrets). Report missing
  ones with the command to set them; never set or move secrets yourself. Secrets at the repository
  level while the record names an environment (or the reverse) are `differs`: explain the move in
  "Release environment" and let the user choose to move them or change the record.

### `changelog`

- `changelog.d/README.md` equals `templates/repo/changelog.d-README.md`.
- `CHANGELOG.md` exists (create the Keep a Changelog header when missing).
- With `ci`: the `changelog` job is in `ci.yml`.
- The `no-changelog` label exists (`gh label list`); create it with
  `gh label create no-changelog --description "No user-visible change"`.

### `dependabot`

- `.github/dependabot.yml` has the `github-actions` entry of `templates/github/dependabot.yml`
  (with the `no-changelog` label); keep other ecosystems the project added.

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

One line per item, grouped (Base, Language and components, Features, Stage):

```
✅ gitattributes        ok
⚠️ ci                   differs: run-name missing; ref v0.1.0 < v0.3.0
❌ changelog            missing: changelog.d/README.md
➖ dependabot           not a feature of this repository
```

Then ask which of the `⚠️`/`❌` items to fix (all, a list, or none). Fix, update `version` in the
record, and commit the fixes as `chore: apply personal-rules <version>` (or one commit per
feature when there are many).
