---
ticket: SDLC-002
title: Four-phase planning — when architecture is required, ADRs, vertical slices, rule traceability
status: draft
stacks: [instructions]
---

# SDLC-002 — Four-phase planning — when architecture is required, ADRs, vertical slices, rule traceability

## Problem

`SDLC-001-a/b/c` add the artefacts (`arch.md`, `design.md`, skillified rules) but not the rules
that decide *when* each level applies, and not the mechanism that turns a design into an ordered
build. Without an explicit threshold every ticket either gets an architecture document it does
not need or skips the one it does; without an ordered slice loop, `/sdlc:implement` still decides
its own order mid-build, which is where the architectural workarounds appear; without a decision
record an epic's hard-to-reverse calls live only in a markdown table nobody greps; and without
back-references a harvested rule cannot be traced to the finding that paid for it.

## Scope

In:
- The threshold that makes `/sdlc:arch` required rather than optional, stated as a number.
- ADR emission from `/sdlc:arch` into the location `.claude/sdlc.md` names.
- `design.md`'s build order as ordered vertical slices, and `/sdlc:implement` executing them
  one at a time with verification between slices.
- Two-way traceability between a skillified rule and the finding it came from.

Out:
- The artefacts, commands, queue phase and eval scoring themselves — `SDLC-001-a/b/c`.
- Authoring an ADR format of our own: the project's existing one wins; when the profile says
  `none`, no ADR file is written.
- Any new queue phase, per-phase budget, or change to the spec gate.

## Context

- `specs/SDLC-001/arch.md` — the epic this refines; its slice table and decisions.
- `plugins/sdlc/skills/spec-authoring/SKILL.md` § Sizing — "Split when the spec exceeds ~8 use
  cases, spans more than two stacks, or contains a row that cannot be tested until another row
  ships."
- `plugins/sdlc/commands/spec.md:84-86` — the existing split instruction and its `-a`/`-b` ids;
  `:102-127` — the readiness report that must name the architecture step.
- `plugins/sdlc/commands/implement.md:62-82` — Phase 2, "Build, one UC at a time", the loop that
  becomes slice-driven when a design exists.
- `plugins/sdlc/templates/sdlc.md` § "Contracts and decisions" — `Architecture decision records:`
  is `none` by default, and `none` is a real answer.
- `plugins/sdlc/agents/auto-qa.md:44-67` — the report format that carries the finding ids a rule
  must cite back.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | developer | `/sdlc:spec` producing more than 3 use cases, or more than one stack | the readiness report's `Next` block names `/sdlc:arch <EPIC>` as step 1 and says why, before the approval step | e2e |
| UC-2 | developer | `/sdlc:arch` on work that fits one pull request (≤ 3 use cases, one stack) | one-line refusal — "one spec is one task is one pull request; run /sdlc:spec" — and no `arch.md` written | e2e |
| UC-3 | developer | `/sdlc:arch EPIC-7` where `.claude/sdlc.md` names an ADR location | one file per hard-to-reverse decision at that location, each with `status: proposed` and a link back to `specs/EPIC-7/arch.md`; the arch's Decisions table cites each file | e2e |
| UC-4 | developer | `/sdlc:arch EPIC-7` where the ADR location is `none` | no ADR file anywhere; the Decisions table carries the same content and the report states that this repo records no ADRs | e2e |
| UC-5 | developer | reading `design.md`'s build order | an ordered slice table where every row names its UC ids and the observable proof, row 1 is the end-to-end skeleton, and every UC in the spec appears in exactly one row | e2e |
| UC-6 | implement phase | building with a `design.md` present | commits appear in slice order, one per slice at minimum, each message naming the slice's UC ids | e2e |
| UC-7 | implement phase | a slice whose verification is red after one targeted fix | `BLOCKED.md` names the slice and the later slices are not started — no commit exists for a slice after the failed one | e2e |
| UC-8 | developer | `/sdlc:skillify ABC-123` writing a rule | the rule's added lines cite `ABC-123` and the finding number, and `qa-report.md` is amended in the same commit with the rule file per skillified finding | e2e |
| UC-9 | developer | `grep -rl ABC-123 .claude/` | finds the rule harvested from that ticket — the trace from a finding to the instruction that prevents its recurrence is greppable in both directions | e2e |

## Non-functional

- Thresholds are numbers in the instruction text, never adjectives: "more than 3 use cases",
  "more than one stack". A weak model cannot follow "large".
- No new queue phase, no change to `ALL_PHASES` beyond the `design` entry added by `SDLC-001-a`.
- `make validate` stays green; no instruction added here may restate one that already exists in
  another tier.

## Open questions

- [ ] none
