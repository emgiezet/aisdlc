---
ticket: SDLC-008
title: Discovery — brainstorm, discover, synthetic users, backlog, ux-shape, ux-setup
status: draft
stacks: [instructions]
---

# SDLC-008 — Discovery: the artefacts before a spec

## Problem

`/sdlc:spec` assumes someone already knows what to build. Before that there is an idea, a client
conversation, or an existing product with no written problem statement — and the harness offers
nothing, so the spec inherits whatever assumptions the ticket author held. The specs that fail in
review (`docs/ai-sdlc.md` § "Failure modes", row 1) fail because the problem was never written
down with evidence.

## Scope

In:
- `/sdlc:brainstorm "<idea>"`: one question at a time, alternatives including building nothing, a
  challenger subagent, a routing line, a brief file.
- `/sdlc:discover --mode existing|client|own "<product>"`: `product-brief.md` with every claim
  evidence-tagged, decisions with owners, a collection plan for empty sections.
- `/sdlc:synthetic-users <brief> --flow "<name>" [--stance validate|simulate|adversary]`.
- `/sdlc:backlog <brief|spec> [--dry-run]`: epics → stories → tasks filed through `/sdlc:issue`.
- `/sdlc:ux-shape "<flow>"`: a decided direction before `/sdlc:mockup`.
- `/sdlc:ux-setup`: the repo's design contract as a path-scoped rule.
- `skills/discovery/SKILL.md`: brief format, evidence tags, Definition of Ready.
- `/sdlc:init --discovery`: adds the Definition of Ready block to the profile.

Out:
- Anything queueable: every command here is interactive and asks questions.
- Browser-driven UX review — SDLC-009 (`/sdlc:ux-review`).
- Real user research tooling (surveys, analytics): the brief *records* evidence, it does not gather it.
- A new artefact directory outside the profile's `Briefs live in:` (SDLC-005 UC-1).

## Context

- `specs/SDLC-005/spec.md` — `Briefs live in: specs/briefs/`; operation `create-issue` via
  `/sdlc:issue` (SDLC-007 UC-1) for `backlog`.
- `plugins/sdlc/commands/spec.md` Phase 1 "Gather the source" — reads `specs/briefs/*.md` when
  present, so a brief flows into the spec's Problem and Out sections.
- `plugins/sdlc/commands/mockup.md` Phase 1 — consumes `ux-shape`'s states list.
- `plugins/sdlc/skills/task-router/SKILL.md` § "The three tiers" — `ux-setup` writes a tier-3
  rule at `.claude/rules/design-system.md` (≤ 70 lines, path-scoped to the UI directories).
- `plugins/sdlc/templates/sdlc.md` — new optional block `## Definition of Ready` written by
  `--discovery`.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | product owner | `/sdlc:brainstorm "should we add bulk archive?"` | questions arrive one per message; at least one alternative is "do nothing"; a challenger subagent's objection is quoted; the run ends with `Next: /sdlc:spec <T> | /sdlc:issue | /sdlc:discover | none` and `specs/briefs/<slug>.md` (≤ 80 lines) | e2e |
| UC-2 | product owner | `/sdlc:discover --mode client "benefits portal"` with a research folder | `specs/briefs/product-brief.md` has sections Problem / Who / Stakeholders / Rules / Flows / Benchmark / Success criteria / Scope (now, later, not) / Non-goals / Decisions (owner each) / Riskiest assumptions (test each) / Open questions; every factual sentence ends with `[EVIDENCE: <file or interview>]`, `[ASSUMPTION]` or `[SYNTHETIC]` | e2e |
| UC-3 | product owner | `/sdlc:discover` where a section has no material | the section contains a `Collection plan:` list (what to gather, from whom, capture template) and no prose; the report names those sections under `Not yet evidence-backed` | e2e |
| UC-4 | product owner | `/sdlc:synthetic-users specs/briefs/product-brief.md --flow "first claim"` | two independent panel runs; only findings present in both are listed; each finding is tagged `[SYNTHETIC]` and paired with `Real-user check:`; in `--stance adversary` any agreement is discarded; no numeric claims | e2e |
| UC-5 | product owner | `/sdlc:backlog specs/briefs/product-brief.md --dry-run` | the epic → story → task tree is printed with acceptance criteria per story and nothing is filed; without `--dry-run` each node is filed through `/sdlc:issue` with `Epic: #<n>` lines and the epic body carries a checklist; existing matching issues are adopted, not duplicated | e2e |
| UC-6 | product owner | `/sdlc:backlog` on a brief whose Problem is `[ASSUMPTION]`-tagged | refuses with `brief rests on assumptions: <sections>` and offers `--research` which files only the collection-plan items | e2e |
| UC-7 | designer | `/sdlc:ux-shape "quick-add for the people list"` | `specs/briefs/ux-<slug>.md` with Direction / Scope / States (empty, loading, error, denied, success) / Riskiest assumption + test; `/sdlc:mockup` reads it when the ticket names the same slug | e2e |
| UC-8 | designer | `/sdlc:ux-setup` on a repo with a design system | `.claude/rules/design-system.md` ≤ 70 lines, path-scoped, listing tokens, components, spacing, copy rules with `file:line` sources; `CLAUDE.md` router unchanged; a repo with none gets the rule stubbed with `none` and a one-line report | e2e |

## Non-functional

- Nothing here counts as evidence unless a human produced it: `[SYNTHETIC]` never upgrades to
  `[EVIDENCE]`, and `backlog` treats `[ASSUMPTION]` as not ready.
- One question per message in `brainstorm`, `discover` — a weak model asked five things answers
  the last one (`harness-eval` § "Writing for the weakest model").
- Briefs ≤ 80 lines, `product-brief.md` ≤ 200 lines: past that, `spec` cannot load it beside the
  router and a playbook.
- `make validate`, `make eval-dry` stay green.

## Open questions

- [ ] none
