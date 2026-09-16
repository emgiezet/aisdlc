---
ticket: SDLC-001-a
title: Program design as a committed artefact and a queue phase
status: draft
stacks: [runner, instructions]
---

# SDLC-001-a — Program design as a committed artefact and a queue phase

## Problem

`/sdlc:implement` receives a spec that states observable results and nothing about code shape,
so it designs while it builds. Under pressure to reach green it reaches for the hacks a reviewer
then has to find: a swallowed exception, a widened type, a helper in the wrong module. There is
no artefact between "approved" and "committed code" that a reviewer or a later phase can hold
the implementation against.

## Scope

In:
- A `program-design` skill holding the `design.md` and `arch.md` formats and their sizing limits.
- `/sdlc:design <TICKET>` producing `specs/<TICKET>/design.md` from an approved spec.
- A `design` queue phase, first in the default phase list, whose output is committed.
- `/sdlc:implement` and `/sdlc:qa` bound to that artefact: declared file scope, recorded growth.
- Eval scoring for the declared scope, offline-testable.

Out:
- `/sdlc:arch` and `/sdlc:skillify` (slices b and c).
- Per-phase model or budget overrides in the task record.
- A human approval gate on `design.md` — the spec remains the only gate.
- Changing existing scenarios' assertions, the guard hook, or the spec format.

## Context

- `plugins/sdlc/bin/aisdlc:28` — `ALL_PHASES="implement qa ship"`, the default phase list.
- `plugins/sdlc/bin/aisdlc:431-444` — the phase loop; `plugins/sdlc/bin/aisdlc:606` — `cmd_logs`
  enumerates `run.log implement.log qa.log ship.log`; `:544` renders phase initials in `%-6s`.
- `plugins/sdlc/bin/aisdlc:445-460` — where `qa-report.md` and `pr-body.md` are copied out of the
  worktree before it is released.
- `plugins/sdlc/commands/implement.md:29-58` — Phase 0 spec gate and Phase 1 routing.
- `plugins/sdlc/commands/qa.md:39-79` — gap closing and verdict rules;
  `plugins/sdlc/agents/auto-qa.md:30-67` — gap taxonomy and report format.
- `Makefile:10-11` — `COMMANDS` and `SKILLS`, the lists `make validate` enforces.
- `evals/harness/run.sh:76-200` — `score()`; `evals/harness/selftest.sh:57-69` — phase-order test;
  `evals/harness/stub-claude` — the offline fake `claude`.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | developer | `/sdlc:design ABC-123` on an approved spec | `specs/ABC-123/design.md` exists with frontmatter `ticket`, `spec`, a non-empty `files:` list, and the sections Approach, Components, Signatures, Call graph, Contract changes, Build order, Risks | e2e |
| UC-2 | developer | `/sdlc:design ABC-123` where the spec is missing or `status: draft` | one-line refusal naming the reason, no file written under `specs/ABC-123/` | e2e |
| UC-3 | queue | `aisdlc add ABC-123` with no `--phases` | `task.json` `.phases == ["design","implement","qa","ship"]` | integration |
| UC-4 | queue | `aisdlc run --once` over that task | `design.log` exists in the task dir, ordered before `implement.log`; `design.md` is copied out of the worktree; `aisdlc logs <id>` prints the design log | integration |
| UC-5 | design phase | finishing inside the worktree | `design.md` is committed on the branch (`git ls-tree -r HEAD` lists it) and the tree is clean | integration |
| UC-6 | implement phase | needing a file the design did not declare | the same commit amends `files:` with a one-line reason; no file outside the amended list is touched | e2e |
| UC-7 | qa phase | a branch whose diff leaves the declared scope with no amendment | `qa-report.md` carries a `## Design conformance` section and the verdict is `GAPS` with that finding marked blocking | e2e |
| UC-8 | queue | a task queued `--phases implement,qa` (no design) | both phases run unchanged and neither refuses for a missing `design.md` | integration |

## Non-functional

- `make validate`, `make selftest` and `make eval-dry` stay green; `program-design` is registered
  in `Makefile:11` and carries `agents/eval-set.json` with at least one negative trigger case.
- `design.md` is capped at 120 lines; a design that cannot fit means the spec must be split.
- The design phase writes one document and no code, so its turn count stays close to the QA
  phase's floor rather than to `implement`'s.
- `$/PR` is re-measured with `make harness-eval MODEL=haiku` before any document claims a saving.

## Open questions

- [ ] none
