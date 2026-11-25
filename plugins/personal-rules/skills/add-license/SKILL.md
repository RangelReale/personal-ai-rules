---
name: add-license
description: Add the MIT license file (and the Cargo license field for Rust). Idempotent and safe on an existing repository. Use when asked to add or update the license setup of a repository.
disable-model-invocation: true
---

# Add `license`

1. Read the `license` section of `${CLAUDE_PLUGIN_ROOT}/reference/features.md` and
   `.github/personal-rules.yml` (if the record is missing, create it as the reference says, after
   the user confirms the guess).
2. Audit only the `license` items and show what is `ok`, `differs` or `missing`. If all are `ok`,
   say so and stop.
3. Never replace a different existing license: report it and stop.
4. In a worktree, apply the fix for each item that is not `ok`, keeping the project's own
   additions. Add `license` to `features` in the record and set its `version` to the plugin's.
5. Commit (`ci: add license` for workflows, `chore: add license` otherwise) and merge by the
   repository's stage.
