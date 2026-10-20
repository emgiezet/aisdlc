---
ticket: GH-42-c
title: "anti-slop O(n²) reduce as AP-TS-PERF-005, whole-module mock as AP-TS-MAINT-009"
status: draft
stacks: [slop-guard catalogue, bash]
depends-on: GH-42-a
---

# GH-42-c — Flag O(n²) reduce accumulator copy and whole-module mocking

Source: https://github.com/emgiezet/aisdlc/issues/42 · plan: `specs/GH-42/decomposition.md`

## Problem

Two anti-slop rules remain unported after GH-42-a. `no-reduce-accumulator-copy`
catches a common agent pattern — spreading the accumulator on every reduce iteration —
which creates O(n²) object allocation without any type-system signal. `no-module-mocking`
catches `jest.mock`/`vi.mock` full-module replacement, which couples the test suite to internal
module structure rather than the public contract. Neither can be named or enforced today; both
are assigned to this slice in D36 (GH-42-a).

## Scope

In:
- `plugins/slop-guard/rules/catalog.yaml`: `AP-TS-PERF-005` (severity `warn`, category
  `performance`, `cwe: []`, original text, own `bad`/`good`) for `no-reduce-accumulator-copy`;
  `AP-TS-MAINT-009` (severity `warn`, category `maintainability`, `cwe: []`) for
  `no-module-mocking`. `AP-TS-PERF-005` inserted after `AP-TS-PERF-004` (before `AP-TS-MAINT-001`)
  within §8.4. `AP-TS-MAINT-009` inserted after the last MAINT entry present in §8.4 at merge
  time (currently MAINT-006; MAINT-008 if GH-42-b has merged), before the §8.5 Node.js header.
- `plugins/slop-guard/rules/mapping/eslint.yaml`: entries for `anti-slop/no-reduce-accumulator-copy`
  (ap\_id `AP-TS-PERF-005`, category `performance`) and `anti-slop/no-module-mocking`
  (ap\_id `AP-TS-MAINT-009`, category `maintainability`), both at `warn`.
- `plugins/slop-guard/configs/baseline/eslint.config.mjs`: `anti-slop/no-reduce-accumulator-copy`
  added at `warn` in the TypeScript block; `anti-slop/no-module-mocking` added at `warn` in the
  TypeScript block. Neither rule is turned off in the `tests and scripts: relaxed` block:
  `no-reduce-accumulator-copy` catches production code patterns; `no-module-mocking` is
  specifically designed to fire in test files where `jest.mock`/`vi.mock` appear.
- `plugins/slop-guard/tests/fixtures/ts/bad/AP-TS-PERF-005.ts`: a `reduce` call that spreads the
  accumulator on each iteration (`({ ...acc, [x.id]: x })`), creating O(n²) allocation.
- `plugins/slop-guard/tests/fixtures/ts/bad/AP-TS-MAINT-009.ts`: a `jest.mock('./auth')` call at
  module level replacing the entire module.
- `plugins/slop-guard/tests/fixtures/ts/good/AP-TS-PERF-005.ts`: equivalent reduce that mutates
  the accumulator in place (`acc[x.id] = x; return acc;`) — linear allocation.
- `plugins/slop-guard/tests/fixtures/ts/good/AP-TS-MAINT-009.ts`: targeted `vi.spyOn` on a
  specific export instead of full module replacement.
- `plugins/slop-guard/tests/integration/fast.sh`: two new test blocks —
  one for AP-TS-PERF-005 (one `it_expect_ap` assertion, `CONFIG_SOURCE=full`) and one for
  AP-TS-MAINT-009 (one assertion, `CONFIG_SOURCE=full`); a paired good-fixture block confirms no
  spurious findings.
- `plugins/slop-guard/skills/ts-react-antipatterns/reference/AP-TS-PERF-005.md`: regenerated.
- `plugins/slop-guard/skills/ts-react-antipatterns/reference/AP-TS-MAINT-009.md`: regenerated.
- `plugins/slop-guard/tests/catalog_test.sh`: extend the AP-id existence assertion to include
  `AP-TS-PERF-005` and `AP-TS-MAINT-009`. Preserves the 23-row D36 table count unchanged.
  Checks only this slice's AP ids; passes independently whether or not GH-42-b has merged.
- `plugins/slop-guard/CHANGELOG.md`: `## Unreleased` entry with a **Why** paragraph.

Out:
- Package files — `@spacemansh/anti-slop` already installed by GH-42-a; no new dependency.
- GH-42-b rules (`no-unknown-parameters` through `no-reflect-apply`).
- AP entries MAINT-005 through MAINT-008 delivered by GH-42-a and GH-42-b.
- `tools/tools.lock.json`, `lib/dispatch.sh`, `rules/stacks.json`.
- Effect entry point `@spacemansh/anti-slop/eslint/effect`.
- Oxlint.

Change budget: 224 added lines, 12 files, 2 modules

## Context

- `plugins/slop-guard/rules/catalog.yaml` — `AP-TS-PERF-004` ends the React performance block;
  last MAINT entry in §8.4 is MAINT-006 or higher; §8.5 header follows. `AP-TS-PERF-005` inserted
  after AP-TS-PERF-004 (use the last PERF entry before the first MAINT as anchor). `AP-TS-MAINT-009`
  inserted at the end of §8.4's MAINT block regardless of GH-42-b merge state.
- `plugins/slop-guard/rules/mapping/eslint.yaml` — existing `anti-slop/*` entries at end of file.
- `plugins/slop-guard/configs/baseline/eslint.config.mjs` — `// --- TypeScript ---` block; the
  four GH-42-a rules precede; GH-42-b rules may or may not be present; append after the last
  existing `anti-slop/*` rule.
- `plugins/slop-guard/tests/integration/fast.sh` — `eslint-anti-slop-006-*` blocks (GH-42-a) or
  `eslint-anti-slop-008-*` (GH-42-b if merged) as predecessor pattern; `CONFIG_SOURCE=full`
  required for non-security findings (§D29).
- `plugins/slop-guard/tests/catalog_test.sh` — per-slice AP-id existence list; append
  AP-TS-PERF-005 and AP-TS-MAINT-009 to that list.
- `plugins/slop-guard/scripts/gen-skills` — regenerates `reference/` for entries with
  `prevent_in_skill: true`; run with `--check` to validate without writing.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | agent | writes `items.reduce((acc, x) => ({ ...acc, [x.id]: x }), {})` | fast tier (`CONFIG_SOURCE=full`) reports `AP-TS-PERF-005` from `anti-slop/no-reduce-accumulator-copy` | integration |
| UC-2 | agent | the good fixture: `reduce` that mutates `acc[x.id] = x; return acc;` | no `AP-TS-PERF-005` finding | integration |
| UC-3 | agent | writes `jest.mock('../auth')` at module scope in a test file | fast tier reports `AP-TS-MAINT-009` from `anti-slop/no-module-mocking` | integration |
| UC-4 | agent | writes `vi.spyOn(auth, 'getUser').mockReturnValue(fakeUser)` (targeted spy, no module replacement) | no `AP-TS-MAINT-009` finding | integration |
| UC-5 | maintainer | `scripts/gen-skills --check` | exit 0; `reference/AP-TS-PERF-005.md` and `reference/AP-TS-MAINT-009.md` exist and contain the `bad` and `good` blocks from the catalogue | unit |
| UC-6 | maintainer | `bash tests/catalog_test.sh` | exits 0; `AP-TS-PERF-005` and `AP-TS-MAINT-009` are asserted present in `catalog.yaml` by the ID-existence check added in this slice; the 23-row D36 table count still passes | unit |

## Non-functional

- No new package dependency; both rules ship inside `@spacemansh/anti-slop` 0.3.0 already
  installed by GH-42-a.
- `CI= make validate` and `make tool-integration` (after `doctor --install --all`) pass.
- Generated `SKILL.md` within 150 lines / 3000 tokens.

## Dependencies and collisions

- **Requires GH-42-a merged**: `@spacemansh/anti-slop` installed, plugin registered in
  `eslint.config.mjs`, D36 table present in `decisions.md`.
- **Independent of GH-42-b**: no code or contract from GH-42-b is consumed here. The catalog
  insertion uses the last MAINT entry present at merge time as anchor. Numeric AP id continuity
  is a convention; a gap between MAINT-006 and MAINT-009 (if GH-42-b is not yet merged) is
  acceptable and resolved when GH-42-b lands.
- **Parallel-safe with GH-42-b during implementation**: different catalog entries, different
  fixture files, non-overlapping fast.sh blocks. `CHANGELOG.md`, `catalog.yaml`, and
  `catalog_test.sh` are shared files; avoid adjacent edits or rebase-merge. Each slice extends
  the ID-existence list independently; no implementation coordination required.

## Open questions

none
