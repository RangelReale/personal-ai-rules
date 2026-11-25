---
name: release
description: Cut a release - raises the version (patch, minor or major), merges the changelog fragments, gets the version change onto master by the repository's stage, then pushes the vX.Y.Z tag that starts the release workflow. Use when asked to release, cut a release or tag a version.
argument-hint: "patch | minor | major | X.Y.Z[-rc.N]"
disable-model-invocation: true
---

# Release

1. Read `.github/personal-rules.yml` (stage, language, features). Find the last version from the
   latest `v*` tag (`git describe --tags --abbrev=0 --match 'v[0-9]*'`), or `0.0.0`.
2. Work out the new version from the argument; with no argument, ask (patch / minor / major /
   exact), showing the fragments in `changelog.d/` to help choose. Refuse a version that is not
   greater than the last one.
3. In a worktree on branch `release-<version>`, make the version change, and nothing else:
   - `rust`: `[workspace.package] version` (or `[package] version`), then refresh `Cargo.lock`
     with `cargo metadata --format-version 1 > /dev/null`;
   - `cpp`: `project(... VERSION X.Y.Z ...)` in `CMakeLists.txt` (without the prerelease part),
     unless the release uses a `version-define`;
   - other manifests the release checks (`version-files` in `.github/workflows/release.yml`);
   - `go`, `android`: nothing, the tag is the version;
   - `changelog`: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/changelog.sh" release <version>` merges
     the fragments into `CHANGELOG.md` and deletes them.
4. Commit: `chore(release): v<version>`.
5. Get it onto `master` by stage: `early` → local `--no-ff` merge and push; `established` → push,
   `gh pr create --title "chore(release): v<version>"`, wait for `CI result` (version-only, so it
   is quick), `gh pr merge --merge`.
6. Update the main checkout (`git pull --ff-only`), then tag the merge commit on `master` and push
   only the tag:
   `git tag -a v<version> -m "v<version>" && git push origin v<version>`.
7. Watch the `Release` run (`gh run watch`), then report the release URL
   (`gh release view v<version> --json url`) and send a push notification with the outcome.
8. Clean up the worktree and the branch.
