#!/usr/bin/env bash
# Lints the caller workflow templates with actionlint, after filling in the placeholders. The
# component jobs are linted inside a Rust caller that has an Android, an iOS and another component.
# Usage: scripts/lint-templates.sh   (from the repository root; needs actionlint)
# Set ACTIONLINT_FLAGS=-shellcheck= on Windows, where actionlint can hang on long scripts.
set -euo pipefail
T=plugins/personal-rules/templates/workflows
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.github/workflows"
cp .github/actionlint.yaml "$tmp/.github/"
fill() { sed 's/__RULES_REF__/v0.0.0/g; s/__RELEASE_ENVIRONMENT__/release/g' "$@"; }
for f in "$T"/ci-*.yml "$T"/release-*.yml; do
  case "${f##*/}" in *-component-*) continue ;; esac
  fill "$f" > "$tmp/.github/workflows/${f##*/}"
done

# A caller with components: insert the component jobs and list them in needs.
component() { # $1 template, $2 name, $3 path, $4 native, $5 build
  fill "$1" | grep -v '^#' | sed "s/__NAME__/$2/g; s|__PATH__|$3|g; s/__NATIVE__/$4/g; s|__BUILD__|${5:-}|g"
}
{
  component "$T/ci-component-android.yml" android apps/android rust
  component "$T/ci-component-ios.yml" ios ports/ios none
  component "$T/ci-component-other.yml" tizen ports/tizen none "bash tools/port/tizen/build.sh"
} > "$tmp/ci-jobs"
fill "$T/ci-rust.yml" | awk -v jobs="$tmp/ci-jobs" '
  /^  # Fragments in changelog.d/ { while ((getline l < jobs) > 0) print l; print "" }
  { sub(/needs: \[changes, build, changelog\]/, "needs: [changes, build, android, ios, tizen, changelog]"); print }
' > "$tmp/.github/workflows/ci-rust-components.yml"
{
  component "$T/release-component-android.yml" android apps/android rust
  component "$T/release-component-ios.yml" ios ports/ios none
  component "$T/release-component-other.yml" tizen ports/tizen none "bash tools/port/tizen/build.sh"
} > "$tmp/release-jobs"
fill "$T/release-rust.yml" | awk -v jobs="$tmp/release-jobs" '
  /^  # Component release jobs/ { while ((getline l < jobs) > 0) print l; next }
  { sub(/needs: \[check, build\]/, "needs: [check, build, android, ios, tizen]"); print }
' > "$tmp/.github/workflows/release-rust-components.yml"

cd "$tmp"
# shellcheck disable=SC2086
actionlint ${ACTIONLINT_FLAGS:-} -config-file .github/actionlint.yaml .github/workflows/*.yml
echo "Templates OK ($(find .github/workflows -name '*.yml' | wc -l | tr -d ' ') workflows)"
