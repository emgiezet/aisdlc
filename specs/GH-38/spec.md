---
ticket: GH-38
title: "aisdlc run: stop popping tasks at a max-open-PRs cap and a run spend cap"
status: approved
stacks: [bash, instructions]
---

# GH-38 — aisdlc run: stop popping tasks at a max-open-PRs cap and a run spend cap

## Problem

`aisdlc run` keeps popping queued tasks for as long as the queue has entries. Two limits are missing:

- **No cap on open agent PRs.** Every finished task opens a PR. A long queue can open more PRs than the team can review. Review then becomes the bottleneck and approvals turn into rubber stamps.
- **No spend cap for the whole run.** `--max-budget-usd` is applied per phase only (`BUILTIN_BUDGET="5"`). A run with many tasks has no total ceiling.

## Scope

In:
- `aisdlc run --max-open-prs N`: worker does not pop the next task while the number of open PRs carrying the profile PR label is $\ge$ N. It logs the reason and stops. Resolve CLI/config/environment through `resolve_default`; absent or null means unlimited. If an enabled cap cannot obtain a trustworthy count (provider failure, invalid local state, or unsupported tracker), stop before claiming with a count-unavailable diagnostic rather than running uncapped.
- `aisdlc run --max-run-usd X`: stop popping new tasks once summed numeric `cost_usd` of tasks started in this run reaches X; in-flight tasks finish. An all-subscription run warns and ignores this cap. Mixed stored billing modes require the decision below; runtime config must not silently relabel previously queued tasks. Resolve `AISDLC_MAX_RUN_USD` through the existing precedence.
- `aisdlc status`: displays stop reasons and run summary.
- `aisdlc help` / init / update wiring for `max_open_prs` and `max_run_usd`: emit null defaults (disabled), preserve configured values, and never enable a cap merely by initializing or updating a repo.
- Integration into `cmd_run`, `pop_task` gating, config resolution, usage text, and `evals/harness/selftest.sh` using `stub-gh`.
- Minimal documentation update in `docs/ai-sdlc.md`.

Out:
- Automatic model routing.
- Per-user cost reporting.
- Limits enforced inside a running phase.

Change budget: 350 added lines, 6 files, 3 modules

## Context

- `plugins/sdlc/bin/aisdlc`: `cmd_run` worker loop, `pop_task` atomic-pop gate, `cmd_status` task summary, `resolve_default` config-key lookup, `cmd_inbox` PR listing (`prs.jsonl` for local tracker, `gh pr list` for GitHub tracker).
- `plugins/sdlc/commands/init.md`, `plugins/sdlc/commands/update.md`: config-key documentation for `max_open_prs` and `max_run_usd` wired per queue-runner playbook.
- `evals/harness/selftest.sh`, `evals/harness/stub-gh`: test cases and PR-count stub responses.
- `docs/ai-sdlc.md`: queue-runner flags section.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | maintainer | run with `--max-open-prs 2`; parameterize a trustworthy count of 2 and an unavailable/failed count | no task is claimed; count 2 exits 0 naming the limit, while unavailable count exits non-zero naming the lookup failure | selftest |
| UC-2 | maintainer | single-worker `aisdlc run --max-run-usd 1` with 3 queued stub tasks costing 0.6 each | exactly two tasks complete; run stops before popping the third; total accumulated cost ≥ 1.0 in task records | selftest |
| UC-3 | maintainer | run with no cap flags and either absent keys or init/update's null defaults | queue drains fully, exit 0, no cap message or PR-count lookup occurs | selftest |
| UC-4 | maintainer | `aisdlc status` after either cap stops a run (separate cases: `--max-open-prs 2`, `--max-run-usd 1`) | output names the stopping limit and configured value; spend-cap output also shows accumulated cost | selftest |
| UC-5 | maintainer | `aisdlc run --max-run-usd 5` with all queued tasks stored as `billing: subscription` | warns that run spend cannot be enforced and ignores the cap; null costs are not misreported as measured zero spend | selftest |
| UC-6 | maintainer | `AISDLC_MAX_OPEN_PRS=2` set in env (no CLI flag) with stub-gh reporting 2 open PRs | run stops with same cap message as UC-1; CLI flag absent, env value used | selftest |
| UC-7 | maintainer | `aisdlc run --workers 2 --max-open-prs 1` where open-PR count reaches limit while one task is in flight | the in-flight task completes normally; no additional tasks are popped after the cap is reached | selftest |
| UC-8 | maintainer | `aisdlc run --max-open-prs abc` (non-numeric value) | exits non-zero with an error message before any task is popped | selftest |

## Non-functional

- Backward compatible: without flags and with unconfigured defaults, current behavior is unchanged.
- Config key precedence: `CLI flag > .aisdlc/config.json > environment > built-in`, matching existing `resolve_default` contract for `max_open_prs` and `max_run_usd`.
- `CI= make validate` passes.

## Open questions

- [x] On mixed stored API/subscription billing, sum numeric API costs and stop all new claims when the run-wide cap is reached. Never coerce subscription null costs to measured zero. Only all-subscription runs ignore the cap with a warning. Conservative choice under the user's instruction to proceed.
