---
ticket: GH-42-c
title: Reducer accumulator copies and module mocking as AP-TS-PERF-005 / AP-TS-MAINT-009
status: approved
stacks: [slop-guard catalogue, bash]
depends-on: GH-42-a
---

# GH-42-c — Detect quadratic reducers and module-mocked tests

Source: https://github.com/emgiezet/aisdlc/issues/42 · plan: `specs/GH-42/decomposition.md`

## Problem

Two anti-slop patterns sit outside type safety. Reducers that copy their accumulator on every step
(`Object.assign({}, acc, …)`, `acc.concat(…)`) turn a linear fold quadratic. Tests that replace
whole modules with `vi.mock` / `jest.mock` assert against the mock instead of a dependency seam, so
they pass while the real wiring is broken. D36 (`GH-42-a`) assigns them `AP-TS-PERF-005` and
`AP-TS-MAINT-009`.

## Scope

In:
- `plugins/slop-guard/rules/catalog.yaml`: `AP-TS-PERF-005` "Reducer copies its accumulator on every step" (category
  `performance`, severity `warn`) and `AP-TS-MAINT-009` "Module mocking instead of a dependency
  seam" (category `maintainability`, severity `warn`); `cwe: []`, original text, own `bad`/`good`.
  `AP-TS-PERF-005`'s summary names the spread form (`{...acc}`) as prevention-only: ESLint has no
  port of Oxlint's `no-accumulating-spread`.
- `plugins/slop-guard/rules/mapping/eslint.yaml`: `anti-slop/no-reduce-accumulator-copy` → `AP-TS-PERF-005`;
  `anti-slop/no-module-mocking` → `AP-TS-MAINT-009`.
- `plugins/slop-guard/configs/baseline/eslint.config.mjs`: `no-reduce-accumulator-copy` at `warn` in the TypeScript
  block; `no-module-mocking` at `warn` in a block matching test files
  (`**/*.{test,spec}.{js,ts,jsx,tsx}`, `**/__tests__/**`), so the relaxed block does not hide it.
- `plugins/slop-guard/skills/ts-react-antipatterns/`: regenerated.
- `plugins/slop-guard/tests/fixtures/ts/` bad and good fixtures: `AP-TS-PERF-005.ts` and
  `AP-TS-MAINT-009.test.ts` in each of `bad/` and `good/`.
- `plugins/slop-guard/tests/integration/fast.sh`: fixture cases for `AP-TS-PERF-005` and `AP-TS-MAINT-009`.
- `plugins/slop-guard/CHANGELOG.md` `## Unreleased` entry.

Out:
- D36, the package pin, the plugin registration — `GH-42-a`. `AP-TS-MAINT-007/008` — `GH-42-b`.
- Detecting spread accumulation, `vi.fn()` / `jest.fn()` spies, or `vi.spyOn`.
- A JavaScript-only (`.js`) mocking rule beyond what the baseline TS/JS file globs already cover.
- `plugins/sdlc/skills/dense-testing/` — its mocking guidance is not changed here.

Change budget: 300 added lines, 14 files, 1 modules

## Context

- `GH-42-a` — `specs/GH-42-a/spec.md`.
- `plugins/slop-guard/rules/catalog.yaml` — `AP-TS-PERF-001` … `AP-TS-PERF-004` (performance shape).
- `plugins/slop-guard/configs/baseline/eslint.config.mjs` — `// --- tests and scripts: relaxed ---`.
- `plugins/slop-guard/tests/integration/fast.sh` — eslint cases from `GH-42-a`.
- Upstream invalid cases at `c44ef22`: `items.reduce((acc, item) => Object.assign({}, acc, item), {})`,
  `items.reduce((acc, item) => acc.concat([item]), [])`, `acc.slice()` then `push`.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-15 | agent | writes `items.reduce((acc, i) => Object.assign({}, acc, { [i.id]: i }), {})` | fast tier reports `AP-TS-PERF-005` from `anti-slop/no-reduce-accumulator-copy` | integration |
| UC-16 | agent | writes `items.reduce((acc, i) => acc.concat([i]), [])` | `AP-TS-PERF-005` | integration |
| UC-17 | agent | the good fixture: a reducer that mutates and returns its own accumulator *(inferred negative)* | no `AP-TS-PERF-005` finding | integration |
| UC-18 | agent | writes `vi.mock('./db')` in `orders.test.ts` | fast tier reports `AP-TS-MAINT-009` from `anti-slop/no-module-mocking` | integration |
| UC-19 | agent | writes `jest.mock('./db')` in `orders.test.ts` | `AP-TS-MAINT-009` | integration |
| UC-20 | agent | the good fixture: the dependency passed in as a parameter and a `vi.fn()` stub *(inferred negative)* | no `AP-TS-MAINT-009` finding | integration |
| UC-21 | maintainer | `scripts/gen-skills --check` | exit 0; `reference/AP-TS-PERF-005.md` and `AP-TS-MAINT-009.md` exist with the catalogue's `bad` and `good` blocks | unit |

## Non-functional

- Generated `SKILL.md` within 150 lines / 3000 tokens.
- `CI= make validate` and `make tool-integration` pass.

## Open questions

none
