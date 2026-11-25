#!/usr/bin/env bash
# Lints the workflows one file at a time, with shellcheck, and reports files that time out.
# actionlint on Windows can hang on long run scripts; on Linux (CI) plain `actionlint` is enough.
# Usage: scripts/lint-workflows.sh [seconds per file, default 25]
set -uo pipefail
limit=${1:-25}
status=0
for f in .github/workflows/*.yml; do
  out=$(timeout "$limit" actionlint "$f" < /dev/null 2>&1)
  r=$?
  if [ "$r" -eq 124 ]; then
    echo "timeout: $f (linted without shellcheck instead)"
    timeout "$limit" actionlint -shellcheck= "$f" < /dev/null || status=1
  elif [ "$r" -ne 0 ]; then
    echo "$out"
    status=1
  fi
done
[ "$status" -eq 0 ] && echo "workflows OK"
exit $status
