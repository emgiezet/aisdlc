---
ticket: SDLC-001-b
title: Architecture level ahead of the spec
status: draft
stacks: [instructions]
---

# SDLC-001-b — Architecture level ahead of the spec

## Problem

A spec is sized for one unattended run and one pull request, and `spec-authoring` says
decomposition belongs elsewhere — but the harness has no "elsewhere". Anything larger than one
pull request therefore arrives as either an oversized spec that gets split by instinct mid-run,
or as a pile of sibling specs with no recorded component boundaries, so each slice re-invents the
interfaces the others assumed.

## Scope

In:
- `/sdlc:arch <EPIC>` producing `specs/<EPIC>/arch.md`: system context, component boundaries,
  decisions, an ordered slice table, epic-wide out-of-scope.
- `/sdlc:spec` reading an epic's `arch.md` when one exists and grounding the slice in it.
- A router row and session announcement for the new command.

Out:
- Writing the slice specs themselves — `/sdlc:arch` hands off, it does not author specs.
- Any queue involvement: `arch` is never added to `ALL_PHASES`.
- ADR authoring; `arch.md` names the ADR candidates and the profile says where they live.
- Changing the spec format or the UC table rules.

## Context

- `plugins/sdlc/skills/spec-authoring/SKILL.md:12-14` — "Human-facing planning belongs
  elsewhere: decomposition of a vague ticket, design discussion, the narrative of why".
- `plugins/sdlc/skills/spec-authoring/SKILL.md` § Sizing — split at ~8 UCs or two stacks into
  `<TICKET>-a`, `<TICKET>-b`, walking skeleton first.
- `plugins/sdlc/commands/spec.md:50-62` — Phase 2 grounding, where an epic's arch belongs;
  `:102-127` — the readiness report and hand-off block.
- `docs/overlay-contract.md:82-83` — "The artefact chain ahead of the spec: an intent capture
  step and a written implementation plan, both committed, both human-approved."
- `plugins/sdlc/templates/CLAUDE.md` — the router table this adds a row to (47 lines, budget 90).
- `Makefile:10` — `COMMANDS`, the list `make validate` enforces.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | developer | `/sdlc:arch EPIC-7` with a described epic | `specs/EPIC-7/arch.md` exists with frontmatter `epic`, `status: draft`, a `slices:` list, and the sections System context, Component boundaries, Decisions, Slices, Risks, Out of scope | e2e |
| UC-2 | developer | reading the slice table | every row names a ticket id, what it delivers, what it depends on, and its observable proof; the first row is the walking skeleton that proves the path end to end | e2e |
| UC-3 | developer | `/sdlc:arch EPIC-7` finishing | no file is created under any `specs/EPIC-7-*/`; the hand-off block prints the exact `/sdlc:spec <slice>` command per slice, in dependency order | e2e |
| UC-4 | developer | `/sdlc:spec EPIC-7-a` where `specs/EPIC-7/arch.md` exists | the spec's `Context` cites the arch's component rows and its `Out:` carries the epic-wide out-of-scope entries | e2e |
| UC-5 | developer | `/sdlc:spec ABC-123` with no epic arch | unchanged behaviour: no mention of a missing arch beyond at most one line of advice | e2e |
| UC-6 | maintainer | `aisdlc add EPIC-7` | refused by the existing spec gate (`no spec at specs/EPIC-7/spec.md`) — an arch is not queueable work | integration |

## Non-functional

- `make validate` passes with `arch` in `Makefile:10` and `commands/arch.md` present.
- `templates/CLAUDE.md` stays within its 90-line budget and its router table within 12 rows.
- `arch.md` is capped at 120 lines; more means the epic needs splitting, not a longer document.

## Open questions

- [ ] none
