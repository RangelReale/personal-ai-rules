---
name: check
description: Audit the current repository against the personal rules (base files, language basics, opted-in features, stage) and offer to fix what is missing or differs. Use when asked to check, audit or fix a repository's setup, or to upgrade it to a newer personal-rules version.
argument-hint: "[item ids to limit the audit]"
disable-model-invocation: true
---

# Check the repository

1. Read `${CLAUDE_PLUGIN_ROOT}/reference/features.md`: it defines every item, its check and its fix.
2. Read `.github/personal-rules.yml`. If it is missing, survey the repository as that file says,
   show the guessed record, and continue only after the user confirms or corrects it.
3. Audit every item that applies (base, the main language, each component, each feature in
   `features`, the stage). Look for components the record does not list (folders with `gradlew`
   or an iOS project) and report them as `differs`. Items
   for features the repository did not opt into are `➖`, not missing. Only read in this step:
   change nothing.
4. Print the report in the format the reference gives. Say what you could not check (for example
   the ruleset, when `gh` is not signed in).
5. Ask which `⚠️`/`❌` items to fix: all, a list of ids, or none. Do not change any file before the
   answer.
6. Fix the chosen items in a worktree, following the reference, then update `version` in the
   record to the plugin's version. Commit (`chore: apply personal-rules <version>`), and merge by
   the repository's stage.
7. Report what changed and what was left as is.
