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
`gh label list --json name --jq '.[].name' | grep -qx '{label}' || { echo "label {label} absent — skipped"; exit 0; }; gh api -X POST repos/{owner}/{repo}/issues/{n}/labels -f 'labels[]={label}' >/dev/null`
### unlabel-issue
`gh api -X DELETE repos/{owner}/{repo}/issues/{n}/labels/{label} >/dev/null 2>&1 || true`
### assign-issue
`gh api -X POST repos/{owner}/{repo}/issues/{n}/assignees -f 'assignees[]={user}' >/dev/null`
### link-blocks
`gh api -X POST repos/{owner}/{repo}/issues/{blocked}/dependencies/blocked_by -F issue_id="$(gh api repos/{owner}/{repo}/issues/{blocker} --jq .id)" >/dev/null 2>&1 || true; gh issue view {blocked} --json body --jq .body | grep -qx 'Blocked by: #{blocker}' || { gh issue view {blocked} --json body --jq .body; printf '\nBlocked by: #{blocker}\n'; } | gh issue edit {blocked} --body-file -`
The native dependency link is additive and best effort; the body marker is the record of truth, so
a tracker without native dependency links behaves identically.
### list-blockers
`gh issue view {n} --json body --jq .body | grep -oE '^Blocked by: #[0-9]+' | grep -oE '[0-9]+' | while read -r b; do [ "$(gh issue view "$b" --json state --jq .state)" = OPEN ] && echo "$b"; done`
Returns: one open blocker number per line; empty = takeable.
### add-sub-issue
`gh api -X POST repos/{owner}/{repo}/issues/{parent}/sub_issues -F sub_issue_id="$(gh api repos/{owner}/{repo}/issues/{child} --jq .id)" >/dev/null 2>&1 || true`
Best effort; the map file's **Open tickets** table is the authoritative index.
### list-frontier
`gh issue list --label '{label}' --state open --json number,title,labels,assignees --limit 50 --jq '.[] | select((.assignees|length)==0) | [.number, ([.labels[].name] | map(select(startswith("decision:"))) | first // "decision:task"), .title] | @tsv'`
Returns: TSV `number<TAB>type-label<TAB>title`. Blockers are not filtered here — the caller drops
rows whose **list-blockers** is non-empty.
### get-pr
`gh pr view {n} --json number,title,body,state,isDraft,labels,assignees,author,headRefName,baseRefName,mergeable,reviews,comments,url,files,mergeCommit`
Returns: JSON; `mergeable` is `MERGEABLE|CONFLICTING|UNKNOWN`.
### list-prs
`gh pr list --state {state} --label '{label}' --json number,title,labels,url,headRefName,isDraft,createdAt,author --limit 50`
### search-prs
`gh pr list --search '{query}' --state {state} --json number,title,url,state`
### create-pr
`gh pr create --title '{title}' --body-file {body-file} --base {base} {draft:+--draft}`
Returns: PR URL; number is its last path segment.
### update-pr
`gh api -X PATCH repos/{owner}/{repo}/pulls/{n} -f 'title={title}' -F body=@{body-file}`
Not `gh pr edit`: it resolves the PR through a GraphQL query that still selects the retired
`projectCards` connection, which fails on gh builds predating its removal.
### comment-pr
`gh pr comment {n} --body-file {body-file}`
### get-pr-ledger
`me=$(gh api user --jq .login); gh api --paginate "repos/{owner}/{repo}/issues/{n}/comments" | jq -cs --arg me "$me" '[.[][] | select(.user.login == $me and (.body | startswith("<!-- aisdlc-ledger ")))] | last // empty | {id, body}'`
Returns: JSON `{id, body}`, or empty output when absent. Only current-user's comment counts.
### put-pr-ledger
`id=$(<get-pr-ledger> | jq -r '.id // empty'); if [ -n "$id" ]; then gh api -X PATCH "repos/{owner}/{repo}/issues/comments/$id" -F body=@{body-file} --jq .id; else gh api -X POST "repos/{owner}/{repo}/issues/{n}/comments" -F body=@{body-file} --jq .id; fi` — `<get-pr-ledger>` is the command above.
Returns: comment id.
### label-pr
same as **label-issue** — PRs are issues to the REST API.
### unlabel-pr
same as **unlabel-issue**.
### assign-pr
same as **assign-issue**.
### review-pr
`me=$(gh api user --jq .login); pr_author=$(gh pr view {n} --json author --jq .author.login)`.
Self-authored (`[ "$me" = "$pr_author" ]`): `{ printf '🤖 Review (self-authored PR) — Verdict: %s\n' "$([ '{verdict}' = approve ] && echo APPROVED || echo CHANGES_REQUESTED)"; cat {body-file}; } | gh pr comment {n} --body-file -`; labels applied separately by the caller.
Otherwise: `gh pr review {n} --{verdict} --body-file {body-file}` where `{verdict}` is `approve` or `request-changes`.
### merge-pr
`gh pr merge {n} --squash --delete-branch`
### get-pr-diff
`gh pr diff {n}`
### get-pr-checks
`gh pr checks {n} --json name,state,link,workflow` — `state` is `SUCCESS|FAILURE|PENDING|…`.
### get-run-failed-logs
`gh run view {run-id} --log-failed`
### rerun-check
`gh run rerun {run-id} --failed`
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
`me=$(gh api user --jq .login); gh api -X POST repos/{owner}/{repo}/issues/{n}/assignees -f "assignees[]=$me" >/dev/null && gh api -X POST repos/{owner}/{repo}/issues/{n}/labels -f 'labels[]=in-progress' >/dev/null && gh issue comment {n} --body "🤖 /sdlc:{command} claimed $(date -u +%FT%TZ)"`
Read back with **get-issue**/**get-pr**: all three signals present, else fail.
### check-claim
`me=$(gh api user --jq .login); data=$(gh {issue|pr} view {n} --json labels,assignees,comments)`.
`echo "$data" | jq -e '[.labels[].name]|index("in-progress")' >/dev/null || { echo free; exit 0; }`.
`echo "$data" | jq -e --arg me "$me" '[.assignees[].login]|index($me)' >/dev/null && { echo mine; exit 0; }`.
`clm=$(echo "$data" | jq -r '[.comments[]|select(.body|test("🤖 .* claimed"))]|last'); login=$(echo "$clm"|jq -r '.author.login // empty'); ts=$(echo "$clm"|jq -r '.createdAt // empty'); [ -z "$ts" ] && echo "other:${login:-$(echo "$data"|jq -r '.assignees[0].login//"unknown"')}" || { [ $(( $(date -u +%s) - $(date -d "$ts" +%s) )) -gt 3600 ] && echo "stale:$login" || echo "other:$login"; }`
### release
`gh api -X DELETE repos/{owner}/{repo}/issues/{n}/labels/in-progress >/dev/null 2>&1; gh issue comment {n} --body "🤖 /sdlc:{command} completed: {outcome}. Lock released."`
