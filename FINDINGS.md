# GitHub Issues API: Permission Scoping for Pull Requests

**Date**: 2026-03-23
**Test repos**: [public](https://github.com/gcl-sekoia/gh-issues-api-permissions-test) · [private](https://github.com/gcl-sekoia/gh-issues-api-permissions-test-private)

## Summary

GitHub's REST API exposes pull request operations through `/issues/` endpoints,
since every PR is also an issue. The API documentation and the
`x-accepted-github-permissions` response header both suggest that `issues: write`
is sufficient for these operations. **It is not.**

When a workflow uses explicit `permissions:` (fine-grained `GITHUB_TOKEN`
scoping), GitHub resolves the target entity type at runtime and enforces
permission checks based on whether the target is an actual issue or a pull
request — even though the endpoint path is `/issues/`. The enforcement rules
differ between public and private repositories, and are internally inconsistent
in both cases.

## Background

While hardening GitHub Actions workflows in
[SEKOIA-IO/documentation](https://github.com/SEKOIA-IO/documentation), we
replaced the default (broad) `GITHUB_TOKEN` permissions with explicit
least-privilege scoping:

```yaml
permissions: {}  # deny all at workflow level

jobs:
  upload:
    permissions:
      actions: read
      issues: write  # for peter-evans/create-or-update-comment
```

This broke the preview comment workflow: creating new comments on PRs returned
**403 Resource not accessible by integration**, while updating existing comments
on the same PRs continued to work. The investigation revealed that `issues: write`
is not sufficient for write operations on pull requests through the Issues API.

## Test methodology

A [workflow](.github/workflows/test-permissions.yml) creates a test issue and a
test PR, then runs two jobs in parallel:

- One with **only `issues: write`**
- One with **only `pull-requests: write`**

Each job tests 15 operations (8 write, 7 read) against both the issue and the
PR via the `/issues/` API endpoints, recording the HTTP status code and the
`x-accepted-github-permissions` response header.

The same test was run on a **public** and a **private** repository.

## Results

### Public repository

#### `issues: write`

| # | Operation | Method | Endpoint | Issue | PR |
|---|-----------|--------|----------|:-----:|:--:|
| 1 | Create comment | `POST` | `/issues/{n}/comments` | `201` ✅ | `403` ❌ |
| 2 | Update comment | `PATCH` | `/issues/comments/{id}` | `200` ✅ | `200` ✅ |
| 3 | Delete comment | `DELETE` | `/issues/comments/{id}` | `204` ✅ | `204` ✅ |
| 4 | Add label | `POST` | `/issues/{n}/labels` | `200` ✅ | `403` ❌ |
| 5 | Remove label | `DELETE` | `/issues/{n}/labels/{name}` | `200` ✅ | `403` ❌ |
| 6 | Add reaction | `POST` | `/issues/{n}/reactions` | `201` ✅ | `403` ❌ |
| 7 | Add comment reaction | `POST` | `/issues/comments/{id}/reactions` | `201` ✅ | `403` ❌ |
| 8 | Update issue/PR | `PATCH` | `/issues/{n}` | `200` ✅ | `200` ✅ |
| 9 | Get issue/PR | `GET` | `/issues/{n}` | `200` ✅ | `200` ✅ |
| 10 | List comments | `GET` | `/issues/{n}/comments` | `200` ✅ | `200` ✅ |
| 11 | Get comment | `GET` | `/issues/comments/{id}` | `200` ✅ | `200` ✅ |
| 12 | List labels | `GET` | `/issues/{n}/labels` | `200` ✅ | `200` ✅ |
| 13 | List events | `GET` | `/issues/{n}/events` | `200` ✅ | `200` ✅ |
| 14 | List reactions | `GET` | `/issues/{n}/reactions` | `200` ✅ | `200` ✅ |
| 15 | Get timeline | `GET` | `/issues/{n}/timeline` | `200` ✅ | `200` ✅ |

#### `pull-requests: write`

| # | Operation | Method | Endpoint | Issue | PR |
|---|-----------|--------|----------|:-----:|:--:|
| 1 | Create comment | `POST` | `/issues/{n}/comments` | `403` ❌ | `201` ✅ |
| 2 | Update comment | `PATCH` | `/issues/comments/{id}` | `403` ❌ | `200` ✅ |
| 3 | Delete comment | `DELETE` | `/issues/comments/{id}` | `403` ❌ | `204` ✅ |
| 4 | Add label | `POST` | `/issues/{n}/labels` | `403` ❌ | `200` ✅ |
| 5 | Remove label | `DELETE` | `/issues/{n}/labels/{name}` | `403` ❌ | `200` ✅ |
| 6 | Add reaction | `POST` | `/issues/{n}/reactions` | `403` ❌ | `201` ✅ |
| 7 | Add comment reaction | `POST` | `/issues/comments/{id}/reactions` | `403` ❌ | `201` ✅ |
| 8 | Update issue/PR | `PATCH` | `/issues/{n}` | `403` ❌ | `200` ✅ |
| 9 | Get issue/PR | `GET` | `/issues/{n}` | `200` ✅ | `200` ✅ |
| 10 | List comments | `GET` | `/issues/{n}/comments` | `200` ✅ | `200` ✅ |
| 11 | Get comment | `GET` | `/issues/comments/{id}` | `200` ✅ | `200` ✅ |
| 12 | List labels | `GET` | `/issues/{n}/labels` | `200` ✅ | `200` ✅ |
| 13 | List events | `GET` | `/issues/{n}/events` | `200` ✅ | `200` ✅ |
| 14 | List reactions | `GET` | `/issues/{n}/reactions` | `200` ✅ | `200` ✅ |
| 15 | Get timeline | `GET` | `/issues/{n}/timeline` | `200` ✅ | `200` ✅ |

### Private repository

#### `issues: write`

| # | Operation | Method | Endpoint | Issue | PR |
|---|-----------|--------|----------|:-----:|:--:|
| 1 | Create comment | `POST` | `/issues/{n}/comments` | `201` ✅ | `403` ❌ |
| 2 | Update comment | `PATCH` | `/issues/comments/{id}` | `200` ✅ | `403` ❌ |
| 3 | Delete comment | `DELETE` | `/issues/comments/{id}` | `204` ✅ | `403` ❌ |
| 4 | Add label | `POST` | `/issues/{n}/labels` | `200` ✅ | `403` ❌ |
| 5 | Remove label | `DELETE` | `/issues/{n}/labels/{name}` | `200` ✅ | `403` ❌ |
| 6 | Add reaction | `POST` | `/issues/{n}/reactions` | `201` ✅ | `403` ❌ |
| 7 | Add comment reaction | `POST` | `/issues/comments/{id}/reactions` | `201` ✅ | `403` ❌ |
| 8 | Update issue/PR | `PATCH` | `/issues/{n}` | `200` ✅ | `403` ❌ |
| 9 | Get issue/PR | `GET` | `/issues/{n}` | `200` ✅ | `403` ❌ |
| 10 | List comments | `GET` | `/issues/{n}/comments` | `200` ✅ | `403` ❌ |
| 11 | Get comment | `GET` | `/issues/comments/{id}` | `200` ✅ | `403` ❌ |
| 12 | List labels | `GET` | `/issues/{n}/labels` | `200` ✅ | `403` ❌ |
| 13 | List events | `GET` | `/issues/{n}/events` | `200` ✅ | `403` ❌ |
| 14 | List reactions | `GET` | `/issues/{n}/reactions` | `200` ✅ | `403` ❌ |
| 15 | Get timeline | `GET` | `/issues/{n}/timeline` | `200` ✅ | `403` ❌ |

#### `pull-requests: write`

| # | Operation | Method | Endpoint | Issue | PR |
|---|-----------|--------|----------|:-----:|:--:|
| 1 | Create comment | `POST` | `/issues/{n}/comments` | `403` ❌ | `201` ✅ |
| 2 | Update comment | `PATCH` | `/issues/comments/{id}` | `403` ❌ | `200` ✅ |
| 3 | Delete comment | `DELETE` | `/issues/comments/{id}` | `403` ❌ | `204` ✅ |
| 4 | Add label | `POST` | `/issues/{n}/labels` | `403` ❌ | `200` ✅ |
| 5 | Remove label | `DELETE` | `/issues/{n}/labels/{name}` | `403` ❌ | `200` ✅ |
| 6 | Add reaction | `POST` | `/issues/{n}/reactions` | `403` ❌ | `201` ✅ |
| 7 | Add comment reaction | `POST` | `/issues/comments/{id}/reactions` | `403` ❌ | `201` ✅ |
| 8 | Update issue/PR | `PATCH` | `/issues/{n}` | `403` ❌ | `200` ✅ |
| 9 | Get issue/PR | `GET` | `/issues/{n}` | `403` ❌ | **`403` ❌** |
| 10 | List comments | `GET` | `/issues/{n}/comments` | `403` ❌ | `200` ✅ |
| 11 | Get comment | `GET` | `/issues/comments/{id}` | `403` ❌ | `200` ✅ |
| 12 | List labels | `GET` | `/issues/{n}/labels` | `403` ❌ | `200` ✅ |
| 13 | List events | `GET` | `/issues/{n}/events` | `403` ❌ | `200` ✅ |
| 14 | List reactions | `GET` | `/issues/{n}/reactions` | `403` ❌ | **`403` ❌** |
| 15 | Get timeline | `GET` | `/issues/{n}/timeline` | `403` ❌ | `200` ✅ |

## Analysis

### The permission model

GitHub resolves the target entity type at request time and enforces the
corresponding scope:

- **Issue → requires `issues:`**
- **Pull request → requires `pull-requests:`** (even through `/issues/` endpoints)

This applies to both read and write operations. The endpoint path (`/issues/`)
is irrelevant — what matters is the entity the path resolves to.

### Public vs private: different enforcement

| Behavior | Public | Private |
|----------|--------|---------|
| `issues: write` write ops on PRs | **Partially leaks** (3 of 8 ops work) | Fully blocked |
| `issues: write` read ops on PRs | All work | Fully blocked |
| `pull-requests: write` write ops on issues | Fully blocked | Fully blocked |
| `pull-requests: write` read ops on issues | All work | Fully blocked |
| `pull-requests: write` read ops on PRs | All work | **2 endpoints broken** |

**Public repos** have a more permissive layer — presumably because public data
is world-readable anyway. This creates three inconsistent "leaks" where
`issues: write` grants write access to PR data:

| Leaking operation | Endpoint | Hypothesis |
|---|---|---|
| Update comment on PR | `PATCH /issues/comments/{id}` | Permission check uses comment ID, not entity type |
| Delete comment on PR | `DELETE /issues/comments/{id}` | Same |
| Update PR | `PATCH /issues/{n}` | Unclear |

These leaks do **not** exist on private repos, where the split is perfectly
clean for `issues: write`.

**Private repos** enforce a strict split but have two apparent bugs where
`pull-requests: write` cannot even read PR data:

| Broken operation | Endpoint | `x-accepted-github-permissions` |
|---|---|---|
| Get issue/PR | `GET /issues/{n}` | `issues=read` |
| List reactions | `GET /issues/{n}/reactions` | `issues=read` |

Both headers claim `issues=read` is the only accepted scope — suggesting these
endpoints are not wired to accept `pull-requests:` at all, even when the target
is a PR.

### The `x-accepted-github-permissions` header is unreliable

The header returned on 403 responses is meant to tell you which permission you
need. In practice:

| Endpoint | Header says | Reality (public) | Reality (private) |
|----------|-------------|-------------------|-------------------|
| `POST /issues/{n}/comments` (on PR) | `issues=write; pull_requests=write` | Only `pull_requests=write` works | Only `pull_requests=write` works |
| `POST /issues/{n}/reactions` (on PR) | `issues=write` | Only `pull_requests=write` works | Only `pull_requests=write` works |
| `POST /issues/comments/{id}/reactions` (on PR) | `issues=write` | Only `pull_requests=write` works | Only `pull_requests=write` works |

The semicolon in the header means OR ("either of these works"). For PR targets,
this is false — only `pull_requests=write` works. The header reports what
permissions the **endpoint** accepts in general, not what the **resolved entity**
requires.

## Practical guidance

### For workflow authors

**If your workflow interacts with PRs through `/issues/` endpoints, you need
`pull-requests: write`, not `issues: write`.** This includes:

- Commenting on PRs (`peter-evans/create-or-update-comment`, `actions/github-script`)
- Labeling PRs (`actions/labeler`, `actions/stale`)
- Adding reactions to PRs

If the workflow operates on both issues and PRs, grant both:

```yaml
permissions:
  issues: write
  pull-requests: write
```

### Common pitfall

A workflow that updates existing PR comments may appear to work with only
`issues: write` on a **public** repo (due to the PATCH-by-comment-ID leak),
but will break on:

- **New PRs** that have no existing comment (POST by issue number is blocked)
- **Private repos** where the leak does not exist
- **Future GitHub changes** that close the leak

Always grant `pull-requests: write` if the workflow touches PRs.

### For the `actions/stale` action

`actions/stale` labels and comments on PRs. Despite using the Issues API
internally, it needs:

```yaml
permissions:
  issues: write         # label and comment on stale issues
  pull-requests: write  # label and comment on stale PRs
```

Granting only `issues: write` with `pull-requests: read` (as we initially did)
works only because `actions/stale` happens to interact with PRs through
operations that leak on public repos. This is fragile and should not be relied
upon.

## References

- [GitHub REST API: Issue comments](https://docs.github.com/en/rest/issues/comments)
- [GitHub REST API: Permissions](https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps)
- [GitHubSecurityLab/actions-permissions](https://github.com/GitHubSecurityLab/actions-permissions) —
  MITM-based permission monitor whose
  [mapping logic](https://github.com/GitHubSecurityLab/actions-permissions/blob/main/monitor/mitm_plugin.py)
  correctly identifies that `/issues/` endpoints resolve to either `issues` or
  `pull-requests` scope depending on the target entity, but does not account for
  the public/private divergence or the PATCH-by-ID leak
- Test workflow: [test-permissions.yml](.github/workflows/test-permissions.yml)
- Test script: [test.sh](test.sh)
- Public repo run: https://github.com/gcl-sekoia/gh-issues-api-permissions-test/actions/runs/23430136044
- Private repo run: https://github.com/gcl-sekoia/gh-issues-api-permissions-test-private/actions/runs/23430600891
