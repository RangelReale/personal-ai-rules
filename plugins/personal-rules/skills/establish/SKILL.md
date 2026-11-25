---
name: establish
description: Move a repository from the early stage (local merges, no CI) to the established stage - adds CI, protects master with a ruleset that requires pull requests and the CI result check, and records the stage. Use only when the user asks to establish or protect a repository.
disable-model-invocation: true
---

# Establish the repository

The reference is `${CLAUDE_PLUGIN_ROOT}/reference/features.md` (feature `ci`, section "Stage
`established`").

1. Read `.github/personal-rules.yml`. If `stage` is already `established`, run the stage checks
   and report; stop unless something is missing.
2. Check that `gh` is signed in with admin rights on the repository
   (`gh api repos/{owner}/{repo} --jq .permissions.admin`); without them, stop and say so.
3. In a worktree: add the `ci` feature if missing (and the changelog block if `changelog` is a
   feature), set `stage: established`, commit (`ci: establish the repository`). Merge it the early
   way (local `--no-ff` merge, push), since the protection does not exist yet.
4. Wait for the first `CI` run on `master` to pass (`gh run watch`); the ruleset requires the
   required check (`ci-check` in the record, default `CI result`), so it must exist and be green
   first. On a failure, stop and report it.
5. Show the user the ruleset from `${CLAUDE_PLUGIN_ROOT}/templates/github/ruleset-master.json`
   with `ci-check` filled in (pull requests only, that check required and up to date, no force
   pushes or deletion, admins included, merge commits only) and ask for a yes. Only then:
   `gh api -X POST repos/{owner}/{repo}/rulesets --input <file>`
   (or `-X PUT .../rulesets/<id>` when a ruleset named `master` exists).
6. Make sure merge commits are allowed:
   `gh api -X PATCH repos/{owner}/{repo} -F allow_merge_commit=true`.
7. Report: from now on work reaches `master` only through pull requests merged with
   `gh pr merge --merge` after the required check passes.
