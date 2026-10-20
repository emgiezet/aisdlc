---
ticket: GH-42
title: "slop-guard: map dmmulroy/anti-slop TypeScript rules into AP-TS-* catalog"
status: decomposed
stacks: [slop-guard catalogue, bash]
---

# GH-42 — Map anti-slop into the AP-TS-\* catalogue

Source: https://github.com/emgiezet/aisdlc/issues/42

## Problem

slop-guard names TypeScript type-safety slop with one broad entry, `AP-TS-MAINT-001`. Agents also
produce narrower patterns that pass the type checker by fabricating or discarding type evidence.
dmmulroy/anti-slop catalogues 15 Oxlint rules for "low-evidence TypeScript"; the ESLint port
`@spacemansh/anti-slop` 0.3.0 tracks upstream commit `c44ef22`. No prior record existed of which
rules slop-guard adopts and why.

## Decomposition

| slice | status | what it delivers |
|-------|--------|-----------------|
| [GH-42-a](../GH-42-a/spec.md) | **merged** (777f93f) | Decision D36 recorded; `AP-TS-MAINT-005` (chained / uncommented assertions) and `AP-TS-MAINT-006` (widen-then-assert) enabled; `@spacemansh/anti-slop` 0.3.0 installed |
| [GH-42-b](../GH-42-b/spec.md) | approved | `AP-TS-MAINT-007` (unknown/object signatures) and `AP-TS-MAINT-008` (Reflect API bypass); 7 rules enabled |
| [GH-42-c](../GH-42-c/spec.md) | approved | `AP-TS-PERF-005` (O(n²) reduce accumulator copy) and `AP-TS-MAINT-009` (whole-module mock); 2 rules enabled |

## D36 mapping coverage

All 23 D36 rows in `plugins/slop-guard/docs/decisions.md` §D36 are accounted for:
- 4 rules ported in GH-42-a (MAINT-005, MAINT-006)
- 7 rules ported in GH-42-b (MAINT-007, MAINT-008)
- 2 rules ported in GH-42-c (PERF-005, MAINT-009)
- 1 rule covered by existing `AP-TS-MAINT-001` (`no-runtime-typeof`)
- 5 rules rejected: Effect-only architecture (no Effect framework in catalogue)
- 4 rules rejected: style/formatting/taste — not low-evidence code

## Dependencies between slices

- **GH-42-b and GH-42-c both depend on GH-42-a**: `@spacemansh/anti-slop` 0.3.0 must be
  installed and the plugin registered in `eslint.config.mjs` before either slice can enable rules.
- **GH-42-b and GH-42-c are independent of each other**: no shared code contract, no shared
  file that one's output feeds into the other's input. Either MAY merge first. Numeric AP id
  ordering is a convention, not a runtime dependency.
- `catalog_test.sh`'s ID-existence assertion grows per slice; each slice independently satisfies
  the gate for its own AP ids without requiring the other slice to be present.

## Out of scope for all slices

- Oxlint adoption (recorded in `docs/ideas.md`).
- Non-TypeScript languages.
- `AP-TS-MAINT-001` text or detector changes.
- The issue also requires synchronising the external `trasti-sdlc` vendor copy. Its checkout
  and `docs/upstream-split.md` are not present in this repository; that delivery prerequisite
  must be resolved before calling the parent issue complete.
- Effect entry point `@spacemansh/anti-slop/eslint/effect`.
