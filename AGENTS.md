# Instructions for AI agents

This repository holds Rangel Reale's reusable AI coding rules, as a Claude Code plugin marketplace
(`personal-ai-rules`, plugin `personal-rules`) and as reusable GitHub Actions workflows.

## Using the rules from another AI tool

The rules are plain Markdown; read them directly:

- Always-on rules for every repository: `plugins/personal-rules/rules/always.md`.
- Language rules: `plugins/personal-rules/skills/{android,rust,go,cpp}/SKILL.md`.
- What a repository should hold, and how to check and fix it:
  `plugins/personal-rules/reference/features.md`.
- Commands (procedures): `plugins/personal-rules/skills/{new-project,check,establish,release,add-*}/SKILL.md`.
  `${CLAUDE_PLUGIN_ROOT}` in them means `plugins/personal-rules/` of this repository.

## Working on this repository

The always-on rules apply here too. In addition:

- **Layout.** `.claude-plugin/marketplace.json` (marketplace) → `plugins/personal-rules/` (plugin:
  `hooks/` prints `rules/always.md` at session start, `skills/`, `reference/`, `templates/`,
  `scripts/`). `.github/workflows/` holds the reusable workflows (`on: workflow_call`) that
  project callers pin by tag, plus this repository's own `ci.yml` and `release.yml`.
- **Keep `rules/always.md` short** (tests fail at 9000 bytes): it is injected into every session.
  Put detail in skills or the reference.
- **Caller templates are generated.** Edit `scripts/gen-templates.py`, then run
  `python3 -I scripts/gen-templates.py plugins/personal-rules/templates/workflows`; CI fails when
  the committed templates differ.
- **Reusable workflows are a public API.** Projects pin them by tag. Do not rename or remove an
  input or output, or change its meaning, without a major version change; add inputs with
  defaults that keep the old behaviour.
- **One definition of correct.** `check` and every `add-*` command read
  `reference/features.md`; change an expectation there, not in a skill.
- **Check a change:** `bash tests/run.sh`, `actionlint`, `bash scripts/lint-templates.sh`,
  `shellcheck plugins/personal-rules/scripts/*.sh scripts/*.sh tests/*.sh`,
  `claude plugin validate .`.
- **Releases.** `version` in `plugins/personal-rules/.claude-plugin/plugin.json` is the version;
  the tag `v<version>` must match it (the release fails otherwise). Use the plugin's own
  `/personal-rules:release`, which bumps `plugin.json` and merges `changelog.d/`.
