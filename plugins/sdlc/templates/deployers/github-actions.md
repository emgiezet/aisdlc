# Deploy target: github-actions

GitHub Actions workflows used as the deploy mechanism. Deployment state is tracked through the
GitHub Deployments API; workflow triggers use `gh workflow run`. Read operations require `repo`,
`actions:read`, and `deployments:read`; **promote** and **rollback** additionally need
`actions:write` (fine-grained token) or the classic `workflow` scope to dispatch workflows.

## Prerequisites

`gh` ≥ 2.40, authenticated: run `gh auth status` before any other operation. The workflows
`{deploy-workflow}` and `{promote-workflow}` must exist in `.github/workflows/`.
`{promote-workflow}` must declare `workflow_dispatch` inputs named `environment` and `ref`;
`gh workflow run` rejects a trigger that names inputs the workflow does not declare.

## Conventions

Environments match the names in the GitHub repository's Environments settings. Deployment state
is read from the Deployments API, not from workflow run conclusions. GitHub deployment states
map to the descriptor vocabulary: `success` → `succeeded`; `failure`/`error` → `failed`;
`pending`/`queued`/`in_progress` or no status posted yet → `in-progress`; `inactive` → `unknown`.
Rollback is a promotion of an older ref — the deploy pipeline must be idempotent. A target
whose pipeline is not idempotent needs its own `### rollback` body; that is a finding about the
deploy pipeline, not about this file.

## Operations

### deploy-status
`dep_id=$(gh api "repos/{owner}/{repo}/deployments?environment={env}&per_page=1" --jq '.[0].id // empty') && [ -n "$dep_id" ] || { echo "no deployment record found for {env}"; exit 1; }`.
`sha=$(gh api "repos/{owner}/{repo}/deployments/$dep_id" --jq '.sha // empty') && [ -n "$sha" ] || { echo "deployment $dep_id has no sha"; exit 1; }`.
`st=$(gh api "repos/{owner}/{repo}/deployments/$dep_id/statuses?per_page=1") && [ -n "$st" ] || { echo "failed to read statuses for deployment $dep_id"; exit 1; }`.
`printf '%s\n' "$st" | jq -r --arg sha "$sha" '(.[0] // {}) | if .state == "success" then "succeeded" elif (.state == "failure" or .state == "error") then "failed" elif .state == "inactive" then "unknown" else "in-progress" end + " " + $sha + " " + (.updated_at // "")'`
Returns: state (succeeded|failed|in-progress|unknown), sha, finished-at on one line.

### current-release
`sha=$(gh api "repos/{owner}/{repo}/deployments?environment={env}&per_page=1" --jq '.[0].sha // empty') && [ -n "$sha" ] || { echo "no deployment record found for {env}"; exit 1; }`.
`echo "$sha"`
Returns: the sha most recently deployed to `{env}`. Projects that tag instead of using the
Deployments API replace this with `git describe --tags --abbrev=0 {env-tag-pattern}`.

### env-diff
`from_sha=$(gh api "repos/{owner}/{repo}/deployments?environment={from-env}&per_page=1" --jq '.[0].sha // empty') && [ -n "$from_sha" ] || { echo "no deployment found for {from-env}"; exit 1; }`.
`to_sha=$(gh api "repos/{owner}/{repo}/deployments?environment={to-env}&per_page=1" --jq '.[0].sha // empty') && [ -n "$to_sha" ] || { echo "no deployment found for {to-env}"; exit 1; }`.
`git fetch --quiet origin && git log --oneline --no-merges "${to_sha}..${from_sha}"`
Returns: one line per commit in `{from-env}` not yet in `{to-env}`: sha, subject, PR number when derivable from the subject line.

### pending-migrations
`{the project's migration status command, e.g. migrate -database "$DATABASE_URL_{env}" status}`
Returns: one line per migration present in the code but not applied in `{env}`; empty means none.

### promote
`ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)`.
`gh workflow run {promote-workflow} -f environment={env} -f ref={ref}`.
`url=''; n=0; while [ $n -lt 12 ] && [ -z "$url" ]; do sleep 5; url=$(gh run list --workflow {promote-workflow} --event workflow_dispatch --limit 10 --json url,createdAt | jq -r --arg ts "$ts" '[.[] | select(.createdAt >= $ts)] | .[0].url // ""'); n=$((n+1)); done`.
`[ -n "$url" ] && echo "$url" || { echo "no dispatch run appeared within 60 s of trigger"; exit 1; }`
Returns: the dispatch run URL. Confirm with **deploy-status** `{env}` before reporting the
promotion complete. A non-zero exit from `gh workflow run` means the trigger was rejected — stop
and report the error; do not proceed to the polling loop.

### rollback
`ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)`.
`gh workflow run {promote-workflow} -f environment={env} -f ref={ref}`.
`url=''; n=0; while [ $n -lt 12 ] && [ -z "$url" ]; do sleep 5; url=$(gh run list --workflow {promote-workflow} --event workflow_dispatch --limit 10 --json url,createdAt | jq -r --arg ts "$ts" '[.[] | select(.createdAt >= $ts)] | .[0].url // ""'); n=$((n+1)); done`.
`[ -n "$url" ] && echo "$url" || { echo "no dispatch run appeared within 60 s of trigger"; exit 1; }`
Returns: the dispatch run URL. Confirm with **deploy-status** `{env}` before reporting success.
Rollback is a promotion of an older ref; a refused trigger is a human's problem, not a reason to
retry.
