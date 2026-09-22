---
ticket: SDLC-010
title: Pipeline retro — rank what the harness cost, by cause
status: draft
stacks: [instructions]
---

# SDLC-010 — Pipeline retro

## Problem

`aisdlc status` and `result.json` carry cost, turns and verdicts per task, and `docs/ai-sdlc.md`
§ "Metrics worth tracking" says which ratios matter — but nobody computes them, and the mapping
from "this run needed two review loops" to "this playbook row is ambiguous" lives in one person's
head. The harness's own failure modes are the highest-leverage defects and the least measured.

## Scope

In:
- `/sdlc:retro [--since <date>] [--repo <path>]`: read-only classification of finished runs, ranked
  causes, a mapping to the harness file per `harness-eval`'s diagnosis table, hand-off of the top
  cause to `/sdlc:issue`.

Out:
- Fixing anything: the retro files one issue and stops.
- `create-skill` and `apply-upgrade-notes` from the reference collection: plugin updates arrive
  through the marketplace and skill-writing guidance is `harness-eval`.
- New telemetry: only what `task.json`, `result.json`, `*.log`, `qa-report.md` and the tracker
  already record.

## Context

- `plugins/sdlc/bin/aisdlc` `task.json` fields `status attempts cost_usd created updated pr_url
  error phases`; `<phase>.json` `num_turns total_cost_usd is_error`.
- `plugins/sdlc/skills/harness-eval/SKILL.md` § "Diagnosing a failure" — the symptom → file table
  the retro maps causes onto.
- `docs/ai-sdlc.md` § "Metrics worth tracking" and § "Failure modes".
- `specs/SDLC-005/spec.md` — operations `list-prs get-pr` for review-loop counts and merge state;
  SDLC-007 `/sdlc:issue` for the hand-off.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | maintainer | `/sdlc:retro --since 2026-09-01` | every task under `.aisdlc/tasks/` updated since the date is classified as exactly one of `clean | blocked | gaps | review-loop | retried | failed`, from `status`, `error`, `qa-report.md` verdict, `attempts`, and the PR's review count | e2e |
| UC-2 | maintainer | same run | a table ranks causes by summed `cost_usd` and wall-clock (`updated - created`), with count, share of total, and the harness file `harness-eval` names for that symptom (`spec-authoring` / playbook / rule / router / `auto-qa`) | e2e |
| UC-3 | maintainer | same run | metrics from `docs/ai-sdlc.md` printed as numbers: `$ per merged PR`, first-pass `PASS` rate, `BLOCKED` rate with top three `BLOCKED.md` reasons, generated-vs-merged ratio | e2e |
| UC-4 | maintainer | run where the tracker is `local` or unreachable | review-loop and merge columns show `n/a`; the rest of the report is unchanged; one line explains | e2e |
| UC-5 | maintainer | end of run | asks once whether to file the top cause; on yes, `/sdlc:issue` is invoked with the cause, its evidence (task ids, cost, symptom) and the named harness file; report ends `Issue: #<n> (<url>)`; on no, nothing is written | e2e |
| UC-6 | maintainer | `/sdlc:retro` with no finished tasks | `no finished runs since <date>` and exit; no tables | e2e |

## Non-functional

- Read-only except for the one optional issue; never edits `task.json` or any harness file.
- Numbers come from `jq` over the JSON files, never from reading logs into the model's context —
  logs are consulted only for the top three `BLOCKED.md` reasons.
- Report ≤ 60 lines.
- `make validate`, `make eval-dry` stay green.

## Open questions

- [ ] none
