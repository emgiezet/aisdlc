---
ticket: SDLC-004
title: Architecture rules as executable tests, per stack
status: draft
stacks: [instructions, runner]
---

# SDLC-004 — Architecture rules as executable tests, per stack

## Problem

`arch.md` and `design.md` declare component boundaries in a table, and nothing checks that the
code respects them. The `files:` scope check catches a file the design never declared; it says
nothing about a controller that now imports a repository directly, a domain package that reaches
into HTTP, or business logic that moved into a Blade view. Those are exactly the violations a
model produces when it optimises for a green suite, and they are invisible to linters, which check
syntax within a file rather than the direction of dependencies between packages. Every stack
already has a tool for this — ArchUnit, Deptrac, import-linter, dependency-cruiser, depguard — and
the harness never asks for one, so the boundary a human approved in `arch.md` decays from the
first branch onward.

## Scope

In:
- An `## Architecture rules` section in `design.md`: one row per boundary rule, each naming the
  test that proves it.
- A profile field naming this repo's architecture-test tool, its rule file, and its command, plus
  detection of an existing one in `/sdlc:init`.
- A density floor: every declared boundary rule has one architecture test, in the project's
  existing arch-test tool, run by the verification matrix.
- `/sdlc:implement` writing those tests before the code they constrain; `/sdlc:qa` reporting a
  declared rule with no test as a gap.
- The per-stack tool table, so a weak model does not have to choose.

Out:
- Bundling or vendoring any architecture-test tool; the project installs it, as with every other
  tool in the verification matrix.
- Inventing an arch-test framework where the stack has none — the profile says `none` and the
  step is skipped, per the profile's own convention.
- Retrofitting rules onto existing code: `Z2`-style, only boundaries this change declares are
  enforced; pre-existing violations are recorded once, not fixed.
- Per-framework syntactic rules inside a single file — that is `slop-guard`'s subject
  (`docs/slop-guard-spec.md` §6.1, §8), and this spec must not duplicate it.

## Context

- `specs/SDLC-001/arch.md` § "Component boundaries" — the table whose rows become rules.
- `docs/plans/2026-09-16-planning-and-skillify.md` Task 1 — `design.md`'s section list, which this
  extends by one section.
- `plugins/sdlc/skills/dense-testing/SKILL.md` § "Density floors" — the table this adds a row to;
  § "Assert on observable behaviour", which an arch test satisfies: a dependency direction is
  observable.
- `plugins/sdlc/templates/sdlc.md` § "Stacks and verification" and § "Test conventions" — where the
  tool, its rule file and its command belong.
- `plugins/sdlc/commands/init.md` Phase 1 "Verification commands" and "Test conventions" — where
  detection goes.
- `plugins/sdlc/commands/implement.md` Phase 2 (the slice loop) and Phase 3 (the self-check).
- `plugins/sdlc/agents/auto-qa.md` § "What counts as a gap" and the report format.
- `evals/fixtures/sandbox/services/ledger/` — Go fixture with `internal/httpapi` and
  `internal/ledger`, the boundary an eval scenario can assert on.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------------|----------------------------|------|
| UC-1 | developer | `/sdlc:design ABC-123` where the profile names an arch-test tool | `design.md` carries an `## Architecture rules` table; every row states the rule as a dependency direction, the tool, and the test name that will prove it | e2e |
| UC-2 | developer | `/sdlc:design ABC-123` where the profile says `none` | the section is omitted entirely and the report says the repo records no architecture tests — no tool is proposed, no file is created | e2e |
| UC-3 | implement phase | building a slice whose design declares a boundary rule | the architecture test exists in the project's arch-test rule file or test suite, carries the rule's id, and was committed before the code it constrains | e2e |
| UC-4 | implement phase | code that violates a declared rule | the arch test fails in the verification matrix and the run stops per the one-fix-then-stop rule — never by relaxing the rule file | e2e |
| UC-5 | qa phase | a declared rule with no architecture test | `qa-report.md` lists it as a blocking finding and the verdict is `GAPS` | e2e |
| UC-6 | qa phase | an arch rule file weakened in the diff (a rule deleted, a layer allowed) | reported as a blocking finding quoting both sides, exactly as a weakened test is | e2e |
| UC-7 | developer | `/sdlc:init` on a repo already using an arch-test tool | the detected tool, its rule file and its command land in `.claude/sdlc.md`, and the command joins the verification matrix | e2e |
| UC-8 | developer | `/sdlc:init` on a repo with none | the profile field is `none` and the proposal names the one tool that fits the stack as a recommendation, without writing a rule file | e2e |
| UC-9 | maintainer | reading `dense-testing` | the density table has one row — declared boundary rule → 1 architecture test — and the non-negotiables cover relaxing an arch rule to get green | unit |

## Non-functional

- The per-stack tool table states exactly one default per stack, because two acceptable options
  means a weak model flips a coin (`harness-eval` § "Writing for the weakest model"): Java/Kotlin
  → ArchUnit; PHP → Deptrac; Python → import-linter; TypeScript/JavaScript → dependency-cruiser;
  Go → `depguard` inside golangci-lint; C# → NetArchTest. Anything else → `none`.
- An architecture test runs in the existing verification matrix, never as a separate ceremony: if
  `make verify` does not run it, it does not exist.
- `make validate`, `make selftest` and `make eval-dry` stay green; no new plugin skill.

## Open questions

- [ ] none
