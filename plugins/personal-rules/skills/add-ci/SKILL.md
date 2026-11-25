---
name: add-ci
description: Add or update CI - the language's CI caller workflow with the PR run-name, path rules fitted to the repository so CI runs only what a change needs, a Linux-only matrix on pull requests, and the single CI result check. Idempotent and safe on an existing repository. Use when asked to add or update the ci setup of a repository, or to make CI faster.
disable-model-invocation: true
---

# Add `ci`

1. Read the `ci` section of `${CLAUDE_PLUGIN_ROOT}/reference/features.md` and
   `.github/personal-rules.yml` (if the record is missing, create it as the reference says, after
   the user confirms the guess).
2. Audit only the `ci` items and show what is `ok`, `differs` or `missing`. If all are `ok`,
   say so and stop.
3. Early-stage repositories normally have no CI: if `stage` is `early`, say that `/personal-rules:establish` adds CI together with the protection, and continue only if the user still wants CI now.
4. Survey the tree and the build for path rules (reference, "Path rules"): propose the `ignore`,
   `components`, `groups` and `full-paths` entries, and the jobs to gate on groups, in one list
   for the user to confirm or trim.
5. In a worktree, apply the fix for each item that is not `ok` and the confirmed path rules,
   keeping the project's own additions. Add `ci` to `features` in the record and set its
   `version` to the plugin's.
6. Commit (`ci: add ci` for workflows, `chore: add ci` otherwise) and merge by the
   repository's stage.
