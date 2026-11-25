#!/usr/bin/env bash
# Waits until a pull request's checks have all finished, then says whether it can be merged.
# It polls instead of `gh pr checks --watch`, which can return before the checks exist.
#
#   wait-pr.sh <number> [minutes, default 55]
#
# Exit 0: no check is pending, no required check failed, and the merge state is not blocked
#         (checks that are not required may have failed: they are listed).
# Exit 1: a required check failed or was cancelled once nothing is pending, the branch is
#         DIRTY/BEHIND, or something other than checks (a review, a rule) blocks the merge.
# Only the newest run of each check counts, as for GitHub: a run that a newer push or label
# cancelled can leave a failed "CI result" behind, which the newer run's result replaces. For
# the same reason a required failure is final only when no check is pending.
# A required check that the base branch's protection or rulesets name but that has not reported
# yet (its workflow is still queued) counts as pending, so a merge blocked only by it is waited
# for rather than reported as blocked.
# Exit 2: checks still pending at the time limit; run it again.
# Exit 3: the pull request is no longer open (merged or closed); the output says which.
# Run it in the background after the last push. WAIT_PR_INTERVAL sets the seconds between polls.
set -uo pipefail
n=${1:?usage: wait-pr.sh <number> [minutes]}
limit=$(( ${2:-55} * 60 ))
interval=${WAIT_PR_INTERVAL:-30}
# A push takes a moment to start its workflows: with no checks listed, wait this long before
# deciding that the repository has none.
no_checks_grace=${WAIT_PR_NO_CHECKS:-300}

count() { jq "[.[] | select($1)] | length" <<< "$2"; }
# The newest run of each check, by its job id (the number at the end of the link; GitHub's ids
# grow with time). Checks without a job link count as id 0.
newest() {
  jq '[group_by(.name)[] | max_by((.link // "") | (capture("/job/(?<id>[0-9]+)")? | .id | tonumber) // 0)]' <<< "$1"
}

# The checks the base branch requires, by name: classic protection and rulesets. Read once; an
# empty list (no protection, or no right to read it) leaves the waiting as it was.
base=$(gh pr view "$n" --json baseRefName --jq .baseRefName 2>/dev/null || true)
expected='[]'
if [ -n "$base" ]; then
  expected=$({
    gh api "repos/{owner}/{repo}/branches/$base" \
      --jq '.protection.required_status_checks.contexts[]?' 2>/dev/null
    gh api "repos/{owner}/{repo}/rules/branches/$base" \
      --jq '.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context' 2>/dev/null
  } | tr -d '\r' | jq -R 'select(length > 0)' | jq -s 'unique')
  [ -n "$expected" ] || expected='[]'
fi

elapsed=0 blocked_polls=0 result=""
while :; do
  view=$(gh pr view "$n" --json state,mergeStateStatus --jq '.state + " " + .mergeStateStatus' 2>/dev/null || echo "OPEN UNKNOWN")
  pr_state=${view%% *} state=${view#* }
  if [ "$pr_state" != OPEN ]; then result=$(tr '[:upper:]' '[:lower:]' <<< "$pr_state"); fi
  # gh exits non-zero while checks are pending or failed; the JSON is still printed.
  all=$(gh pr checks "$n" --json name,bucket,link 2>/dev/null || true)
  required=$(gh pr checks "$n" --required --json name,bucket,link 2>/dev/null || true)
  [ -n "$all" ] || all='[]'
  [ -n "$required" ] || required='[]'
  all=$(newest "$all") required=$(newest "$required")
  total=$(count true "$all")
  # Required checks not listed yet are pending: their workflow has not started.
  missing=$(jq --argjson all "$all" '[.[] | select(. as $c | $all | map(.name) | index($c) | not)] | length' <<< "$expected")
  pending=$(( $(count '.bucket == "pending"' "$all") + missing ))
  required_failed=$(count '.bucket == "fail" or .bucket == "cancel"' "$required")

  if [ -n "$result" ]; then break; fi
  if [ "$required_failed" -gt 0 ] && [ "$pending" -eq 0 ]; then result=failed; break; fi
  case "$state" in DIRTY | BEHIND) result=conflict; break ;; esac
  if [ "$total" -gt 0 ] && [ "$pending" -eq 0 ]; then
    case "$state" in
      BLOCKED)
        # Everything finished and nothing required failed, yet the merge is blocked: a review or
        # a rule. Give GitHub two polls to update the state before saying so.
        blocked_polls=$((blocked_polls + 1))
        if [ "$blocked_polls" -ge 3 ]; then result=blocked; break; fi ;;
      UNKNOWN) ;;
      *) result=ready; break ;;
    esac
  elif [ "$total" -eq 0 ] && [ "$elapsed" -ge "$no_checks_grace" ]; then
    case "$state" in BLOCKED | UNKNOWN) ;; *) result=ready; break ;; esac
  fi
  if [ "$elapsed" -ge "$limit" ]; then result=timeout; break; fi
  sleep "$interval"
  elapsed=$((elapsed + interval))
done

echo "state=$state result=$result checks=$total pending=$pending required_failed=$required_failed missing_required=$missing"
failed_other=$(jq -r '[.[] | select(.bucket == "fail" or .bucket == "cancel") | .name] | join(", ")' <<< "$all")
[ -n "$failed_other" ] && echo "failed: $failed_other"
gh pr checks "$n" 2>/dev/null || true
case "$result" in
  ready) exit 0 ;;
  timeout) exit 2 ;;
  merged | closed) exit 3 ;;
  *) exit 1 ;;
esac
