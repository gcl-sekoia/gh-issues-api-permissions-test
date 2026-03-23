#!/bin/bash
# test.sh — Probe /issues/ API endpoints and report HTTP status codes.
#
# Required env vars:
#   GH_TOKEN          GITHUB_TOKEN with the permission under test
#   REPO              owner/repo
#   ISSUE             issue number (actual issue)
#   PR                issue number (pull request)
#   ISSUE_COMMENT     comment id on issue (for update test)
#   ISSUE_COMMENT_DEL comment id on issue (for delete test)
#   PR_COMMENT        comment id on PR (for update test)
#   PR_COMMENT_DEL    comment id on PR (for delete test)
#   LABEL             label already on both issue & PR (for remove test)
#   LABEL_ADD         label that exists but is not on issue/PR (for add test)
#   PERM_NAME         human-readable permission name for the report header
#   GITHUB_STEP_SUMMARY  (set by Actions runner)

set -euo pipefail

API="https://api.github.com"
FAILURES=""

# Call the GitHub API. Prints the HTTP status code.
# Also saves response headers to /tmp/h and body to /tmp/b.
call() {
  local method="$1" endpoint="$2"
  shift 2
  curl -s -D /tmp/h -o /tmp/b -w "%{http_code}" \
    -X "$method" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$@" \
    "${API}${endpoint}"
}

# Extract x-accepted-github-permissions from last response headers.
accepted_perms() {
  grep -i '^x-accepted-github-permissions:' /tmp/h 2>/dev/null \
    | sed 's/^[^:]*: //' | tr -d '\r' || echo "—"
}

badge() {
  if [[ "$1" =~ ^2 ]]; then echo "\`$1\` ✅"; else echo "\`$1\` ❌"; fi
}

# Run one test on both issue and PR targets.
# Args: num, description, method, endpoint_pattern,
#       issue_endpoint, pr_endpoint, [curl extra args...]
run_test() {
  local num="$1" desc="$2" method="$3" pattern="$4"
  local issue_ep="$5" pr_ep="$6"
  shift 6

  local is ps ih ph

  is=$(call "$method" "$issue_ep" "$@")
  ih=$(accepted_perms)

  ps=$(call "$method" "$pr_ep" "$@")
  ph=$(accepted_perms)

  echo "| $num | $desc | \`$method\` | \`$pattern\` | $(badge "$is") | $(badge "$ps") |"

  # Record failures for the detail table
  if [[ ! "$is" =~ ^2 ]]; then
    FAILURES+="| $num | $desc | Issue #$ISSUE | \`$is\` | \`$ih\` |"$'\n'
  fi
  if [[ ! "$ps" =~ ^2 ]]; then
    FAILURES+="| $num | $desc | PR #$PR | \`$ps\` | \`$ph\` |"$'\n'
  fi
}

{
  echo "## \`$PERM_NAME\` permission"
  echo ""
  echo "### Write operations"
  echo ""
  echo "| # | Operation | Method | Endpoint | Issue #$ISSUE | PR #$PR |"
  echo "|---|-----------|--------|----------|:---:|:---:|"

  # 1. Create comment
  run_test 1 "Create comment" POST "/issues/{n}/comments" \
    "/repos/$REPO/issues/$ISSUE/comments" \
    "/repos/$REPO/issues/$PR/comments" \
    -d '{"body":"probe: create comment"}'

  # 2. Update comment
  run_test 2 "Update comment" PATCH "/issues/comments/{id}" \
    "/repos/$REPO/issues/comments/$ISSUE_COMMENT" \
    "/repos/$REPO/issues/comments/$PR_COMMENT" \
    -d '{"body":"probe: update comment"}'

  # 3. Delete comment
  run_test 3 "Delete comment" DELETE "/issues/comments/{id}" \
    "/repos/$REPO/issues/comments/$ISSUE_COMMENT_DEL" \
    "/repos/$REPO/issues/comments/$PR_COMMENT_DEL"

  # 4. Add label
  run_test 4 "Add label" POST "/issues/{n}/labels" \
    "/repos/$REPO/issues/$ISSUE/labels" \
    "/repos/$REPO/issues/$PR/labels" \
    -d "{\"labels\":[\"$LABEL_ADD\"]}"

  # 5. Remove label
  run_test 5 "Remove label" DELETE "/issues/{n}/labels/{name}" \
    "/repos/$REPO/issues/$ISSUE/labels/$LABEL" \
    "/repos/$REPO/issues/$PR/labels/$LABEL"

  # 6. Add reaction to issue/PR
  run_test 6 "Add reaction" POST "/issues/{n}/reactions" \
    "/repos/$REPO/issues/$ISSUE/reactions" \
    "/repos/$REPO/issues/$PR/reactions" \
    -d '{"content":"+1"}'

  # 7. Add reaction to comment
  run_test 7 "Add comment reaction" POST "/issues/comments/{id}/reactions" \
    "/repos/$REPO/issues/comments/$ISSUE_COMMENT/reactions" \
    "/repos/$REPO/issues/comments/$PR_COMMENT/reactions" \
    -d '{"content":"heart"}'

  # 8. Update issue/PR (title)
  run_test 8 "Update issue/PR" PATCH "/issues/{n}" \
    "/repos/$REPO/issues/$ISSUE" \
    "/repos/$REPO/issues/$PR" \
    -d '{"title":"probe: updated title"}'

  echo ""
  echo "### Read operations"
  echo ""
  echo "| # | Operation | Method | Endpoint | Issue #$ISSUE | PR #$PR |"
  echo "|---|-----------|--------|----------|:---:|:---:|"

  # 9. Get issue/PR
  run_test 9 "Get issue/PR" GET "/issues/{n}" \
    "/repos/$REPO/issues/$ISSUE" \
    "/repos/$REPO/issues/$PR"

  # 10. List comments
  run_test 10 "List comments" GET "/issues/{n}/comments" \
    "/repos/$REPO/issues/$ISSUE/comments" \
    "/repos/$REPO/issues/$PR/comments"

  # 11. Get single comment
  run_test 11 "Get comment" GET "/issues/comments/{id}" \
    "/repos/$REPO/issues/comments/$ISSUE_COMMENT" \
    "/repos/$REPO/issues/comments/$PR_COMMENT"

  # 12. List labels
  run_test 12 "List labels" GET "/issues/{n}/labels" \
    "/repos/$REPO/issues/$ISSUE/labels" \
    "/repos/$REPO/issues/$PR/labels"

  # 13. List events
  run_test 13 "List events" GET "/issues/{n}/events" \
    "/repos/$REPO/issues/$ISSUE/events" \
    "/repos/$REPO/issues/$PR/events"

  # 14. List reactions
  run_test 14 "List reactions" GET "/issues/{n}/reactions" \
    "/repos/$REPO/issues/$ISSUE/reactions" \
    "/repos/$REPO/issues/$PR/reactions"

  # 15. Get timeline
  run_test 15 "Get timeline" GET "/issues/{n}/timeline" \
    "/repos/$REPO/issues/$ISSUE/timeline" \
    "/repos/$REPO/issues/$PR/timeline"

  # Detail table for failures
  if [[ -n "$FAILURES" ]]; then
    echo ""
    echo "### \`x-accepted-github-permissions\` header for failed requests"
    echo ""
    echo "| # | Operation | Target | Status | Header |"
    echo "|---|-----------|--------|--------|--------|"
    echo -n "$FAILURES"
  fi

  echo ""

} | tee -a "$GITHUB_STEP_SUMMARY"
