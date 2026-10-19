---
ticket: GH-43-a
title: task.json records each phase's agent session — id, runtime, transcript path, runtime version
status: approved
stacks: [bash]
---

# GH-43-a — Link every phase to the agent session that ran it

Source: https://github.com/emgiezet/aisdlc/issues/43 · plan: `specs/GH-43/decomposition.md`

## Problem

Nothing ties a queued task to the agent sessions that produced it. `run_phase` reads cost,
`is_error` and `num_turns` from `<phase>.json` but never its `session_id`; `task.json` holds no
session id, transcript path or runtime version. Once the worktree is gone, the Claude transcript
under `~/.claude/projects/` is keyed by a path nobody recorded, so "why did the agent do that?"
cannot be answered for any finished task.

## Scope

In:
- After every phase that invoked a runtime, append one object to a `sessions` array in
  `task.json`: `{phase, runtime, session_id, transcript, started, ended}`.
- claude: `session_id` = `.session_id` of the collapsed `<phase>.json`; `transcript` =
  `$HOME/.claude/projects/<enc>/<session_id>.jsonl`, where `<enc>` is the worktree's absolute path
  with every `/` and `.` replaced by `-`.
- omp: `session_id` = the uuid after `_` in the name of the `.jsonl` file the phase created under
  `<task dir>/sessions/` (`<ISO-ts>_<uuid>.jsonl`); `transcript` = that file's absolute path.
- `runtime_version` in `task.json`, set once per task from `<runtime> --version` (first line).
- `stub-claude` returns a per-phase `session_id`; `stub-omp` writes one `<ts>_<uuid>.jsonl` into
  its `--session-dir`.
- `docs/ai-sdlc.md`: the new `task.json` fields.

Out:
- Any archive, copy of a transcript, or redaction — `GH-43-b` and `GH-43-c`.
- `aisdlc archive …` subcommands (`GH-43-d`) and `/sdlc:retro` (`GH-43-e`).
- Phases that invoke no runtime (`scope-check`, `verify`): they add no `sessions` entry.
- Cost accounting, `collapse_result`, the 0-turn and `is_error` failure rules, `cmd_clean`.
- Reading or validating the transcript file itself; the path is recorded, not checked.

Change budget: 110 added lines, 4 files, 3 modules

## Context

- `plugins/sdlc/bin/aisdlc` — `run_phase` (after `collapse_result "$out"`), `invoke_omp`
  (`sessions="$(dirname "$out")/sessions"`, `--session-dir`), `run_claude_phase`, `task_set`,
  `cmd_add` (initial `task.json` object), `ts`.
- `evals/harness/stub-claude` — the result object printer (`"session_id":"stub"`).
- `evals/harness/stub-omp` — argv loop (`--session-dir` is currently skipped).
- `evals/harness/selftest.sh` — `fresh_repo`, `task_field`, the omp runtime cases.
- `docs/ai-sdlc.md` — the queue / `task.json` description.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | queue | a claude task runs implement and qa to `done` | `task.json .sessions` has two entries, `phase` `implement` and `qa`, `runtime` `claude`, each with the `session_id` its phase json returned and ISO `started`/`ended` | selftest |
| UC-2 | queue | same, worktree at `/tmp/x.y/wt` | each `transcript` is `$HOME/.claude/projects/-tmp-x-y-wt/<session_id>.jsonl` | selftest |
| UC-3 | queue | an omp task runs one phase | one entry with `runtime` `omp`, `session_id` equal to the uuid in the file the phase wrote under `sessions/`, `transcript` that file's absolute path | selftest |
| UC-4 | queue | a task with three phases | `task.json .runtime_version` equals the first line of `<runtime> --version`; the runtime's `--version` ran once for the task | selftest |
| UC-5 | queue | a claude phase whose json has no `session_id` *(inferred negative)* | entry present with `session_id: null` and `transcript: null`; the phase's pass/fail outcome is unchanged | selftest |

## Non-functional

- Recording a session never changes a phase's outcome or the task's status.
- `make selftest`, `plugins/sdlc/tests/run-tests` and `CI= make validate` pass.

## Open questions

none
