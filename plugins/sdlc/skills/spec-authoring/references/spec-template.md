---
ticket: TICKET-000
title: <one line, in the product's own vocabulary>
status: draft
stacks: [backend]
---

# TICKET-000 — <title>

## Problem

<2–4 sentences: what is broken or missing, for whom. No solution, no implementation.>

## Scope

In:
- <the change, stated as an outcome>

Out:
- <adjacent modules, refactors, and "while we're here" work that must not be touched>

Change budget: <n> added lines, <n> files, <n> modules
<!-- what this slice may add before scope-check calls it unreviewable; omit to take the
     repo's defaults from .claude/sdlc.md -->

## Context

- `path/to/file.ext` — <what lives here and why it matters to this change>
- Contract: `<operationId>` in <the contract directory named in .claude/sdlc.md>
- Decision: <the ADR that constrains this, if the project keeps any>
- Delete the lines that do not apply. An invented path is worse than a missing one.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | <who> | <what they do> | <what a test can read: status, row, text, event> | integration |
| UC-2 | <who> | <invalid variant> | <rejection, error shape, no side effect> | integration |
| UC-3 | <who> | <permission boundary> | <denial, nothing written> | integration |

## Non-functional

<Only constraints that change the implementation — latency budget, transaction boundary,
idempotency, tenancy isolation, audit trail. Delete this section if there are none.>

## Open questions

- [ ] <unresolved decision — must be empty before status: approved>
