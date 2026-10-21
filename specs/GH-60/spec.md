---
ticket: GH-60
title: "local tracker: ship records the PR in the worktree's .aisdlc/tracker, invisible to the runner and lost on clean"
kind: bugfix
status: approved
approved-by: issue #60 (label bug, @emgiezet)
stacks: [bash]
---

## Problem

When `aisdlc` creates a git worktree and runs phases inside it, the local tracker descriptor
(`templates/trackers/local.md`) resolves `.aisdlc/tracker/…` relative to cwd. The `ship` phase's
`create-pr` operation writes `prs.jsonl` into `<worktree>/.aisdlc/tracker/`, not into
`<repo>/.aisdlc/tracker/`. The runner's `tracker_local_pr_claim`, `aisdlc inbox`, and a manual
`merge-pr` all read from the repo root, so the PR record is invisible to them and is deleted with
the worktree on `retry` or `clean --all`.

## Scope

In:
- In `execute_task` (`plugins/sdlc/bin/aisdlc`), after a successful `git worktree add`, when
  `tracker_kind "$repo"` equals `local`: call `mkdir -p "$repo/.aisdlc/tracker"` to ensure the
  target exists, then `ln -sfn "$repo/.aisdlc/tracker" "$wt/.aisdlc/tracker"` (creating
  `"$wt/.aisdlc/"` first). Log the link action to `run.log`. A failure at this step sets the task
  to `failed` with a descriptive `.error` entry, logs the error, and leaves the worktree in place
  for inspection — consistent with the playbook's rule that failed tasks keep their worktree.
- New `AISDLC_STUB=localpr` mode in `evals/harness/stub-claude`: the ship case appends one JSON
  line to `.aisdlc/tracker/prs.jsonl` relative to cwd (mirroring what `create-pr` does), then
  outputs `PR: #1 (specs/$ticket/pr-body.md)`.
- New selftest case in `evals/harness/selftest.sh` covering UC-1 through UC-6.
- One row added to the Failure modes table in `docs/ai-sdlc.md`.

Out:
- `plugins/sdlc/templates/trackers/local.md` — descriptor unchanged; the symlink makes its
  relative paths resolve correctly without any descriptor edit.
- `/sdlc:update`, `commands/init.md`, `commands/update.md` — no new config key is introduced;
  the symlink behaviour is automatic and requires no user configuration.
- Repos using the github tracker — `tracker_kind` returns `github`; the symlink block is not
  entered and the worktree is created as before.
- `evals/fixtures/sandbox/` — must not be touched.
- `verify` clean-tree check — `.aisdlc/` is gitignored for all worktrees via the `/.aisdlc/`
  entry written by `init_state` into `git info/exclude`; `git status --porcelain` will not
  surface the symlink.

Change budget: 150 added lines, 4 files, 3 modules

## Context

- `execute_task` in `plugins/sdlc/bin/aisdlc`: the `git worktree add` block (search:
  `"if ! git -C \"$repo\" worktree add"`); symlink insertion goes in the success path immediately
  after that block, before `seed_spec`.
- `tracker_kind` in `plugins/sdlc/bin/aisdlc`: returns `local` when `.claude/sdlc.md` names
  the local descriptor, when `.aisdlc/tracker/` already exists, or when `gh` is absent — the
  canonical single-source check for tracker type.
- `init_state` in `plugins/sdlc/bin/aisdlc`: writes `/.aisdlc/` to `git info/exclude` of the
  common git dir, gitignoring `.aisdlc/` in all worktrees; confirms that the symlink is invisible
  to `git status --porcelain` and does not affect the verify clean-tree check.
- `run_verify` in `plugins/sdlc/bin/aisdlc`: clean-tree check (`git status --porcelain
  --untracked-files=all | grep -vE '^(\.claude/|\.aisdlc-)'`); `.aisdlc/` is gitignored, so the
  symlink never appears regardless of the grep filter.
- `tracker_local_pr_claim` and `tracker_local_pr_release` in `plugins/sdlc/bin/aisdlc`: already
  reference `$repo/.aisdlc/tracker/prs.jsonl` via the absolute `$repo` variable; once the symlink
  routes the write-side to the same file these functions need no change.
- `evals/harness/stub-claude`: `AISDLC_STUB` selects stub behaviour; existing modes `ok`, `dirty`,
  `nouc`, `skiptest`, `mdonly`, `nosid`, `blocked`; `localpr` extends the `ship` case inside
  `case "${AISDLC_STUB:-ok}"`.
- `docs/ai-sdlc.md`: Failure modes table is the insertion target.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | runner | creates worktree for repo where `tracker_kind "$repo"` = `local` and `$repo/.aisdlc/tracker/` exists | `$wt/.aisdlc/tracker` is a symlink; `readlink` resolves to `$repo/.aisdlc/tracker` | regression |
| UC-2 | `localpr` stub ship | appends JSON to `.aisdlc/tracker/prs.jsonl` in the worktree cwd | `jq -e .url "$repo/.aisdlc/tracker/prs.jsonl"` returns `local#1`; `aisdlc inbox` lists the task | regression |
| UC-3 | runner | `aisdlc clean --all` after ship completes | `$repo/.aisdlc/tracker/prs.jsonl` retains the PR record; worktree directory no longer exists | regression |
| UC-4 | runner | creates worktree for repo where `tracker_kind "$repo"` = `local` and `$repo/.aisdlc/tracker/` is absent | `$repo/.aisdlc/tracker/` is created; `$wt/.aisdlc/tracker` is a symlink resolving to it | regression |
| UC-5 | runner | symlink creation step fails (e.g. `$wt/.aisdlc/` not writable) | task status is `failed`; `.error` field is set; `run.log` records the failure; worktree directory is retained at `$wt`; no phase (implement/qa/ship) is invoked | regression |
| UC-6 | runner | creates worktree for repo where `tracker_kind "$repo"` = `github` | no `$wt/.aisdlc/tracker` symlink is created; worktree creation succeeds; task proceeds normally | regression |

## Non-functional

- Symlink creation failure must not remove the worktree (contrast: `git worktree add` failure,
  which never created a worktree, does remove nothing — these are not equivalent paths).
- `git worktree remove --force` removes the worktree directory and its `.aisdlc/tracker` symlink
  entry; the symlink target `$repo/.aisdlc/tracker/` is unaffected. No extra cleanup required.

## Open questions

None.
