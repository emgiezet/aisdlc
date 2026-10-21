---
ticket: GH-52
title: "aisdlc run: implement that changes nothing passes; later phases judge an empty diff"
kind: bugfix
status: approved
approved-by: issue #52 (label bug, @emgiezet)
stacks: [bash]
depends-on: GH-51
---

# GH-52 — implement that changes nothing passes; later phases judge an empty diff

Source: https://github.com/emgiezet/aisdlc/issues/52

## Problem

When `implement` exits with `is_error: false` and non-zero turns but commits no real files (only
`specs/<TICKET>/BLOCKED.md`, or nothing beyond agent-config paths), the runner treats it as
success. The subsequent `scope-check`, `qa`, and `verify` phases judge an empty diff and the task
fails at `verify` with a misleading error (`untested: UC-…`, `uv sync exited 2`) rather than
naming the actual cause.

## Scope

In:
- `execute_task` in `plugins/sdlc/bin/aisdlc`: after `run_phase` returns 0 for the `implement`
  phase, call `_branch_changes "$wt" "$base" "$specs_dir/$ticket"` (GH-51 API:
  `_branch_changes <wt> <base> <task-specdir-relative>` where the third arg is the
  ticket-specific spec path relative to `$wt`, e.g. `$specs_dir/$ticket`). If the output is
  empty (no changed files outside `specs/<TICKET>/` and agent-config paths), mark the task
  `failed` immediately — `qa` must never run in this path. Error stored in `task.json .error`:
  `phase 'implement' failed — it changed no file; see implement.json for why`.
- `evals/harness/stub-claude`: add `refuse` stub mode. For `/implement*` it commits only
  `specs/$ticket/BLOCKED.md` and returns `is_error: false` with non-zero turns (mimics an
  implement that wrote a BLOCKED file and claimed success). Other phases are unreachable in
  this mode and fall through to the default result.
- `evals/harness/selftest.sh`: add a selftest case exercising `AISDLC_STUB=refuse`; asserts
  task fails, `qa.json` is absent in the task dir, and `task.json .error` contains
  `"changed no file"`.
- `docs/ai-sdlc.md`: extend the zero-turn guard paragraph with one sentence naming the
  empty-diff guard and its error message.

Out:
- `_branch_changes` implementation — owned by GH-51; this spec only calls it.
- Changes to `run_scope_check`, `run_verify`, `run_phase`, or any phase other than the
  post-implement hook in `execute_task`.
- New spec-level configuration to override the empty-diff check.
- The `BLOCKED.md` handling in `check_spec` or in the issue-mode spec gate.
- CI matrix, Makefile, or any file under `plugins/sdlc/{commands,skills,agents,templates}/`.

Change budget: 45 added lines, 4 files, 3 modules

## Context

- `plugins/sdlc/bin/aisdlc` — `execute_task`: the phase-dispatch loop (`while read -r phase`);
  the existing post-`run_phase` block that parses `ship` results is the anchor; the new
  no-change check inserts after the `elif ! run_phase …` branch, guarded by
  `[ "$phase" = "implement" ]`.
- `plugins/sdlc/bin/aisdlc` — `run_phase`: already records `is_error`, `num_turns`, and the
  phase result into `$dir/${phase}.json`; the no-change diagnostic points to this existing
  artifact without parsing or rewriting its result.
- `plugins/sdlc/bin/aisdlc` — `_branch_changes` (added by GH-51): signature
  `_branch_changes <wt> <base> <task-specdir-relative>`, stdout newline-separated paths with
  the named specdir and agent-config paths (`.claude/`, `AGENTS.md`, `CLAUDE.md`) excluded.
  Returns empty output when no meaningful file changed.
- `evals/harness/stub-claude` — `blocked` mode: the existing reference for a stub that writes
  `specs/$ticket/BLOCKED.md` and returns `is_error: true`; `refuse` is structurally similar
  but returns `is_error: false` so the runner's existing `is_error` check does not catch it.
- `evals/harness/selftest.sh` — `noop` test case (`AISDLC_STUB=noop`): structural model for
  the `refuse` test; same three-assertion pattern: status, artifact absence, error text.
- `docs/ai-sdlc.md` — zero-turn guard paragraph (near `num_turns == 0`): the natural home for
  a companion sentence about the empty-diff guard.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | queue runner | `AISDLC_STUB=refuse aisdlc run --once` on an approved spec; stub commits only `specs/SBX-1/BLOCKED.md` with non-zero turns and `is_error:false` | `task.json .status` = `failed`; `qa.json` absent in the task dir; `task.json .error` = `phase 'implement' failed — it changed no file; see implement.json for why` | selftest |
| UC-2 | queue runner | `AISDLC_STUB=ok aisdlc run --once` on the same fixture (regression guard) | `task.json .status` = `done`; `qa.json` present in task dir | selftest |
| UC-3 | queue runner | `_branch_changes` called with a worktree where only `.claude/rules/test.md` changed since base (agent-config-only diff) | helper returns empty output | unit (inline in selftest) |

## Non-functional

- The empty-diff check is one `git diff --name-only` call (no model invocation); it runs only
  on the `implement` phase and adds no extra model turns.
- The check only fires for the `implement` phase; no other phase gains this guard.

## Open questions

none
