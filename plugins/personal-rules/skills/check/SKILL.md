---
name: check
description: Audit the current repository against the personal rules (base files, language basics, opted-in features, stage) and offer to fix what is missing or differs; with the argument "standard", also add the standard features it lacks (release, changelog). Use when asked to check, audit, fix or standardize a repository's setup, or to upgrade it to a newer personal-rules version.
argument-hint: "[standard] [item ids to limit the audit]"
disable-model-invocation: true
---

# Check the repository

1. Read `${CLAUDE_PLUGIN_ROOT}/reference/features.md`: it defines every item, its check and its fix.
2. Read `.github/personal-rules.yml`. If it is missing, survey the repository as that file says,
   show the guessed record, and continue only after the user confirms or corrects it.
3. Audit every item that applies (base, the main language, each component, each feature in
   `features`, the stage). Look for components the record does not list (folders with `gradlew`,
   an iOS project, another platform's project or build script, a platform the release builds) and
   report them as `differs`. A feature in `custom` is audited by its contract (reference, "Custom
   workflows"), never against the template; a workflow without the personal-rules header that the
   record does not mark `custom` is `differs: not managed`, fixed by adding it to `custom`, not by
   replacing it. With `ci`, audit the path rules too (reference,
   "Path rules"): list each top-level folder and whether a rule covers it, and propose `ignore`,
   `components` and `groups` entries that would spare builds. Items
   for features the repository did not opt into are `➖`, not missing, unless the argument
   `standard` was given: then every standard feature the repository lacks (reference, "Standard
   features") is audited as `❌ missing (standard)`. Only read in this step: change nothing.
4. Print the report in the format the reference gives, ending with the features not opted in.
   Say what you could not check (for example the ruleset, when `gh` is not signed in).
5. Ask which `⚠️`/`❌` items to fix: all, a list of ids, or none. Do not change any file before the
   answer.
6. Fix the chosen items in a worktree, following the reference (a missing standard feature is set
   up as its `add-*` command does, and added to the record's `features`), then update `version` in
   the record to the plugin's version. Commit (`chore: apply personal-rules <version>`), and merge by
   the repository's stage.
7. Report what changed and what was left as is.
