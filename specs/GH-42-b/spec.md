---
ticket: GH-42-b
title: "anti-slop unknown/object signatures as AP-TS-MAINT-007, Reflect API bypass as AP-TS-MAINT-008"
status: approved
stacks: [slop-guard catalogue, bash]
depends-on: GH-42-a
---

# GH-42-b — Reject unknown-typed signatures and Reflect API calls

Source: https://github.com/emgiezet/aisdlc/issues/42 · plan: `specs/GH-42/decomposition.md`

## Problem

Five anti-slop rules flag functions whose parameter or return types carry no structural information
(`unknown`, `object`, `{ [key: string]: unknown }`). Two more flag `Reflect.get` and
`Reflect.apply`, which bypass TypeScript's property-access and call-site type safety entirely.
None of these can be named or enforced today; they are assigned to this slice in D36 (GH-42-a).

## Scope

In:
- `plugins/slop-guard/rules/catalog.yaml`: `AP-TS-MAINT-007` (severity `warn`, category
  `maintainability`, `cwe: []`, original text, own `bad`/`good`) covering the five
  unknown/object-signature rules; `AP-TS-MAINT-008` (severity `warn`, category `maintainability`,
  `cwe: []`) covering `no-reflect-get` and `no-reflect-apply`. Both entries inserted after
  `AP-TS-MAINT-006` within §8.4.
- `plugins/slop-guard/rules/mapping/eslint.yaml`: entries for all seven rule ids of this slice
  (`anti-slop/no-unknown-parameters`, `anti-slop/no-unknown-returns`,
  `anti-slop/no-unknown-type-aliases`, `anti-slop/no-object-parameters`,
  `anti-slop/no-unsafe-dictionary-type`, `anti-slop/no-reflect-get`,
  `anti-slop/no-reflect-apply`), each mapping to the correct AP id at `warn`.
- `plugins/slop-guard/configs/baseline/eslint.config.mjs`: seven rules added at `warn` in the
  TypeScript block (`// --- TypeScript ---`), after the existing four GH-42-a rules.
- `plugins/slop-guard/tests/fixtures/ts/bad/AP-TS-MAINT-007.ts`: five declarations, one per
  anti-slop rule, each triggering exactly one finding.
- `plugins/slop-guard/tests/fixtures/ts/bad/AP-TS-MAINT-008.ts`: one `Reflect.get` and one
  `Reflect.apply` call.
- `plugins/slop-guard/tests/fixtures/ts/good/AP-TS-MAINT-007.ts`: concrete-typed equivalents
  of the five bad declarations.
- `plugins/slop-guard/tests/fixtures/ts/good/AP-TS-MAINT-008.ts`: direct property access and
  typed function call replacing each Reflect call.
- `plugins/slop-guard/tests/integration/fast.sh`: two new test blocks — one for AP-TS-MAINT-007
  (five `it_expect_ap` assertions, `CONFIG_SOURCE=full`) and one for AP-TS-MAINT-008 (two
  assertions, `CONFIG_SOURCE=full`); a paired good-fixture block confirms no spurious findings.
- `plugins/slop-guard/skills/ts-react-antipatterns/reference/AP-TS-MAINT-007.md`: regenerated.
- `plugins/slop-guard/skills/ts-react-antipatterns/reference/AP-TS-MAINT-008.md`: regenerated.
- `plugins/slop-guard/tests/catalog_test.sh`: extend the AP-id existence assertion to include
  `AP-TS-MAINT-007` and `AP-TS-MAINT-008`. The 23-row count on the D36 decisions table is
  already correct (all rows committed by GH-42-a) and is preserved unchanged. The new assertion
  checks only this slice's AP ids against `catalog.yaml`; it does not check ids from GH-42-c,
  so the test passes independently after this slice merges.
- `plugins/slop-guard/CHANGELOG.md`: `## Unreleased` entry with a **Why** paragraph.

Out:
- Package files (`package.json`, `package-lock.json`) — `@spacemansh/anti-slop` already
  installed by GH-42-a; no new dependency.
- `AP-TS-MAINT-005/006` entries — already delivered by GH-42-a.
- GH-42-c rules (`no-reduce-accumulator-copy`, `no-module-mocking`).
- `tools/tools.lock.json`, `lib/dispatch.sh`, `rules/stacks.json`.
- Effect entry point `@spacemansh/anti-slop/eslint/effect`.
- Oxlint.

Change budget: 273 added lines, 12 files, 2 modules

## Context

- `plugins/slop-guard/rules/catalog.yaml` — `AP-TS-MAINT-005` and `AP-TS-MAINT-006` at end of
  §8.4 (copy the entry shape); §8.5 header follows immediately after.
- `plugins/slop-guard/rules/mapping/eslint.yaml` — existing `anti-slop/*` entries at end of file
  (copy structure from GH-42-a additions).
- `plugins/slop-guard/configs/baseline/eslint.config.mjs` — `// --- TypeScript ---` block;
  `plugins: { 'anti-slop': antiSlop }` already registered; the four GH-42-a rules precede.
- `plugins/slop-guard/tests/integration/fast.sh` — `eslint-anti-slop-006-*` blocks as the
  direct predecessor pattern; `CONFIG_SOURCE=full` required for maintainability findings (§D29).
- `plugins/slop-guard/tests/catalog_test.sh` — UC-1 block from GH-42-a: 23-row D36 table count
  (§UC-1) plus per-slice AP-id existence list; append MAINT-007 and MAINT-008 to that list.
- `plugins/slop-guard/scripts/gen-skills` — regenerates `reference/` for entries with
  `prevent_in_skill: true`; run with `--check` to validate without writing.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | agent | writes an unknown parameter (`function process(raw: unknown): void {}`) or an unknown alias (`type Payload = unknown;`) in separate fixtures | fast tier (`CONFIG_SOURCE=full`) reports `AP-TS-MAINT-007` with the corresponding `anti-slop/no-unknown-parameters` or `anti-slop/no-unknown-type-aliases` rule | integration |
| UC-2 | agent | writes `function build(): unknown { return {}; }` | fast tier reports `AP-TS-MAINT-007` from `anti-slop/no-unknown-returns` | integration |
| UC-3 | agent | writes `function send(opts: object): void {}` | fast tier reports `AP-TS-MAINT-007` from `anti-slop/no-object-parameters` | integration |
| UC-4 | agent | writes `const cache: { [key: string]: unknown } = {};` used as a parameter type | fast tier reports `AP-TS-MAINT-007` from `anti-slop/no-unsafe-dictionary-type` | integration |
| UC-5 | agent | writes `const v = Reflect.get(obj, 'id');` | fast tier reports `AP-TS-MAINT-008` from `anti-slop/no-reflect-get` | integration |
| UC-6 | agent | writes `const r = Reflect.apply(fn, null, [arg]);` | fast tier reports `AP-TS-MAINT-008` from `anti-slop/no-reflect-apply` | integration |
| UC-7 | agent | runs the paired concrete-type and direct-property/call good fixtures for all seven adopted detectors | no `AP-TS-MAINT-007` or `AP-TS-MAINT-008` findings; bad fixtures continue to produce their expected rule-specific findings | integration |
| UC-8 | maintainer | `scripts/gen-skills --check` | exit 0; `reference/AP-TS-MAINT-007.md` and `reference/AP-TS-MAINT-008.md` exist and contain the `bad` and `good` blocks from the catalogue | unit |

## Non-functional

- No new package dependency; the seven rules ship inside `@spacemansh/anti-slop` 0.3.0 already
  installed by GH-42-a.
- `CI= make validate` and `make tool-integration` (after `doctor --install --all`) pass.
- Generated `SKILL.md` within 150 lines / 3000 tokens (unchanged constraint from GH-42-a).

## Dependencies and collisions

- **Requires GH-42-a merged**: `@spacemansh/anti-slop` installed, plugin registered in
  `eslint.config.mjs`, D36 table present in `decisions.md`.
- **Parallel-safe with GH-42-c**: different catalog entries (MAINT-007/008 vs PERF-005/MAINT-009),
  different fixture files, non-overlapping fast.sh blocks. `CHANGELOG.md` and `catalog_test.sh`
  are shared files; avoid adjacent edits or rebase-merge. Each slice extends the ID-existence
  list independently; no implementation coordination required.

## Open questions

none
