---
ticket: GH-43-f
title: "manifest.phases per-phase provenance and model identity"
status: approved
stacks: [bash]
depends-on: GH-43-b
---

# GH-43-f — manifest.phases provenance and model identity

Source: https://github.com/emgiezet/aisdlc/issues/43 · plan: `specs/GH-43/decomposition.md`

## Problem

The issue requires `manifest.json` to include `phases[{name, verdict, session_id, started,
ended}]` and full model identity. Two gaps remain after GH-43-b (PR #61):

1. **Phases absent from manifest.** GH-43-b copies only `sessions[]` from `task.json`. Sessions
   cover only claude/omp phases (implement, qa, ship, review, triage, root-cause) and lack a
   `verdict` field. Native phases (`scope-check`, `verify`) have their verdicts in `.scope_verdict`
   and `.verify_verdict` but no timestamps, and never appear in `sessions[]`.

2. **Model identity lost for single-model tasks.** PR #61 manifest generation uses
   `models:(.models//null)`. When no `model_roles` are configured, `.models` is absent and the
   manifest records `"models": null`, silently discarding `task.json .model` — the actual model
   used for every phase.

## Scope

In:
- **`execute_task()` phase-log capture** in `plugins/sdlc/bin/aisdlc`: in the phase loop
  (`:2090-2120`), wrap each phase call to capture a `phase_log[]` entry in `task.json`:
  - Before calling `run_scope_check`, `run_verify`, or `run_phase`: record `started="$(ts)"`.
  - After return (success or failure): record `ended="$(ts)"` and `verdict`.
    - scope-check: verdict from `task_get "$repo" .scope_verdict "$id"` (PASS/GAPS/BLOCKED).
    - verify: verdict from `task_get "$repo" .verify_verdict "$id"` (PASS/FAIL).
    - claude/omp phases: verdict = PASS only when invocation and the runner's post-phase
      checks succeed; otherwise FAIL (including GH-52's no-change guard). Determine `session_id` by
      comparing `.sessions | length` before and after calling `run_phase`: if the count
      increased by exactly 1 and the new last entry has `phase == <current phase>`, use its
      `session_id`; otherwise `session_id = null`. This handles the omp early-return path
      (`:1081-1085`: command file absent → return 1 without appending a session entry) and
      guards against attaching a prior retry's session to a new failed invocation.
  - Append `{name, verdict, session_id, started, ended}` to `task.json .phase_log[]`.
    `session_id` is null for native phases.
  - Recording is unconditional: phases that fail still get an entry. A phase that did not run
    (task stopped earlier) gets no entry — `phase_log[]` reflects only what executed.
- **`archive_task()` manifest fix** in `plugins/sdlc/bin/aisdlc`:
  - Replace `models:(.models//null)` with two fields:
    - `model: (.model // null)` — preserve the recorded base model; never invent missing historical identity.
    - `models: (.models // null)` — per-phase model map; null when no `model_roles`.
  - Add `phases: (.phase_log // null)` — copies phase_log as `manifest.phases`; null when
    archiving a legacy task record without phase_log. Existing archives remain untouched.
- `evals/harness/selftest.sh`: new UC-31 through UC-37 test cases.
- `docs/ai-sdlc.md`: update archive section to note `phases[]` and `model` fields.

Out:
- Changing `task.json .sessions[]` contract (GH-43-a; merged).
- Per-phase cost attribution or cost-delta calculation.
- Retroactive backfill of phase_log for tasks already in the archive.
- Changes to `run_scope_check()` or `run_verify()` signatures; all new recording is in
  `execute_task()`'s wrapper only.
- Model identity in individual `sessions[]` entries (GH-43-a contract; not extended here).

Change budget: 300 added lines, 3 files, 3 modules

## Context

- `plugins/sdlc/bin/aisdlc` — `execute_task()` phase loop (`:2087-2120`); `run_scope_check()`
  stores `.scope_verdict` via `task_set "$repo" "$id" --arg v "$verdict" '.scope_verdict = $v'`
  (`:1681`, `:1820`); `run_verify()` stores `.verify_verdict` similarly (`:2003`);
  `run_phase()` appends to `.sessions[]` (`:1098-1104`) only when the phase reaches the
  `task_set` call; the omp early-return at `:1081-1085` (command file absent) exits before
  that call, leaving `.sessions[]` unchanged. The count-before/after comparison detects both
  this case and retry contamination.
  `archive_task()` manifest generation (PR #61 diff): `models:(.models//null)` is the gap line;
  `sessions` copied verbatim from task.json; no `phases` field.
- `task.json` fields relevant here: `.model` (base model, set at add time, always present,
  `:693`); `.models` (per-phase map, only when model_roles, `:699`); `.scope_verdict`; 
  `.verify_verdict`; `.sessions[]` (claude/omp phases only, no verdict).
- `evals/harness/stub-claude` — `AISDLC_STUB=blocked` causes implement to fail with BLOCKED.md;
  `AISDLC_STUB=ok` (default) runs all phases successfully.
- `evals/harness/selftest.sh` — `fresh_repo`, `arc_slug()`, `task_field`, `AISDLC_ARCHIVE`
  env pattern (UC-6–UC-13); model_roles test at model-roles section (UC-2).
- `evals/harness/selftest.sh` UC-12: `AISDLC_ARCHIVE=off` → no archive, used for negative.
- Phase name set: `ALL_PHASES="implement qa scope-check verify ship review"` (`:28`);
  `ISSUE_PHASES` includes triage and root-cause.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-31 | queue | stub task reaches `done` with all phases | `manifest.phases` is a non-null array with one entry per executed phase; each entry has `name`, `verdict`, `started`, `ended`; native phases (`scope-check`, `verify`) have `session_id: null`; claude phases have non-null `session_id`; all verdicts are `PASS` | selftest |
| UC-32 | queue | implement fails either with `AISDLC_STUB=blocked` or GH-52's report-only `refuse` mode | `manifest.phases` entry for `implement` has `verdict: "FAIL"` even when the model reported success but the runner rejected its empty diff; phases after implement are absent | selftest |
| UC-33 | queue | scope-check returns BLOCKED (spec Out: blocks the stub's committed path) | `manifest.phases` has entries for `implement` and `qa` with `verdict: "PASS"` (they ran before scope-check); `scope-check` entry has `verdict: "BLOCKED"`, `session_id: null`, non-null `started`/`ended`; phases after scope-check (`verify`, `ship`, `review`) absent from `manifest.phases` | selftest |
| UC-34 | queue | verify returns FAIL (`verify` commands exit non-zero or none configured) | `manifest.phases` entry for `verify` has `verdict: "FAIL"`; `session_id: null`; `started` and `ended` non-null | selftest |
| UC-35 | queue | archive a persisted legacy task record with no `.phase_log` after GH-43-f is installed | new manifest has `phases: null`; no timestamps or verdicts are invented; previously archived files remain untouched | selftest |
| UC-36 | queue | single-model task (no `model_roles` in `.aisdlc/config.json`) | `manifest.model` equals the task's `.model` string (non-null); `manifest.models` is `null` | selftest |
| UC-37 | queue | model_roles configured: smol/default/slow | `manifest.model` equals the base model string (non-null); `manifest.models` has per-phase entries matching the roles map | selftest |

## Non-functional

- `phase_log[]` recording failure is non-fatal: a `task_set` error must not stop phase execution.
- `manifest.model` preserves task.model when recorded; legacy records without it yield null,
  not an inferred model.
- Phase entries in `phase_log[]` are append-only and ordered by execution sequence; no
  retroactive modification after the phase completes.

## Open questions

none
