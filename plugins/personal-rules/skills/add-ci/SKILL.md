---
name: add-ci
description: Add or update CI - the language's CI caller workflow with the PR run-name, docs-only and version-only skips, and the single CI result check. Idempotent and safe on an existing repository. Use when asked to add or update the ci setup of a repository.
disable-model-invocation: true
---

# Add `ci`

1. Read the `ci` section of `${CLAUDE_PLUGIN_ROOT}/reference/features.md` and
   `.github/personal-rules.yml` (if the record is missing, create it as the reference says, after
   the user confirms the guess).
2. Audit only the `ci` items and show what is `ok`, `differs` or `missing`. If all are `ok`,
   say so and stop.
3. Early-stage repositories normally have no CI: if `stage` is `early`, say that `/personal-rules:establish` adds CI together with the protection, and continue only if the user still wants CI now.
4. In a worktree, apply the fix for each item that is not `ok`, keeping the project's own
   additions. Add `ci` to `features` in the record and set its `version` to the plugin's.
5. Commit (`ci: add ci` for workflows, `chore: add ci` otherwise) and merge by the
   repository's stage.
