#!/usr/bin/env bash
# Lints the caller workflow templates with actionlint, after filling in the rules ref.
# Usage: scripts/lint-templates.sh   (from the repository root; needs actionlint)
set -euo pipefail
root=$(pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.github/workflows"
cp .github/actionlint.yaml "$tmp/.github/"
for f in plugins/personal-rules/templates/workflows/*.yml; do
  sed 's/__RULES_REF__/v0.0.0/g' "$f" > "$tmp/.github/workflows/${f##*/}"
done
cd "$tmp"
actionlint -config-file .github/actionlint.yaml .github/workflows/*.yml
echo "Templates OK ($(find .github/workflows -name '*.yml' | wc -l) files)"
cd "$root"
