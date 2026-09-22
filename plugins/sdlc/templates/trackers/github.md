# Tracker provider: github

GitHub issues, pull requests, reviews and checks through the `gh` CLI. Reads use `gh <noun> view
--json`; mutations that `gh` wraps in convenience verbs go through `gh api` REST so an unrelated
field never aborts the write. Every command accepts `--repo {owner}/{repo}`; omitted → current
checkout. `{n}` is always a bare number.

## Prerequisites

`gh` ≥ 2.40, authenticated: **auth-check** must pass before any other operation.

## Conventions

Issues and PRs are `#123`. A PR closes an issue with `Fixes #123` / `Closes #123` in its body.
Draft PRs are real drafts (`--draft`). Multi-line bodies always go through `--body-file`.
Identity for claims is **current-user**. Timestamps ISO-8601 UTC.

## Operations

### auth-check
`gh auth status >/dev/null 2>&1 || { echo "gh not authenticated"; exit 1; }`
Returns: exit 0, or one line and exit 1.
### current-user
`gh api user --jq .login`
Returns: login.
### get-issue
`gh issue view {n} --json number,title,body,state,labels,assignees,author,comments,url`
Returns: JSON.
### search-issues
`gh issue list --search '{query}' --state {state} --json number,title,url --limit 20`
Returns: JSON array.
### create-issue
`gh issue create --title '{title}' --body-file {body-file} --label '{labels}' | tail -1`
Returns: issue URL; number is its last path segment.
### comment-issue
`gh issue comment {n} --body-file {body-file}`
### close-issue
`gh issue close {n} --comment '{comment}'`
### label-issue
`gh label list --json name --jq '.[].name' | grep -qx '{label}' && gh api -X POST repos/{owner}/{repo}/issues/{n}/labels -f 'labels[]={label}' >/dev/null || echo "label {label} absent — skipped"`
### unlabel-issue
`gh api -X DELETE repos/{owner}/{repo}/issues/{n}/labels/{label} >/dev/null 2>&1 || true`
### assign-issue
`gh api -X POST repos/{owner}/{repo}/issues/{n}/assignees -f 'assignees[]={user}' >/dev/null`
### get-pr
`gh pr view {n} --json number,title,body,state,isDraft,labels,assignees,author,headRefName,baseRefName,mergeable,reviews,comments,url,files`
Returns: JSON; `mergeable` is `MERGEABLE|CONFLICTING|UNKNOWN`.
### list-prs
`gh pr list --state {state} --label '{label}' --json number,title,labels,url,headRefName,isDraft,createdAt --limit 50`
### search-prs
`gh pr list --search '{query}' --state {state} --json number,title,url,state`
### create-pr
`gh pr create --title '{title}' --body-file {body-file} --base {base} {draft:+--draft}`
Returns: PR URL; number is its last path segment.
### update-pr
`gh pr edit {n} --title '{title}' --body-file {body-file}`
### comment-pr
`gh pr comment {n} --body-file {body-file}`
### label-pr
same as **label-issue** — PRs are issues to the REST API.
### unlabel-pr
same as **unlabel-issue**.
### assign-pr
same as **assign-issue**.
### review-pr
`gh pr review {n} --{verdict} --body-file {body-file}` where `{verdict}` is `approve` or `request-changes`.
### merge-pr
`gh pr merge {n} --squash --delete-branch`
### get-pr-diff
`gh pr diff {n}`
### get-pr-checks
`gh pr checks {n} --json name,state,link,workflow` — `state` is `SUCCESS|FAILURE|PENDING|…`.
### get-run-failed-logs
`gh run view {run-id} --log-failed`
### checkout-pr
`gh pr checkout {n} --detach` (in a linked worktree, never the primary checkout).
### attach-image-evidence
Upload each image to an `evidence` release asset and embed it:
`gh release view evidence >/dev/null 2>&1 || gh release create evidence --notes "QA evidence" --prerelease; for f in {image...}; do gh release upload evidence "$f" --clobber; done; gh release view evidence --json assets --jq '.assets[] | select(.name as $n | ["{image...}"] | map(split("/")[-1]) | index($n)) | "![\(.name)](\(.url))"' > {body-file}.imgs`
then **comment-pr** `{n}` with `{body-file}` followed by `{body-file}.imgs`. Private repo → asset
URLs need auth; still post them and say so.
### ensure-labels
`for l in {label...}; do gh label create "$l" --force --color 5319e7 --description "ai-sdlc pipeline" >/dev/null; done`
### claim
`gh api -X POST repos/{owner}/{repo}/issues/{n}/assignees -f 'assignees[]={me}' >/dev/null && gh api -X POST repos/{owner}/{repo}/issues/{n}/labels -f 'labels[]=in-progress' >/dev/null && gh issue comment {n} --body "🤖 /sdlc:{command} claimed $(date -u +%FT%TZ)"`
Read back with **get-issue**/**get-pr**: all three signals present, else fail.
### check-claim
From **get-issue**/**get-pr**: no `in-progress` label → `free`; label present and `{me}` in
assignees → `mine`; else find the newest comment matching `^🤖 .* claimed (\S+)`: older than
60 min → `stale:<its author>`, otherwise `other:<its author>` (fallback: first assignee).
### release
`gh api -X DELETE repos/{owner}/{repo}/issues/{n}/labels/in-progress >/dev/null 2>&1; gh issue comment {n} --body "🤖 /sdlc:{command} completed: {outcome}. Lock released."`
