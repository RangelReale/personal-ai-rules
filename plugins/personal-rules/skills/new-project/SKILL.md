---
name: new-project
description: Set up a new repository with the personal rules - asks the language and the optional features, then writes the base files, the record and the chosen features. Use when starting a new project or repository.
argument-hint: "[name]"
disable-model-invocation: true
---

# New project

The reference for every file is `${CLAUDE_PLUGIN_ROOT}/reference/features.md`.

1. Ask, in one `AskUserQuestion` call:
   - the language: `android`, `rust`, `go`, `cpp` or `none`;
   - the features (multi-select), with **release** and **changelog** preselected (listed first and
     marked recommended); `license` (MIT), `dependabot` and `ci` unselected. Say that `ci` normally
     waits until `/personal-rules:establish`;
   - the name and one-line description, if the argument and the folder do not give them.
2. If the folder is not a git repository: `git init -b master`. If it has commits, this is not a
   new project: run `/personal-rules:check` instead and stop.
3. Write, in this order (work directly on `master` only for the very first commit of an empty
   repository; after that, use a worktree):
   - `.github/personal-rules.yml` from the template: `stage: early`, the language, the features,
     `version` = the plugin's version;
   - the base items: `.gitignore`, `.gitattributes`, `.editorconfig`, `CLAUDE.md`, `README.md`;
   - each chosen feature, as the reference describes it.
4. Do not scaffold application code unless the user asks; when they do, follow the language skill.
5. Commit: `chore: set up the repository with personal-rules <version>`.
6. Ask whether to create the GitHub repository. Only on a yes, run
   `gh repo create <owner>/<name> --source . --push` with the visibility the user picks, then for
   `release` with `android`, list the secrets to add (`ANDROID_KEYSTORE_BASE64`,
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`).
7. Report the files written, the stage (`early`: merge locally, no CI), and that
   `/personal-rules:establish` switches to pull requests and CI when the code settles.
