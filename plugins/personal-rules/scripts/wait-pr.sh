#!/usr/bin/env bash
# Waits until a pull request can be merged or cannot: polls its merge state, because
# `gh pr checks --watch` can return before the required checks exist.
#
#   wait-pr.sh <number> [minutes, default 55]
#
# Prints `state=<mergeStateStatus>` and the checks, and exits 0 when the state is CLEAN (or
# HAS_HOOKS), 1 when a required check failed or the branch is DIRTY/BEHIND, 2 on a timeout.
# Run it in the background after the last push.
set -uo pipefail
n=${1:?usage: wait-pr.sh <number> [minutes]}
minutes=${2:-55}
state=UNKNOWN
for _ in $(seq 1 $((minutes * 2))); do
  state=$(gh pr view "$n" --json mergeStateStatus --jq .mergeStateStatus 2>/dev/null || echo UNKNOWN)
  failed=$(gh pr checks "$n" --required 2>/dev/null | grep -c -E '\bfail' || true)
  if [ "$failed" != 0 ]; then break; fi
  case "$state" in BLOCKED | UNKNOWN | UNSTABLE) ;; *) break ;; esac
  # UNSTABLE: a check that is not required is still running or failed; keep waiting while
  # anything runs, then go on.
  if [ "$state" = UNSTABLE ] && ! gh pr checks "$n" 2>/dev/null | grep -q -E '\bpending'; then break; fi
  sleep 30
done
echo "state=$state"
gh pr checks "$n" || true
case "$state" in
  CLEAN | HAS_HOOKS | UNSTABLE) [ "${failed:-0}" = 0 ] && exit 0 || exit 1 ;;
  DIRTY | BEHIND) exit 1 ;;
  BLOCKED) [ "${failed:-0}" != 0 ] && exit 1 || exit 2 ;;
  *) exit 2 ;;
esac
