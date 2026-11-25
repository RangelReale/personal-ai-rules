---
name: add-dependabot
description: Add Dependabot updates for GitHub Actions, monthly in one grouped pull request. Idempotent and safe on an existing repository. Use when asked to add or update the dependabot setup of a repository.
disable-model-invocation: true
---

# Add `dependabot`

1. Read the `dependabot` section of `${CLAUDE_PLUGIN_ROOT}/reference/features.md` and
   `.github/personal-rules.yml` (if the record is missing, create it as the reference says, after
   the user confirms the guess).
2. Audit only the `dependabot` items and show what is `ok`, `differs` or `missing`. If all are `ok`,
   say so and stop.
3. In a worktree, apply the fix for each item that is not `ok`, keeping the project's own
   additions. Add `dependabot` to `features` in the record and set its `version` to the plugin's.
4. Commit (`ci: add dependabot` for workflows, `chore: add dependabot` otherwise) and merge by the
   repository's stage.
