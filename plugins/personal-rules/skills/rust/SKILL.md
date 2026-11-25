---
name: rust
description: Build and code rules for Rust projects and Cargo workspaces. Use when working in a repository with Cargo.toml or rust-toolchain.toml, or when creating, building, testing, linting or releasing Rust code.
---

# Rust rules

## Toolchain and workspace

- Pin the toolchain exactly in `rust-toolchain.toml` (`channel = "1.98.1"`,
  `components = ["rustfmt", "clippy"]`), and set `rust-version` to the same version. A floating
  channel lets a new clippy lint fail CI on a branch that changed nothing. Raise the pin in a
  change of its own.
- Edition 2024. The version lives once, in `[workspace.package] version`; member crates use
  `version.workspace = true`. Set `publish = false` unless a crate is published.
- Workspace lints in `[workspace.lints]` (`unsafe_code = "deny"`, `missing_docs = "warn"`,
  `clippy::todo = "warn"`); each crate has `[lints] workspace = true`.
- `[profile.release]`: `lto = "thin"`, `codegen-units = 1`. Give heavy dependencies `opt-level = 2`
  in the dev profile when debug builds are too slow to use.
- `rustfmt.toml`: `max_width = 100`.
- Commit `Cargo.lock` for applications.

## Check a change

Run what CI runs (`rust-ci.yml`), all three must pass:

```sh
cargo fmt --all --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --locked
```

Fix clippy warnings; do not `#[allow]` them without a comment saying why.

## Code

- Errors: `thiserror` in libraries, `anyhow` (with context) in binaries.
- Keep platform code behind `#[cfg(...)]` modules, so the rest builds everywhere.

## Releases

- A release changes only `[workspace.package] version`, the workspace crates' entries in
  `Cargo.lock` (refresh with `cargo metadata --format-version 1 > /dev/null`) and the changelog.
  CI sees that as a version-only change and skips the builds.
- The release fails unless the tag is `v<workspace version>` (`release-check.yml`).
- Licence: MIT, in `LICENSE` and `license = "MIT"` in `[workspace.package]`.
