---
name: add-release
description: Add or update the release workflow - a vX.Y.Z tag checks the version, builds the release files and publishes the GitHub release. Idempotent and safe on an existing repository. Use when asked to add or update the release setup of a repository.
disable-model-invocation: true
---

# Add `release`

1. Read the `release` section of `${CLAUDE_PLUGIN_ROOT}/reference/features.md` and
   `.github/personal-rules.yml` (if the record is missing, create it as the reference says, after
   the user confirms the guess).
2. Audit only the `release` items and show what is `ok`, `differs` or `missing`. If all are `ok`,
   say so and stop. A `release.yml` without the personal-rules header is the project's own: propose
   adding `release` to `custom` and audit its contract (reference, "Custom workflows"); never
   replace it with the template unless the user asks and the template does everything it does.
3. For `android`, list the `ANDROID_*` secrets that `gh secret list` does not show; never set secrets yourself.
4. In a worktree, apply the fix for each item that is not `ok`, keeping the project's own
   additions; in a `custom` workflow, as edits the user agreed to. Add `release` to `features` in
   the record and set its `version` to the plugin's.
5. Commit (`ci: add release` for workflows, `chore: add release` otherwise) and merge by the
   repository's stage.
