# GitHub Issues API Permissions Test

Systematically tests every `/issues/` API endpoint against both actual issues
and pull requests, with different `GITHUB_TOKEN` permission scopes.

**Goal**: determine which operations require `issues: write` vs
`pull-requests: write` when the target issue number is actually a PR.

## Background

GitHub's REST API exposes pull request operations through `/issues/` endpoints
(since PRs are issues). The documentation and `x-accepted-github-permissions`
response header suggest that `issues: write` is sufficient for these operations,
but in practice GitHub enforces a stricter entity-type-based permission check
when fine-grained `GITHUB_TOKEN` permissions are used.

## Setup (one-time)

The repo must be **public** — private repos may have different default
permission behavior.

```bash
# 1. Create the repo
gh repo create <you>/gh-issues-api-permissions-test --public --source=. --push

# 2. Allow GitHub Actions to create PRs (needed by the setup job)
gh api repos/<you>/gh-issues-api-permissions-test/actions/permissions/workflow \
  -X PUT -F can_approve_pull_request_reviews=true -F default_workflow_permissions=write
```

## Running

```bash
gh workflow run test-permissions.yml --repo <you>/gh-issues-api-permissions-test
```

Results appear in the **Step Summary** of each test job on the workflow run page.

The cleanup job automatically closes the test issue/PR, deletes the test branch,
and removes test labels.

## Test matrix

The workflow creates:
- A test **issue** and a test **PR**
- Fixture comments and labels for each test job

Then runs two jobs in parallel:
- `issues: write` — tests all endpoints with only that permission
- `pull-requests: write` — tests all endpoints with only that permission

### Operations tested

| # | Operation | Method | Endpoint |
|---|-----------|--------|----------|
| 1 | Create comment | `POST` | `/issues/{n}/comments` |
| 2 | Update comment | `PATCH` | `/issues/comments/{id}` |
| 3 | Delete comment | `DELETE` | `/issues/comments/{id}` |
| 4 | Add label | `POST` | `/issues/{n}/labels` |
| 5 | Remove label | `DELETE` | `/issues/{n}/labels/{name}` |
| 6 | Add reaction | `POST` | `/issues/{n}/reactions` |
| 7 | Add comment reaction | `POST` | `/issues/comments/{id}/reactions` |
| 8 | Update issue/PR | `PATCH` | `/issues/{n}` |
| 9–15 | Read operations | `GET` | various |

Each operation is tested against both the issue and the PR.

## Extending

To add new test cases, edit `test.sh` and add `run_test` calls. The function
signature is:

```bash
run_test <num> <description> <method> <endpoint_pattern> \
  <issue_endpoint> <pr_endpoint> [curl_extra_args...]
```

If a new test needs pre-created fixtures, add them to the setup job in the
workflow and pass the IDs as environment variables.
