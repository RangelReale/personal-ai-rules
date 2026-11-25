#!/usr/bin/env bash
# Tests the shell logic inside the reusable workflows and the changelog tool.
# Usage: tests/run.sh   (from the repository root; needs bash, git, awk, jq)
set -uo pipefail
root=$(pwd)
W="$root/.github/workflows"
CL="$root/plugins/personal-rules/scripts/changelog.sh"
fails=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }
expect() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "got '$2', want '$3'"; fi; }

# The body of the `run: |` block of the step whose line matches $2, in workflow $1.
step_script() {
  awk -v pat="$2" '
    index($0, pat) { found = 1 }
    found && /run: \|/ { inrun = 1; next }
    inrun && /^      - / { exit }
    inrun { print }
  ' "$1" | sed 's/^          //'
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- release-check.yml: manifests hold the tag's version
step_script "$W/release-check.yml" "name: Manifests hold" > "$tmp/manifest.sh"
mkdir "$tmp/m" && cd "$tmp/m" || exit 1
printf '[workspace]\nmembers = ["a"]\n\n[workspace.package]\nversion = "1.2.0-rc.1"\n' > Cargo.toml
printf 'project(app\n  VERSION 1.2.0\n  LANGUAGES CXX)\n' > CMakeLists.txt
echo '{"version":"1.2.0-rc.1"}' > plugin.json
echo 1.2.0-rc.1 > VERSION
VERSION=1.2.0-rc.1 CORE=1.2.0 VERSION_FILES=$'Cargo.toml\n CMakeLists.txt\nplugin.json\nVERSION' \
  bash "$tmp/manifest.sh" > /dev/null
expect "manifests match" "$?" 0
VERSION=1.3.0 CORE=1.3.0 VERSION_FILES=$'Cargo.toml' bash "$tmp/manifest.sh" > /dev/null
expect "manifest mismatch fails" "$?" 1
VERSION=1.2.0 CORE=1.2.0 VERSION_FILES=$'missing.toml' bash "$tmp/manifest.sh" > /dev/null
expect "missing manifest fails" "$?" 1
printf '[package]\nname = "x"\nversion = "0.4.1"\n\n[dependencies]\nfoo = { version = "1" }\n' > Cargo.toml
VERSION=0.4.1 CORE=0.4.1 VERSION_FILES=Cargo.toml bash "$tmp/manifest.sh" > /dev/null
expect "package version" "$?" 0

# --- changes.yml: docs / version / code
step_script "$W/changes.yml" "- id: classify" > "$tmp/classify.sh"
mkdir "$tmp/c" && cd "$tmp/c" || exit 1
git init -q -b master
git config user.email test@example.com
git config user.name test
git config core.autocrlf false
printf '[workspace.package]\nversion = "1.0.0"\nrust-version = "1.90"\n\n[workspace.dependencies]\nserde = { version = "1" }\n' > Cargo.toml
printf '[[package]]\nname = "a"\nversion = "1.0.0"\n\n[[package]]\nname = "dep"\nversion = "0.4.1"\n' > Cargo.lock
mkdir -p src changelog.d docs apps/android plugins/p
echo code > src/main.rs
echo app > apps/android/build.gradle.kts
echo skill > plugins/p/SKILL.md
echo "# Changelog" > CHANGELOG.md
echo "- x" > changelog.d/x.added.md
git add -A && git commit -qm base
base=$(git rev-parse HEAD)
# Prints "<kind> <main> <components>".
classify() {
  EVENT=${EVENT:-pull_request} PR_BASE=$base BEFORE=${BEFORE:-} VERSION_FILES=$'Cargo.toml\n' \
    COMPONENTS=$'android: apps/android\nios: ports/ios' CODE_PATHS=plugins/ GITHUB_OUTPUT=/dev/stdout \
    bash "$tmp/classify.sh" | sed -n 's/^\(kind\|main\|components\)=//p' | tr '\n' ' ' | sed 's/ $//'
  git reset -q --hard "$base"
}
echo doc > docs/a.md && echo r > README.md && git add -A && git commit -qm d
expect "docs only" "$(classify)" 'docs false []'
sed -i 's/"1.0.0"/"1.1.0"/' Cargo.toml Cargo.lock && git rm -q changelog.d/x.added.md
echo "## [1.1.0]" >> CHANGELOG.md && git add -A && git commit -qm v
expect "version only" "$(classify)" 'version false []'
sed -i 's/"1.0.0"/"1.1.0"/' Cargo.toml && echo 'edition = "2024"' >> Cargo.toml && git add -A && git commit -qm v2
expect "manifest with another change" "$(classify)" 'code true []'
sed -i 's/version = "1" }/version = "1.2" }/' Cargo.toml && git add -A && git commit -qm dep
expect "dependency version is code" "$(classify)" 'code true []'
sed -i 's/1.90/1.91/' Cargo.toml && git add -A && git commit -qm rv
expect "rust-version is code" "$(classify)" 'code true []'
sed -i 's/0.4.1/0.4.2/' Cargo.lock && git add -A && git commit -qm lock
expect "lockfile update is code" "$(classify)" 'code true []'
echo more >> src/main.rs && echo "- y" > changelog.d/y.fixed.md && git add -A && git commit -qm c
expect "main code" "$(classify)" 'code true []'
echo more >> apps/android/build.gradle.kts && git add -A && git commit -qm a
expect "component only" "$(classify)" 'code false ["android"]'
echo more >> plugins/p/SKILL.md && git add -A && git commit -qm p
expect "markdown in code-paths" "$(classify)" 'code true []'
echo more >> src/main.rs && git add -A && git commit -qm first
expect "first push builds all" "$(EVENT=push BEFORE=0000000000000000000000000000000000000000 classify)" 'code true ["android","ios"]'

# --- changelog.sh and the notes release-publish.yml extracts
mkdir -p "$tmp/l/changelog.d" && cd "$tmp/l" || exit 1
echo doc > changelog.d/README.md
printf -- '- feature one\n' > changelog.d/a.added.md
printf 'fixed the crash\n  on start\n' > changelog.d/b.fixed.md
bash "$CL" check > /dev/null
expect "fragments check" "$?" 0
bash "$CL" release 1.2.0 > /dev/null
expect "release 1.2.0" "$?" 0
expect "fragments removed" "$(find changelog.d -name '*.md' ! -name README.md | wc -l | tr -d ' ')" 0
printf -- '- later\n' > changelog.d/c.changed.md
bash "$CL" release 1.3.0 > /dev/null
expect "newest section first" "$(grep -m1 '^## \[' CHANGELOG.md)" "## [1.3.0] - $(date -u +%Y-%m-%d)"
bash "$CL" release 1.3.0 > /dev/null 2>&1
expect "no fragments fails" "$?" 1
echo bad > changelog.d/x.md
bash "$CL" check > /dev/null 2>&1
expect "bad fragment name fails" "$?" 1
rm changelog.d/x.md
step_script "$W/release-publish.yml" "name: Notes" > "$tmp/notes.sh"
RUNNER_TEMP=$tmp VERSION=1.2.0 CHANGELOG=CHANGELOG.md bash "$tmp/notes.sh" > /dev/null
expect "notes first line" "$(head -1 "$tmp/notes.md")" "### Added"
expect "notes stop at next section" "$(grep -c 'later' "$tmp/notes.md")" 0

# --- the always-on rules fit the SessionStart context limit
cd "$root" || exit 1
size=$(wc -c < plugins/personal-rules/rules/always.md)
if [ "$size" -lt 9000 ]; then pass "always.md is $size bytes"; else fail "always.md size" "$size bytes, keep it under 9000"; fi

echo
if [ "$fails" -eq 0 ]; then echo "all tests passed"; else echo "$fails test(s) failed"; exit 1; fi
