---
ticket: SDLC-001-c
title: The skillify loop — findings become instructions
status: draft
stacks: [instructions]
---

# SDLC-001-c — The skillify loop — findings become instructions

## Problem

Every QA finding, every `BLOCKED.md`, and every review comment is resolved once, inside one
branch, and teaches the next task nothing. `harness-eval` already states the rule — "the same
mistake in every task is a harness defect, not a model defect: fix the playbook or rule" — and
`task-router` already owns the three tiers those fixes belong in. No step in the pipeline ever
writes to them, so the instruction hierarchy is whatever `/sdlc:init` guessed on day one and the
agent workforce does not compound.

## Scope

In:
- `/sdlc:skillify <TICKET>` — read the evidence, classify each finding, propose a tier-correct
  diff, write it after approval, commit it with provenance.
- A "Harvesting an instruction from a finding" section in the `task-router` skill.
- A `## Skillify candidates` section in the QA report format and in the `auto-qa` agent.

Out:
- Any write to this plugin's own `plugins/sdlc/skills/` from a consumer repo.
- A queue phase: the queue's `settings.json` denies `Write(.claude/**)`.
- A new skill — the knowledge belongs in `task-router`, which already owns the tiers.
- A findings database or ledger: the evidence is the committed `qa-report.md` files.

## Context

- `plugins/sdlc/skills/task-router/SKILL.md` § "The three tiers", § "When to add what",
  § Budgets — root ≤ 90 lines, playbook ≤ 70, rule ≤ 70, router ≤ 12 rows, and "No instruction
  appears in two tiers".
- `plugins/sdlc/skills/harness-eval/SKILL.md` § "Diagnosing a failure" — symptom → the
  instruction file that caused it; § "Adding a scenario".
- `plugins/sdlc/commands/init.md:25-33` — the language for a command that needs an interactive
  session because `.claude/` writes are approval-gated, and how `--yes` skips only its own gate.
- `plugins/sdlc/bin/aisdlc:139-140` — `"Write(.claude/**)"`, `"Edit(.claude/**)"` in the deny
  list handed to every headless phase.
- `plugins/sdlc/agents/auto-qa.md:44-67` — the `qa-report.md` format this extends.
- `plugins/sdlc/commands/qa.md:100-111` — the hand-off block that must name the new step.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | developer | `/sdlc:skillify ABC-123` after a `GAPS` verdict | every finding in `qa-report.md` and `BLOCKED.md` is listed with a classification — `rule`, `playbook`, `invariant`, or `one-off` — and the evidence quoted as `<TICKET>` plus `file:line` | e2e |
| UC-2 | developer | the proposal step | the exact diff per destination file is printed and nothing is written until approval; `--yes` skips only this command's gate, never the runtime's `.claude/` approval | e2e |
| UC-3 | developer | approving a rule change | `.claude/rules/<stack>.md` stays ≤ 70 lines, still ends in its verification block, and the added lines carry a provenance comment naming the ticket and the finding | e2e |
| UC-4 | developer | approving a new playbook | the playbook is ≤ 70 lines and `CLAUDE.md` gains exactly one router row for it, staying ≤ 90 lines and ≤ 12 rows | e2e |
| UC-5 | developer | a finding whose text already exists in another tier | reported as duplicate with the file that already says it, and no second copy is written | e2e |
| UC-6 | developer | a finding that is a one-off code defect | reported as `one-off — not skillifiable` with the reason, and written nowhere | e2e |
| UC-7 | developer | a finding matching one in another ticket's committed `qa-report.md` | reported as a recurring harness defect with the `evals/harness/scenarios/` entry to add | e2e |
| UC-8 | qa phase | writing `qa-report.md` | the report carries a `## Skillify candidates` section listing the findings whose cause is a missing or weak instruction, or the word `none` | e2e |
| UC-9 | headless session | `/sdlc:skillify ABC-123` with no human present | states that `.claude/**` writes are denied to unattended runs, writes nothing, and exits; `ALL_PHASES` still has no `skillify` entry | integration |

## Non-functional

- `make validate` passes with `skillify` in `Makefile:10`; no new entry in `SKILLS`.
- `task-router/SKILL.md` stays under ~105 lines after the new section, and its eval set gains a
  positive trigger for harvesting and keeps at least one negative case.
- Every instruction this command writes must be followable by a weak model: an exact command or
  an example, never an intention (`harness-eval` § "Writing for the weakest model").

## Open questions

- [ ] none
