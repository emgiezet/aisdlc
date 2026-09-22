# Tracker provider: {name}

Copy to `.claude/trackers/{name}.md`, set **Tracker descriptor** in `.claude/sdlc.md` to that path,
and fill every operation below. Commands name operations in bold (**get-issue**); this file says how
each one runs. It is the whole integration surface — no command changes for a new tracker.

Rules for a provider:

- One `### <operation>` per heading below, body = the exact command with `{param}` placeholders,
  then `Returns:` one line. A heading left empty strands every command that names it.
- Split setups are normal: issues in one tool, PRs on the code host. Implement the *Issues*
  section here and write `Pull requests: as in github.md` for the rest.
- Mutations go through the plainest API the tracker has; read back what you wrote before
  returning. A label write that fails must not be reported as success.
- Never grant what `guard` blocks: no `--force`, no `--no-verify`.
- Label mutations check the label exists first; missing → print `label {label} absent — skipped`
  and continue. Only **ensure-labels** creates labels.
- Identity: the automation user **current-user** returns is the one claims and reviews are
  attributed to.

## Prerequisites

{CLI or API, how to authenticate, minimum version — and the **auth-check** command}

## Conventions

{identifier syntax in text (`#123`), how a PR names the issue it fixes (`Fixes #123`), draft PR
equivalent, comment formatting}

## Operations

### auth-check
### current-user
### get-issue        {n} → number, title, body, state, labels, assignees, author, comments
### search-issues    {query} {state} → number, title, url
### create-issue     {title} {body} {labels} → number, url
### comment-issue    {n} {body}
### close-issue      {n} {comment}
### label-issue      {n} {label}
### unlabel-issue    {n} {label}
### assign-issue     {n} {user}
### get-pr           {n} → number, title, body, state, labels, assignees, author, headRefName, baseRefName, mergeable, reviews, comments, mergeCommit, url
### list-prs         {state} {label} → number, title, labels, url, headRefName, isDraft, createdAt, author
### search-prs       {query} {state} → number, title, url
### create-pr        {title} {body-file} {base} {draft} [{verdict}] → number, url
### update-pr        {n} {title} {body-file}
### comment-pr       {n} {body-file}
### label-pr         {n} {label}
### unlabel-pr       {n} {label}
### assign-pr        {n} {user}
### review-pr        {n} {approve|request-changes} {body-file}
### merge-pr         {n} → squash
### get-pr-diff      {n}
### get-pr-checks    {n} → name, state, link
### get-run-failed-logs {run-id}
### rerun-check      {run-id} → reruns only the failed jobs of a CI run
### checkout-pr      {n} → PR head checked out locally (forks included)
### attach-image-evidence {n} {slug} {image...} → comment with inline images; never touches the PR branch
### ensure-labels    {label...} → creates the missing ones
### claim            {issue|pr} {n} {command} → assign to current-user, label in-progress, comment `🤖 /sdlc:{command} claimed {ISO}`
### check-claim      {issue|pr} {n} → `free | mine | other:<login> | stale:<login>` (stale: another's claim older than 60 min)
### release          {issue|pr} {n} {command} {outcome} → unlabel in-progress, comment `🤖 /sdlc:{command} completed: {outcome}. Lock released.`
