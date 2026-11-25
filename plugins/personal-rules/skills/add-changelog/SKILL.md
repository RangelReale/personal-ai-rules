---
name: add-changelog
description: Add changelog fragments - changelog.d/ with its README, CHANGELOG.md, the CI fragment check and the no-changelog label. Idempotent and safe on an existing repository. Use when asked to add or update the changelog setup of a repository.
disable-model-invocation: true
---

# Add `changelog`

1. Read the `changelog` section of `${CLAUDE_PLUGIN_ROOT}/reference/features.md` and
   `.github/personal-rules.yml` (if the record is missing, create it as the reference says, after
   the user confirms the guess).
2. Audit only the `changelog` items and show what is `ok`, `differs` or `missing`. If all are `ok`,
   say so and stop.
3. If the repository has a hand-edited `CHANGELOG.md`, keep its content: only add the header when the file is missing.
4. In a worktree, apply the fix for each item that is not `ok`, keeping the project's own
   additions. Add `changelog` to `features` in the record and set its `version` to the plugin's.
5. Commit (`ci: add changelog` for workflows, `chore: add changelog` otherwise) and merge by the
   repository's stage.
