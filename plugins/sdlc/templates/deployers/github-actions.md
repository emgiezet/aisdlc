# Deploy target: github-actions

GitHub Actions workflows used as the deploy mechanism. Deployments are triggered via
`gh workflow run` and tracked through the GitHub Deployments API. All operations require `gh`
authenticated with the scope needed to trigger workflows and read deployment records.

## Prerequisites

`gh` ≥ 2.40, authenticated: run `gh auth status` before any other operation. The workflows
`{deploy-workflow}` and `{promote-workflow}` must exist in `.github/workflows/`.

## Conventions

Environments match the names registered in the GitHub repository's Environments settings.
A deployment is identified by its run URL, read back via `gh run list` after trigger.
Rollback is a promotion of an older ref — the deploy pipeline is idempotent by design. A
target whose pipeline is not idempotent needs a separate `### rollback` body, and that is a
finding about the deploy pipeline, not about this file.

## Operations

### deploy-status
`gh run list --workflow {deploy-workflow} --branch {branch} --limit 1 --json conclusion,headSha,updatedAt --jq '.[0] | "\(.conclusion // "in-progress") \(.headSha) \(.updatedAt)"'`
Returns: state (succeeded|failed|in-progress|unknown), ref, finished-at on one line.

### current-release
`gh api repos/{owner}/{repo}/deployments -X GET -f environment={env} --jq '.[0].sha'`
Returns: the sha GitHub records as most recently deployed to `{env}`. Projects that tag instead
of using the Deployments API replace this body with
`git describe --tags --abbrev=0 {env-tag-pattern}`.

### env-diff
`git fetch --quiet origin && git log --oneline --no-merges $(gh api repos/{owner}/{repo}/deployments -X GET -f environment={to-env} --jq '.[0].sha')..$(gh api repos/{owner}/{repo}/deployments -X GET -f environment={from-env} --jq '.[0].sha')`
Returns: one line per commit in `{from-env}` not yet in `{to-env}`: sha, subject, and PR number
when derivable from the subject line.

### pending-migrations
`{the project's migration status command, e.g. migrate -database "$DATABASE_URL_{env}" status}`
Returns: one line per migration present in the code but not applied in `{env}`; empty means none.

### promote
`gh workflow run {promote-workflow} -f ref={ref} -f environment={env} && sleep 5 && gh run list --workflow {promote-workflow} --limit 1 --json databaseId,url --jq '.[0].url'`
Returns: the run URL; read back with **deploy-status** using `{promote-workflow}` and the ref's
branch before reporting the promotion complete. A non-zero exit from `gh workflow run` means the
workflow was rejected — stop and report the error; do not proceed.

### rollback
`gh workflow run {promote-workflow} -f ref={ref} -f environment={env} && sleep 5 && gh run list --workflow {promote-workflow} --limit 1 --json databaseId,url --jq '.[0].url'`
Returns: the run URL, read back with **deploy-status** before reporting success. Rollback is a
promotion of an older ref; a refused run is a human's problem, not a reason to retry.
