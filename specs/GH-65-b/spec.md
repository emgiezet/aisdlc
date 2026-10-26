---
ticket: GH-65-b
title: Rust OpenGrep rules match unsafe operations without flagging documented safe code
status: approved
depends-on: GH-65-a
stacks: [slop-guard catalogue, bash]
---

# GH-65-b — Rust rule/fixture contract

Source: https://github.com/emgiezet/aisdlc/issues/65 · decomposition: `specs/GH-65/decomposition.md`

## Problem

The Rust unsafe-block rule flags a good fixture, while four Rust detection rules do not flag their bad fixtures. A rule/fixture pair that merely exists is not evidence of a working detector. Rust operators need positive and negative results from the pinned binary.

## Scope

In:
- Restore hits for `slopguard.rs.command-injection`, `slopguard.rs.from-utf8-unchecked`, `slopguard.rs.mem-transmute`, `slopguard.rs.raw-pointer-deref`; remove the good-fixture hit for `slopguard.rs.unsafe-block` without losing its bad-fixture hit.
- Repair the corresponding `AP-RS-SEC-00{1,5,6,7,8}` bad/good Rust examples as needed, expand `tests/integration/opengrep.sh` to enforce these IDs, and document fixes in the Unreleased changelog.

Out:
- C# behavior from `GH-65-a` (retain its test), Ruby (`GH-65-c`), JVM/Go/Node (`GH-65-d`), React/Laravel and full-rule gate (`GH-65-e`).
- Rule/AP IDs, catalogue, mappings, binary pin, generated skills and dispatch; no blanket disabling of unsafe-block detection.

Change budget: 270 added lines, 13 files, 2 modules

## Context

- `plugins/slop-guard/rules/opengrep/rust.yaml` — five named rule IDs and their AP metadata.
- `plugins/slop-guard/tests/fixtures/rust/{bad,good}/AP-RS-SEC-00{1,5,6,7,8}.rs` — paired examples; several bad fixtures currently contain only placeholders.
- `plugins/slop-guard/tests/integration/opengrep.sh` — scoped real-binary checks from `GH-65-a`.
- `plugins/slop-guard/CHANGELOG.md` — Unreleased fixes.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-5 | OpenGrep operator | scans the copied fixture tree with the full rules directory | each of the five Rust IDs produces at least one hit on its corresponding `rust/bad/AP-RS-SEC-00{1,5,6,7,8}.rs` fixture | integration |
| UC-6 | OpenGrep operator | scans the same tree's good fixtures | each of the five Rust IDs produces zero hits under any `good/` directory; C# checks from `GH-65-a` still pass | integration |

## Non-functional

- Keep the copied-tree scan, pinned version and scan/JSON failure behavior established by `GH-65-a`; show real unsafe operations in bad examples and appropriate safe counterparts in good examples.

## Open questions

none
