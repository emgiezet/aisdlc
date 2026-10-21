---
ticket: GH-40
title: "aisdlc add: optional readiness score on the smol model before a spec is queued"
status: approved
stacks: [bash, instructions]
source: https://github.com/emgiezet/aisdlc/issues/40
---

## Problem

`check_spec` gates queuing on `status: approved` and no unresolved open questions, but makes no
judgment about quality. An approved spec can still carry acceptance criteria that are not
checkable ("works correctly"), undeclared file scope, or contradictions between `In:` and `Out:`.
These vague specs reach implement and QA before the deficiency surfaces, burning token budget on
output that still fails review or lands as a low-quality PR.

## Scope

In:
- `plugins/sdlc/bin/aisdlc`: new `readiness_check` function; wired into `cmd_add` after
  `check_spec` passes, skipped for the `--issue` route; `cmd_status` output gains a `READY`
  column from `.readiness_score`; `cmd_help` documents `readiness_min` in the config block.
- `plugins/sdlc/prompts/readiness.md`: new rubric file with scoring criteria (In/Out
  consistency, checkable acceptance criteria, declared file scope, open dependencies); loaded
  at runtime so operators can edit without touching the binary.
- `plugins/sdlc/commands/init.md` and `plugins/sdlc/commands/update.md`: add `readiness_min`
  with a null default, preserving configured values. Initialization/update must not enable
  scoring; only an explicitly configured numeric threshold opts in.
- `evals/harness/selftest.sh`: cover the behavioral criteria below, reusing existing runtime
  wrappers; help documentation is checked by a throwaway smoke, not a text-pinning unit test.
- `docs/ai-sdlc.md`: add `readiness_min` to the configuration table in the spec-gate section.

Out:
- Shipping or bundling a local model; the check runs on whatever `model_roles.smol` resolves to.
- Re-scoring inside the worktree.
- Changing any existing `check_spec` logic; this gate runs only after `check_spec` passes.
- New model config keys; reuse the `model_roles.smol` path already resolved in `cmd_add`.
- Auto-committing `readiness.md`; it is written to disk only.

Change budget: 400 added lines, 8 files, 3 modules

## Context

- `plugins/sdlc/bin/aisdlc` — `check_spec`: current spec gate (status + open-question count);
  `readiness_check` runs only after this returns zero.
- `plugins/sdlc/bin/aisdlc` — `phase_role`: maps phase → cost role; `smol` covers scope-check,
  ship, verify. Reuse this role for `readiness_check`; no new model config key.
- `plugins/sdlc/bin/aisdlc` — `cfg`: `readiness_min` is a `.aisdlc/config.json` setting only;
  absent or null means feature off. No new CLI flag or environment variable is introduced.
- `plugins/sdlc/bin/aisdlc` — `cmd_add`: the non-`--issue` branch runs the spec gate; `runtime`
  and the smol model name are both resolved before the task JSON is assembled; `--force` path
  already bypasses the spec gate with a warning — follow the same pattern for readiness.
- `plugins/sdlc/bin/aisdlc` — `invoke_claude` / `invoke_omp`: runtime-specific headless
  invocation; `readiness_check` uses whichever runtime was resolved, with the smol model and
  the same billing behaviour (subscription omits `--max-budget-usd`).
- `plugins/sdlc/bin/aisdlc` — `cmd_status`: tabular output via `jq` over `task.json` fields;
  `READY` column reads `.readiness_score // "-"`.
- `plugins/sdlc/bin/aisdlc` — `cmd_help`: inline heredoc documents `model_roles` with a table;
  `readiness_min` is added in the same block.
- `plugins/sdlc/commands/init.md` — config.json keys list (the `{"model","budget",…}` block):
  append `readiness_min: null` (disabled).
- `plugins/sdlc/commands/update.md` — `## Phase 3 — Config keys`: lists the keys
  `/sdlc:update` adds to `.aisdlc/config.json`; append a null default without overwriting opt-ins.
- Model response contract (from issue): score 0–100, at most 5 concrete gaps, each naming a
  spec section; parsed as JSON `{"score": <int>, "gaps": [<string>, …]}`.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | operator | `aisdlc add SBX-1` with readiness_min absent or set to null by init/update | command queues normally; no readiness model invocation or readiness_score field is added | unit |
| UC-2 | operator | `aisdlc add SBX-1` with `readiness_min: 80` and stub returning `{"score":60,"gaps":["## Acceptance criteria: rows are not checkable"]}` | Command exits non-zero; queue file remains empty; `specs/SBX-1/readiness.md` is created and contains the gap text | unit |
| UC-3 | operator | `aisdlc add SBX-1 --force` with same `readiness_min: 80` / score 60 stub | Command exits zero; warning is printed naming the score and threshold; task appears in queue; `task.json` contains `readiness_score: 60` | unit |
| UC-4 | operator | `aisdlc add SBX-1` with `readiness_min: 80` and stub returning `{"score":85,"gaps":[]}` | Command exits zero; task queued; `task.json` contains `readiness_score: 85`; `specs/SBX-1/readiness.md` is not created | unit |
| UC-5 | operator | `aisdlc status` after UC-4 | Status table row shows `85` in the `READY` column | unit |
| UC-6 | operator | `aisdlc add SBX-1` with `readiness_min: 80` and stub returning non-JSON output | Command exits non-zero with a message identifying the parse failure; queue remains empty; `--force` queues the task with a warning and `task.json` has no `readiness_score` | unit |
| UC-7 | operator | `aisdlc add --issue 42 …` (issue route) | Readiness check is skipped; issue is claimed; task is queued; no `readiness.md` written | unit |
| UC-8 | operator | `aisdlc help` after implementation | output documents readiness_min as config-only and disabled when absent/null | manual smoke |

## Non-functional

- `readiness_check` uses the runtime resolved during `cmd_add` (claude or omp) and the smol
  model role, inheriting the same billing behaviour as other smol invocations.
- The rubric prompt is loaded from `plugins/sdlc/prompts/readiness.md` at runtime.
- The model response must contain a score 0–100 and at most 5 gaps, each naming a spec section
  (source contract from issue #40).

## Open questions

_(none)_
