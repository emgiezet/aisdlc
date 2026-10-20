---
ticket: GH-43-b
title: Finished tasks are archived — redacted logs, reports, manifest and index — and survive clean
status: approved
stacks: [bash]
depends-on: GH-43-a
---

# GH-43-b — Archive a task when it reaches a terminal status

Source: https://github.com/emgiezet/aisdlc/issues/43 · plan: `specs/GH-43/decomposition.md`

## Problem

Everything a queued task leaves behind is per repo and short-lived: `aisdlc clean` deletes the
task dir, and the worktree holding `qa-report.md`, `scope-report.md`, `verify-report.md`,
`BLOCKED.md` and `pr-body.md` is removed on success and on refusal. Phase logs carry prompts and
results verbatim, with nothing redacted. A failed task's evidence is gone weeks later.

## Scope

In:
- When a task reaches `done`, `failed`, `refused` or `cancelled`, and before any worktree removal,
  write `<root>/<repo-slug>/<YYYY-MM>/<task-id>/` with: `manifest.json`, `task.json`,
  `phases/<phase>.log` and `phases/<phase>.json`, and `spec/` holding whichever of `spec.md`,
  `qa-report.md`, `scope-report.md`, `verify-report.md`, `pr-body.md`, `BLOCKED.md` exist.
- `<root>` = `$AISDLC_ARCHIVE`, else `${XDG_DATA_HOME:-$HOME/.local/share}/aisdlc/archive`.
  `<repo-slug>` = repo directory basename + `-` + first 8 hex of sha256 of its absolute path
  *(inferred: two checkouts named alike never share a slug)*.
- `manifest.json`: id, ticket, repo, base, branch, pr_url, status, attempts, cost_usd, runtime,
  runtime_version, models, `sessions` (from `task.json`), aisdlc `VERSION`, `policy_fingerprint`,
  `archived_at`, `redactions` {rule: count}, `files` {relative path: sha256}.
- Append one line to `<root>/index.jsonl` per archived task: id, ticket, repo, repo_slug,
  status, cost_usd, archived_at, path; appends are `flock`ed.
- Redaction on every archived text file, built-in rules only: Anthropic/OpenAI-style keys
  (`sk-ant-…`, `sk-…`), GitHub tokens (`ghp_`, `gho_`, `ghs_`, `github_pat_`), AWS access key ids,
  `Bearer <token>`, PEM private key blocks, and `KEY=value` lines whose key contains `TOKEN`,
  `SECRET`, `PASSWORD`, `API_KEY` or `PRIVATE`. Each match becomes `[REDACTED:<rule>]`.
- Archive entries are append-only: a second terminal status of the same task (after `retry`)
  writes `<task-id>.<attempts>/`, never overwriting the first.
- `AISDLC_ARCHIVE=off` disables archiving.
- `docs/ai-sdlc.md` and README: archive location, layout, redaction, privacy (local only).

Out:
- Transcript copies, betterleaks, and the profile switches `Archive:` / `Archive transcripts:` —
  `GH-43-c`.
- `aisdlc archive ls|show|grep|prune` — `GH-43-d`. `/sdlc:retro --archive` — `GH-43-e`.
- Redacting the live `.aisdlc/tasks/<id>/` files: only the archive copy is redacted.
- `cmd_clean` behaviour, worktree-keeping rules, status names and transitions.
- Remote upload, sync, encryption, a UI.

Change budget: 800 added lines, 5 files, 4 modules

Budget amendment approved by @emgiezet in this session: repair the reproduced security and
terminal-state blockers, rerun tests/review, and merge only after the required checks pass.

## Context

- `plugins/sdlc/bin/aisdlc` — `set_status` and its terminal call sites in `execute_task` (the
  `failed`/`refused`/`done` branches and the `git worktree remove` that follows each) and in
  `cmd_cancel`; `cmd_retry`; `cmd_clean`; `task_dir`, `task_file`, `state_dir`, `VERSION`,
  `policy_fingerprint`, `flock` usage on `queue.lock`.
- `task.json` `sessions` and `runtime_version` — added by `GH-43-a`.
- `evals/harness/selftest.sh` — `fresh_repo`, `AISDLC_STUB` modes (`ok`, failing modes), the
  refused-task cases.
- `docs/ai-sdlc.md`, `README.md` — queue sections.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-6 | queue | a stub task reaches `done` | archive dir exists at `<root>/<repo-slug>/<YYYY-MM>/<id>/` with `manifest.json`, `task.json`, `phases/*.log`, `spec/spec.md`, `spec/qa-report.md`; `sha256sum` of every file equals its `manifest.files` entry | selftest |
| UC-7 | queue | same | `<root>/index.jsonl` gained exactly one line, with that `id`, `status` `done` and the archive `path` | selftest |
| UC-8 | queue | a stub phase log contains a planted `sk-ant-api03-…` key | the archived log has `[REDACTED:anthropic-key]` where the key was, `manifest.redactions["anthropic-key"]` ≥ 1, the live task log is unchanged | selftest |
| UC-9 | queue | a stub task ends `failed` (worktree kept) | archived with `status` `failed` and the worktree's `spec/` reports present | selftest |
| UC-10 | queue | a task is `refused` with `BLOCKED.md` in its worktree | archive holds `spec/BLOCKED.md`, copied before the worktree was removed | selftest |
| UC-11 | maintainer | `aisdlc clean --all` after UC-6 | archive tree and `index.jsonl` byte-identical to before | selftest |
| UC-12 | maintainer | runs a task with `AISDLC_ARCHIVE=off` | no `<root>` directory created, no `index.jsonl` line | selftest |
| UC-13 | maintainer | `aisdlc retry` on the `failed` task from UC-9, which then reaches `done` *(inferred)* | a second dir `<id>.<attempts>/`; the first archive dir unchanged; two index lines for the id | selftest |

## Non-functional

- Archiving never changes a task's status or the runner's exit code: a failed archive write
  (unwritable `<root>`, full disk) logs `archive failed: <reason>` to the task log and continues
  *(inferred)*.
- `cancelled` tasks are archived like the others; they have no phase logs *(inferred)*.
- Every archived file is redacted before its sha256 is computed.
- `make selftest`, `plugins/sdlc/tests/run-tests` and `CI= make validate` pass.

## Open questions

none
