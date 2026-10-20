---
ticket: GH-59
title: "Change budget: repo-wide Tolerance percentage before scope-check reports an overshoot"
status: approved
stacks: [bash, instructions]
---

## Problem

Every soft change-budget overshoot, even by one line, produces a `[major] over change budget`
scope-check finding. `/sdlc:review` imports it, the PR becomes `CHANGES_REQUESTED`, and a
maintainer must waive it manually per PR. A repo that permits bounded overshoot as policy
(e.g. "accept up to 100% above budget") has no mechanism to declare that once and stop
blocking clean-enough PRs.

## Scope

In:
- New `- **Tolerance:** <n>%` bullet under `## Change budget` in `plugins/sdlc/templates/sdlc.md`; absent means 0
- `_budget_profile` already reads any labelled bullet from `## Change budget`; no changes to the function — call it with label `'Tolerance'` to extract `n`
- `_size_eval` gains a `tolerance` argument appended after `ceiling`; computes per-metric effective limit as `budget + budget * tolerance / 100` [ASSUMPTION: integer truncation — issue gives the formula but not the rounding mode; shell `$((...))` truncates]; compares actual value against effective limit; finding names the effective limit when tolerance > 0
- `_write_size_section` gains a `tolerance` argument; Budget column shows `400 +100%` when tolerance is non-zero, bare `400` when zero
- `run_scope_check` reads `Tolerance` from profile via `_budget_profile`, defaults to 0, and passes it to `_size_eval` and `_write_size_section`
- Shotgun-surgery check inside `_size_eval` uses the same toleranced module limit
- Hard ceiling is **never** moved by tolerance
- `commands/implement.md` budget-watch paragraph mentions the toleranced effective limit
- `size_budget_test.sh` adds tests covering all UC table rows

Out:
- Per-spec tolerance override (issue is explicit: repo-wide only; a spec cannot widen its own approval margin)
- Hard ceiling change of any kind
- Changes to erosion/hotspot (structure check) logic
- Changes to `.claude/sdlc.md` in this repo (template update only; this repo's profile carries no Tolerance yet)
- Changes to `aisdlc add` CLI flags or any command other than `implement.md`

Change budget: 130 added lines, 4 files, 1 module

## Context

- `plugins/sdlc/bin/aisdlc`
  - `_budget_profile`: reads a numeric value from a `**Label:**` bullet inside `## Change budget`; already sufficient for `'Tolerance'` — no changes needed
  - `budget_value`: resolves spec > profile > built-in for line/file/module counts; tolerance has no spec form, so it remains profile-only and is not routed through this function
  - `_size_eval`: current signature `added n_files n_mods modlist b_added b_files b_mods ceiling`; append `tolerance` and update every caller explicitly, using 0 when the profile value is absent.
  - `_write_size_section`: current signature mirrors `_size_eval` except leading `out` and no `tolerance`; new `tolerance` arg appended; renders Budget column
  - `run_scope_check`: resolves budgets, then calls `_size_eval` and `_write_size_section`; add one `_budget_profile` call for `'Tolerance'`
- `plugins/sdlc/tests/size_budget_test.sh` — unit tests sourcing `bin/aisdlc`; extend with tolerance cases matching UC table
- `plugins/sdlc/templates/sdlc.md` — `## Change budget` section; add `- **Tolerance:** <n>%` bullet with inline comment explaining default-0 and repo-wide scope
- `plugins/sdlc/commands/implement.md` — budget-watch paragraph; note that the effective limit is `budget × (1 + Tolerance/100)` when the profile carries a Tolerance value

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-2 | scope-check | 401 added lines, budget 400, with tolerance explicitly 0 or absent (separate cases) | finding `over budget: 401 added lines > 400` with no tolerance suffix; verdict GAPS | unit |
| UC-3 | scope-check | each metric independently one past its toleranced limit, tested separately — (a) added=801, budget 400, Tolerance 100 → limit 800; (b) files=16, budget 10, Tolerance 50 → limit 15; (c) modules=5, budget 3, Tolerance 50 → limit 4 | finding for each case includes the effective limit: `801 added lines > 800 (400 + 100% tolerance)`, `16 files touched > 15 (10 + 50% tolerance)`, `5 modules touched > 4 (3 + 50% tolerance)`; verdict GAPS | unit |
| UC-4 | scope-check | each metric at or below its toleranced limit, tested separately — added=655 or 800 (budget 400, Tolerance 100); files=15 (budget 10, Tolerance 50); modules=4 (budget 3, Tolerance 50) | no `over budget` finding for that metric (clean below and at the exact limit) | unit |
| UC-5 | scope-check | 3001 added lines, `Tolerance: 100`, budget 400 | hard ceiling 3000 triggers BLOCKED; tolerance does not raise or suppress ceiling | unit |
| UC-6 | scope-check | modules 4, `b_mods` 3, `Tolerance: 50` (effective limit 4), per-file edit count < 10 | no `over budget` module finding; no shotgun-surgery finding (modules within toleranced limit) | unit |
| UC-8 | scope-check | `Tolerance: 100`, budget 400, 655 added lines | Budget column in scope report shows `400 +100%`; with tolerance 0 (UC-2 scenario) the column shows bare `400` | unit |
| UC-9 | `_budget_profile` | profile `## Change budget` section contains `- **Tolerance:** 75%` | function returns `75`; when no `Tolerance:` line is present function returns empty string | unit |
| UC-10 | scope-check | profile `Tolerance: 50`; spec budget 120 added lines and an attempted spec-only `Tolerance: 1000`; branch adds 181 lines | profile authority wins: effective limit remains 180, and the branch receives an over-budget finding; the spec cannot widen its own tolerance | unit |

## Non-functional

- Effective-limit arithmetic: `budget + budget * tolerance / 100` using shell integer arithmetic (truncation). [ASSUMPTION: the issue specifies the formula but not the rounding mode; integer truncation is consistent with every other `$((...))` expression in `_size_eval`.]
- Update all `_size_eval` and `_write_size_section` callers, including existing tests, to pass tolerance explicitly; absent profile configuration still resolves to 0.
- Tolerance 0 preserves existing verdicts and report shape; retain the finding prefixes consumed by review's scope-report import.

## Open questions

_(none)_
