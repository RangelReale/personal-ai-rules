# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [0.4.0] - 2026-11-25

### Added

- `custom: [ci, release]` in `.github/personal-rules.yml` marks workflows a repository writes
  itself: `check` audits what the rules rely on (the required check, path rules, tag and version
  checks, every component built) and never replaces them with a template. A workflow without the
  personal-rules header is never replaced either.
- `ci-check` in the record names the required check when it is not `CI result`; `establish`,
  `release` and merging use it.
- Components of `language: other` (a TV, console or other platform port) with a `build` command
  and one or more paths, new `ci-component-other.yml` and `release-component-other.yml` jobs, and a
  survey that finds Tizen, webOS and other platform ports.

## [0.3.1] - 2026-11-25

### Fixed

- `/personal-rules:mmp` ignores the failed CI result a cancelled run leaves behind and waits for
  the newer run, instead of stopping as if a required check had failed.
- The changelog check allows adding CHANGELOG.md, so a repository can set up its changelog in a
  pull request.

## [0.3.0] - 2026-11-25

### Added

- `/personal-rules:check standard` also adds the standard features a repository lacks (release and
  changelog), and `check` ends its report with the features not opted in.

## [0.2.1] - 2026-11-25

### Fixed

- `/personal-rules:mmp` waits until every check of the pull request has finished, including checks
  that are not required, and stops at once when the pull request was merged or closed meanwhile.

## [0.2.0] - 2026-11-25

### Added

- `/personal-rules:mmp` merges the current worktree's work into master and pushes it, by the
  repository's stage: a local merge for early repositories, a pull request merged on a green CI result
  for established ones.

## [0.1.0] - 2026-11-25

### Added

- The `personal-ai-rules` marketplace with the `personal-rules` plugin.
- Always-on rules injected at session start: worktrees, Conventional Commits, merging by stage
  (early or established), releases, changelog fragments, no local paths, push notifications.
- Language skills for Android (Kotlin), Rust, Go and C++ (Qt/CMake).
- Faster CI: per-repository path rules (`ignore`, `components`, `groups`), Linux-only pull
  request builds with the full matrix on master and toolchain or lockfile changes, ccache for C++,
  and `cargo deny` only when dependencies change.
- Signing secrets in an optional GitHub environment, `release` by default in new repositories.
- Multi-language repositories: a main language plus Android and iOS components, each with its own
  CI and release job that runs when its folder or the main code changed.
- Commands: `new-project`, `check`, `establish`, `release`, `add-ci`, `add-release`,
  `add-changelog`, `add-dependabot`, `add-license`.
- Reusable workflows: `changes`, `go-ci`, `rust-ci`, `android-ci`, `cpp-ci`, `release-check`,
  `release-publish`, `go-release`, `rust-release`, `android-release`, `cpp-release`,
  `changelog-check`, with caller templates for each language.
