# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

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
