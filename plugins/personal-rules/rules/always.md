# Personal rules (always on)

These rules come from the `personal-rules` plugin and apply to every repository. A repository's own
`CLAUDE.md` or `AGENTS.md` wins where it conflicts.

## Worktrees

- **Make every change in a git worktree, never in the main checkout.** Several sessions often work in
  one repository; a shared checkout lets them overwrite each other's files and commits.
- Before the first edit to a tracked file, call `EnterWorktree` (it creates `.claude/worktrees/<name>`
  on a new branch). Without that tool: `git worktree add -b <branch> .claude/worktrees/<branch> master`.
- Keep the main checkout on a clean `master` (or `main`): never edit, build, switch branches or commit
  there.
- Subagents that write code start with `isolation: "worktree"`; read-only agents may share a checkout.
- Read-only work (reading code, answering questions) needs no worktree.
- After the merge: remove the worktree (`ExitWorktree` with `remove`, or `git worktree remove`) and
  delete the branch.

## Commits

- **Commit as you go**, without being asked: one focused commit per finished piece (a component, a
  fix, a set of docs). An uncommitted tree cannot be reviewed, bisected or partly undone.
- **Conventional Commits**: `type(scope): summary`, summary in lower case, imperative, no period.
  Types: `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`. Breaking change:
  `type!:` plus a `BREAKING CHANGE:` footer.
- Stage files by name; never `git add -A` or `git add .` (other sessions' files must not leak in).
- Do not raise pinned versions (toolchains, dependencies, actions) as a side effect of other work;
  raise them in a change of their own.

## Merging: follow the repository's stage

Read `.github/personal-rules.yml`. Its `stage` decides how work reaches `master`:

- `stage: early`: no pull requests, no CI. Merge the worktree's branch locally with
  `git merge --no-ff <branch>` in the main checkout (after `git pull --ff-only`), then push `master`.
- `stage: established`: `master` is protected. Push the branch, open a pull request
  (`gh pr create`), and merge it with `gh pr merge --merge` (never squash, never rebase) once the
  `CI result` check passes and the branch is up to date with `master`. Do not pass
  `--delete-branch` from a worktree; delete the branch after removing the worktree.
- No file: follow the repository's `CLAUDE.md`; if it says nothing, ask before merging, and suggest
  `/personal-rules:check`.

When the user asks to "mmp" (merge and push), load the `personal-rules:mmp` skill: it does the
whole run for either stage, from commit to cleanup.

You may push work branches, open pull requests, merge them as above, and push release tags without
asking. Never force-push, never push to a protected `master`, never rewrite pushed history.

## CI runs only what a change needs

CI time is expensive. When a change adds a folder, a sub-project or a CI job, update the path
rules of `changes` in `.github/workflows/ci.yml` in the same change (`ignore`, `components`,
`groups`), so documentation, tooling and unrelated parts do not start builds. Pull requests build on
Linux; the full platform matrix runs on master and on toolchain, lockfile or workflow changes.

## Releases

- The tag `vX.Y.Z` (or `vX.Y.Z-rc.N`, published as a prerelease) is the version. Where the language
  keeps a version in a manifest (`Cargo.toml`, CMake `project(VERSION)`, `plugin.json`), the
  release CI fails unless it matches the tag.
- A version change touches only version strings and the changelog, in a change of its own, so CI can
  skip the full build. Use `/personal-rules:release`.
- Tag only commits on `master`, after the version change is merged.

## Changelog

If `changelog.d/` exists, every change that people who use the project would notice adds a fragment
`changelog.d/<branch>.<type>.md` (`type`: added, changed, deprecated, removed, fixed, security).
Never edit `CHANGELOG.md` directly; only a release merges the fragments.

## Nothing committed describes the local machine

No tracked file may name a local drive or folder, a LAN address, personal hardware, or a person's
private details (code, docs, comments, test data, images). Put such facts in `CLAUDE.local.md` or
`local/`, both gitignored. Use invented samples such as `<your projects folder>`.

## Working style

- Check a change on a real target (build, tests, the app running) before calling it done, and say
  plainly what was not checked.
- Keep instructions files (`CLAUDE.md`, `AGENTS.md`, skills) concise and imperative: say what to do
  and why, in one line where possible.
- **Push notification at each milestone**: when a feature or multi-step piece of work is complete, a
  long build/test/release finishes (especially a failure), or you are blocked on a decision. Lead with
  what to act on, under 200 characters ("M6 done, 544 tests green, merged a85241e"). Not for routine
  progress or quick answers.

## Language skills

For Android (Kotlin), Rust, Go and C++ (Qt/CMake) code, the `personal-rules` skill for that
language holds the build and code rules; load it before changing code there. A repository has one
main language (it holds the version) and may have components in sub-folders, such as an Android or
iOS app on a Rust or Go core (`components:` in `.github/personal-rules.yml`); load the skill of
each part you change.
