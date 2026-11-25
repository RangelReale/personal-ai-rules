---
name: mmp
description: Merge the current worktree's work into master and push it, the way the repository's stage says - a local merge and push for an early repository, a pull request merged on a green CI result for an established one - then remove the worktree and branch. Use when the user types /mmp or asks to "mmp", "merge and push" or "merge to master".
model: sonnet
---

# mmp: get this worktree's work onto master

**The user asking for this is the go-ahead** to commit, push, open a pull request and merge, for
the work in the current worktree and nothing else. **Each step finishes before the next one
starts;** a failing step stops the run, and "When the run stops early" says what to report.

A session isolated in a worktree runs each git command on its own: no `&&`, pipes, here-documents
or `$(...)` around `git`. Put commit messages and pull request bodies in files in the scratchpad
(`git commit -F`, `gh pr create --body-file`).

## 1. Where the session stands

```sh
git status --short
git branch --show-current
git log --oneline origin/master..HEAD
```

- **The branch is `master` (or `main`).** Stop: the work belongs in a worktree.
- **Files this session did not change.** Stop and ask; they are another session's work.
- **Nothing to commit and nothing ahead of `origin/master`.** Stop: there is nothing to merge.
- Read the stage from `.github/personal-rules.yml`. **No record:** an established repository has a
  protected default branch (`gh api repos/{owner}/{repo}/branches/master/protection` or a ruleset);
  say which you found, follow it, and suggest `/personal-rules:check`.

## 2. Commit and changelog

- Commit what is left, Conventional Commits, attribution lines at the end. Stage files by name.
- If `changelog.d/` exists and the branch changes something people who use the project notice (a
  `feat` or `fix`) without a fragment (`git diff --name-only origin/master...HEAD -- changelog.d`),
  write `changelog.d/<branch>.<type>.md` and commit it. Never edit `CHANGELOG.md`.

## 3. Check

Run the repository's checks before anything leaves the machine: `task check` if the Taskfile has
it, else the commands in `CLAUDE.md`, else the language skill's "Check a change". **A change that no
build or test reads** (prose, docs, a skill) may leave the build to CI; say so in the report. Stop
on a failure: never merge a red branch.

## 4a. Stage `early`: merge locally and push

1. `ExitWorktree` with `action: "keep"`.
2. In the main checkout: `git status --short --branch` must show a clean `master`; else stop.
3. `git pull --ff-only origin master`; if it cannot fast-forward, stop.
4. `git merge --no-ff <branch> -m "Merge branch '<branch>': <one-line summary>"` (match
   `git log --merges --format=%s -5`). On a conflict: `git merge --abort`, report the files, stop.
5. `git push origin master`. Then clean up (step 5).

## 4b. Stage `established`: pull request

1. `git push -u origin <branch>`.
2. Use the open pull request whose head is this branch (`gh pr list --head <branch> --state open`),
   or open one: `gh pr create --base master --title "<the commit's subject>" --body-file <file>`.
   The body says what changes and why, which checks ran locally and which did not, then the pull
   request attribution. Several commits take a title of their own for the whole branch.
3. Wait, in the background, after the last push:
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/wait-pr.sh" <n>`.
   It returns only when no check is pending, including checks that are not required, and counts
   only the newest run of each check (a run cancelled by a newer push or label can leave a stale
   failed `CI result` behind).
   - exit 0: every check finished, no required check failed, nothing blocks the merge. Go on, and
     report any check that is not required and failed (the output lists them under `failed:`).
   - exit 1: a required check failed (read `gh run view <run> --log-failed` and report it; a fix in
     this branch is a new commit, push and wait), the branch is `DIRTY`/`BEHIND` (stop: the user
     decides how to bring it up to date), or something other than checks blocks the merge, such as
     a required review (stop and say so).
   - exit 2: still running after the time limit; run it again.
   - exit 3: the pull request was merged or closed meanwhile; check which, and clean up only if
     it was merged.
4. `gh pr merge <n> --merge` (a merge commit; never squash or rebase; no `--delete-branch`, which
   fails from a worktree). Confirm with `gh pr view <n> --json state,headRefOid,mergeCommit` that
   the state is `MERGED`.

## 5. Clean up

Prove the worktree holds nothing the merge lacks, then remove it:
`git status --short` prints nothing, and `git rev-parse HEAD` equals the merged head. Then
`ExitWorktree` with `remove` (or `git worktree remove <path>`), and in the main checkout
`git pull --ff-only origin master`, `git branch -d <branch>` (never `-D`: its refusal is the
check), `git fetch --prune`. Leave every other worktree alone.

## 6. Report

One short message: the merge commit (and the pull request link), what was pushed, what was removed,
and every check that did not run or did not pass. Send a push notification when the wait was long.

## When the run stops early

Say which step stopped, what the command printed, and what state it left: an open pull request
stays open, an unmerged worktree stays where it is.
