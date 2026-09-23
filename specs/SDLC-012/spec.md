---
ticket: SDLC-012
title: PR claim lock uses REST — gh pr edit is broken by the projectCards retirement
status: draft
stacks: [bash, instructions]
---

# SDLC-012 — PR claim lock off `gh pr edit`

## Problem

`gh pr edit` resolves the pull request through a GraphQL query that still selects the retired
`projectCards` connection. Against current GitHub it fails outright on every `gh` build that
predates its removal:

```
$ gh pr edit 19 --add-label ai-sdlc
GraphQL: Projects (classic) is being deprecated ... (repository.pullRequest.projectCards)
$ gh pr view 19 --json labels --jq '[.labels[].name]'
[]
```

Three call sites depend on it:

- `tracker_github_pr_claim` guards the label/assignee write with `|| return 1`, so the **PR claim
  lock hard-fails** — the queue cannot claim a PR for the review phase at all.
- `tracker_github_pr_release` swallows the failure with `|| true`, so `in-progress` is never
  removed and every reviewed PR keeps a stale lock label.
- The shipped `github` tracker descriptor's `update-pr` cannot edit a PR title or body.

The issue-side equivalents (`gh issue edit`) are unaffected — verified against a live repository,
label applied, exit 0 — and the descriptor's `label-pr`/`unlabel-pr` already use REST, which is
why `/sdlc:ship` and `/sdlc:review` never surfaced this.

## Scope

In:
- `plugins/sdlc/bin/aisdlc`: `tracker_github_pr_claim` and `tracker_github_pr_release` move to the
  REST label and assignee endpoints.
- `plugins/sdlc/templates/trackers/github.md`: `update-pr` moves to `PATCH /repos/{o}/{r}/pulls/{n}`.
- `evals/harness/stub-gh` plus selftest coverage: a `gh` whose `pr edit` fails, proving the claim
  path no longer touches it.

Out:
- The issue path (`gh issue edit` at `tracker_github_claim` / `tracker_github_release`). It works;
  rewriting it would be churn.
- `gh pr create`, `gh pr comment`, `gh pr view`, `gh pr list`, `gh pr review` — all verified
  working against the same `gh` build.
- Pinning a minimum `gh` version. The REST calls work on every build, which is the point.

## Context

- `plugins/sdlc/bin/aisdlc` `tracker_github_pr_claim` (l. 426) and `tracker_github_pr_release`
  (l. 458); `gh_repo_slug` (l. 347) derives `{owner}/{repo}` from the origin remote.
- `plugins/sdlc/templates/trackers/github.md` — `label-issue` (l. 40) is the REST form the PR
  operations now match; `label-pr` already delegates to it.
- `plugins/sdlc/templates/trackers/TEMPLATE.md` — "A label write that fails must not be reported
  as success", the invariant the claim lock rests on.
- Observed on `gh version 2.46.0`; PRs are issues to the REST API, so
  `/repos/{o}/{r}/issues/{n}/labels` is the correct endpoint for a PR label.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | queue runner | claims a PR on a `gh` whose `pr edit` exits non-zero | `tracker_github_pr_claim` returns 0; the tracker shows `in-progress` and the current login as assignee | selftest |
| UC-2 | queue runner | same claim | no `gh pr edit` invocation appears in the recorded `gh` call log | selftest |
| UC-3 | queue runner | releases a PR that carries `in-progress` | the label is gone afterwards; the completion comment is still posted | selftest |
| UC-4 | agent following the `github` descriptor | `update-pr` on a PR | title and body are updated through `PATCH /repos/{owner}/{repo}/pulls/{n}` with `-F body=@<file>`; no GraphQL call is made | manual |
| UC-5 | queue runner | claims an **issue** | unchanged: `gh issue edit --add-label --add-assignee`, same behaviour as before this change | inspection |

## Non-functional

- No new dependency and no minimum `gh` version: the REST endpoints predate every affected build.
- The claim keeps its read-back check — a claim that is not observable is not a claim.
- `evals/harness/stub-gh` never reaches the network; the selftest stays offline and free.
- `make selftest` green; the four new cases fail on the pre-fix runner and pass on the fixed one.

## Open questions

None.
