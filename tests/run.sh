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
# Prints "<kind> <main> <components>", or the outputs named in $OUT (a sed alternation).
classify() {
  EVENT=${EVENT:-pull_request} PR_BASE=$base BEFORE=${BEFORE:-} VERSION_FILES=$'Cargo.toml\n' \
    PATH_COMPONENTS=$'android: apps/android\nios: ports/ios\nweb: web/*.ts' CODE_PATHS=plugins/ \
    IGNORE='site/ Taskfile.yml' PATH_GROUPS=$'deps: Cargo.lock deny.toml\nassets: assets/' FULL_PATHS='' \
    DEFAULT_BRANCH=master GITHUB_REF=${GITHUB_REF:-refs/pull/1/merge} GITHUB_OUTPUT=/dev/stdout \
    bash "$tmp/classify.sh" | sed -n "s/^\(${OUT:-kind\|main\|components}\)=//p" | tr '\n' ' ' | sed 's/ $//'
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
expect "first push builds all" "$(EVENT=push BEFORE=0000000000000000000000000000000000000000 classify)" 'code true ["android","ios","web"]'
mkdir -p .github/ISSUE_TEMPLATE site .claude && echo x > .github/ISSUE_TEMPLATE/bug.yml
echo x > site/index.html && echo x > Taskfile.yml && echo x > .claude/settings.json && echo x > .editorconfig
git add -A && git commit -qm ignored
expect "built-in and extra ignores" "$(classify)" 'docs false []'
mkdir -p web && echo x > web/app.ts && git add -A && git commit -qm web
expect "component by pattern" "$(classify)" 'code false ["web"]'
echo x > deny.toml && mkdir -p assets && echo x > assets/a.png && git add -A && git commit -qm g
expect "groups" "$(OUT='groups\|main' classify)" 'true ["assets","deps"]'
echo more >> src/main.rs && git add -A && git commit -qm pr
expect "pull request: small matrix" "$(OUT=full classify)" false
sed -i 's/0.4.1/0.4.2/' Cargo.lock && git add -A && git commit -qm lock2
expect "lockfile: full matrix" "$(OUT='full\|groups' classify)" '["deps"] true'
mkdir -p .github/workflows && echo x > .github/workflows/ci.yml && git add -A && git commit -qm wf
expect "workflow: full matrix" "$(OUT=full classify)" true
echo more >> src/main.rs && git add -A && git commit -qm push
expect "push to master: full matrix" "$(EVENT=push BEFORE=$base GITHUB_REF=refs/heads/master OUT=full classify)" true
echo doc >> README.md && git add -A && git commit -qm pushdoc
expect "docs push to master: no build" "$(EVENT=push BEFORE=$base GITHUB_REF=refs/heads/master OUT='kind\|full' classify)" 'docs false'

# --- changelog-check.yml: fragments and CHANGELOG.md on a pull request
step_script "$W/changelog-check.yml" "name: Fragments" > "$tmp/clcheck.sh"
mkdir "$tmp/k" && cd "$tmp/k" || exit 1
git init -q -b master
git config user.email test@example.com
git config user.name test
git config core.autocrlf false
mkdir changelog.d && echo doc > changelog.d/README.md && echo code > main.c
git add -A && git commit -qm base
kbase=$(git rev-parse HEAD)
clcheck() { # prints the exit code, then resets
  BASE=$kbase KIND=${KIND:-code} NO_CHANGELOG=${NO_CHANGELOG:-false} bash "$tmp/clcheck.sh" > /dev/null 2>&1
  echo $?
  git reset -q --hard "$kbase"
}
echo more >> main.c && git add -A && git commit -qm c
expect "changelog-check: code without a fragment fails" "$(clcheck)" 1
echo more >> main.c && git add -A && git commit -qm c
expect "changelog-check: no-changelog label passes" "$(NO_CHANGELOG=true clcheck)" 0
echo more >> main.c && echo "- y" > changelog.d/y.fixed.md && git add -A && git commit -qm c
expect "changelog-check: code with a fragment passes" "$(clcheck)" 0
echo "# Changelog" > CHANGELOG.md && git add -A && git commit -qm setup
expect "changelog-check: adding CHANGELOG.md passes" "$(KIND=version NO_CHANGELOG=true clcheck)" 0
echo "# Changelog" > CHANGELOG.md && git add -A && git commit -qm setup
kbase=$(git rev-parse HEAD)
echo "edit" >> CHANGELOG.md && git add -A && git commit -qm edit
expect "changelog-check: editing CHANGELOG.md fails" "$(KIND=version NO_CHANGELOG=true clcheck)" 1
echo "- z" > changelog.d/z.added.md && git add -A && git commit -qm frag
kbase=$(git rev-parse HEAD)
git rm -q changelog.d/z.added.md && echo "## [1.0.0]" >> CHANGELOG.md && git add -A && git commit -qm release
expect "changelog-check: a release edits CHANGELOG.md" "$(KIND=version clcheck)" 0

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

# --- wait-pr.sh, against a fake gh that replays one line per poll: <state>|<all checks>|<required>
mkdir -p "$tmp/w/bin" && cd "$tmp/w" || exit 1
cat > bin/gh <<'EOF'
#!/usr/bin/env bash
# Fake gh for wait-pr.sh: each poll's `pr view` advances to the next line of $SCENARIO (the last
# repeats). $REQUIRED_CHECKS (one per line) is what the base branch's protection requires.
counter="$SCENARIO.n"
i=$(cat "$counter" 2>/dev/null || echo 0)
case "$*" in "pr view"*mergeStateStatus*) i=$((i + 1)); echo "$i" > "$counter" ;; esac
line=$(sed -n "${i}p" "$SCENARIO"); [ -n "$line" ] || line=$(tail -1 "$SCENARIO")
IFS='|' read -r state all required <<< "$line"
case "$*" in
  "pr view"*baseRefName*) echo master ;;
  "api repos/{owner}/{repo}/branches/"*) [ -n "${REQUIRED_CHECKS:-}" ] && echo "$REQUIRED_CHECKS" ;;
  "api "*) ;;
  "pr view"*) echo "${PR_STATE:-OPEN} $state" ;;
  *--required*--json*) echo "$required" ;;
  *--json*) echo "$all" ;;
esac
EOF
chmod +x bin/gh
wait_pr() { # $1 scenario lines; prints the exit code
  printf '%s\n' "$1" > scenario; rm -f scenario.n
  PATH="$tmp/w/bin:$PATH" SCENARIO="$tmp/w/scenario" WAIT_PR_INTERVAL=0 WAIT_PR_NO_CHECKS=0 \
    bash "$root/plugins/personal-rules/scripts/wait-pr.sh" 7 1 > out 2>&1
  echo "$? $(cat scenario.n)"
}
P='{"name":"build","bucket":"pending"}' OK='{"name":"build","bucket":"pass"}'
CI_OK='{"name":"CI result","bucket":"pass"}' CI_FAIL='{"name":"CI result","bucket":"fail"}'
X_FAIL='{"name":"macos","bucket":"fail"}'
expect "wait-pr: waits while a check that is not required is pending" \
  "$(wait_pr "UNSTABLE|[$CI_OK,$P]|[$CI_OK]
UNSTABLE|[$CI_OK,$P]|[$CI_OK]
CLEAN|[$CI_OK,$OK]|[$CI_OK]")" "0 3"
expect "wait-pr: waits for checks to appear" \
  "$(wait_pr "BLOCKED|[]|[]
BLOCKED|[$P]|[]
CLEAN|[$CI_OK,$OK]|[$CI_OK]")" "0 3"
expect "wait-pr: a required failure is final once nothing is pending" \
  "$(wait_pr "BLOCKED|[$CI_FAIL,$P]|[$CI_FAIL]
BLOCKED|[$CI_FAIL,$OK]|[$CI_FAIL]")" "1 2"
# A run cancelled by a newer one (job 10) left a failed CI result; the newer run (jobs 20, 30)
# is still building, then passes.
OLD_FAIL='{"name":"CI result","bucket":"fail","link":"https://github.com/o/r/actions/runs/1/job/10"}'
NEW_P='{"name":"build","bucket":"pending","link":"https://github.com/o/r/actions/runs/2/job/20"}'
NEW_B='{"name":"build","bucket":"pass","link":"https://github.com/o/r/actions/runs/2/job/20"}'
NEW_OK='{"name":"CI result","bucket":"pass","link":"https://github.com/o/r/actions/runs/2/job/30"}'
expect "wait-pr: a cancelled run's stale failure is replaced by the newer run" \
  "$(wait_pr "BLOCKED|[$OLD_FAIL,$NEW_P]|[$OLD_FAIL]
BLOCKED|[$OLD_FAIL,$NEW_P]|[$OLD_FAIL]
CLEAN|[$OLD_FAIL,$NEW_B,$NEW_OK]|[$OLD_FAIL,$NEW_OK]")" "0 3"
expect "wait-pr: the stale failure is not listed" "$(grep -c '^failed:' out)" 0
expect "wait-pr: a failure that is not required passes once all finish" \
  "$(wait_pr "UNSTABLE|[$CI_OK,$X_FAIL,$P]|[$CI_OK]
UNSTABLE|[$CI_OK,$X_FAIL]|[$CI_OK]")" "0 2"
expect "wait-pr: lists the failure that is not required" "$(grep -c '^failed: macos' out)" 1
expect "wait-pr: blocked by something other than checks" \
  "$(wait_pr "BLOCKED|[$CI_OK]|[$CI_OK]")" "1 3"
# The required check's workflow is still queued: only a failed optional check is listed, and the
# merge is blocked. That is a wait, not "blocked", until the required check reports.
expect "wait-pr: waits for a required check that has not reported yet" \
  "$(REQUIRED_CHECKS="CI result" wait_pr "BLOCKED|[$X_FAIL]|[]
BLOCKED|[$X_FAIL]|[]
BLOCKED|[$X_FAIL]|[]
BLOCKED|[$X_FAIL]|[]
CLEAN|[$X_FAIL,$CI_OK]|[$CI_OK]")" "0 5"
expect "wait-pr: without protection to read, a lone failed optional check is still blocked" \
  "$(wait_pr "BLOCKED|[$X_FAIL]|[]")" "1 3"
expect "wait-pr: conflict" "$(wait_pr "DIRTY|[$P]|[]")" "1 1"
expect "wait-pr: already merged" "$(PR_STATE=MERGED wait_pr "UNKNOWN|[$OK]|[]")" "3 1"

# --- the always-on rules fit the SessionStart context limit
cd "$root" || exit 1
size=$(wc -c < plugins/personal-rules/rules/always.md)
if [ "$size" -lt 9000 ]; then pass "always.md is $size bytes"; else fail "always.md size" "$size bytes, keep it under 9000"; fi

echo
if [ "$fails" -eq 0 ]; then echo "all tests passed"; else echo "$fails test(s) failed"; exit 1; fi
