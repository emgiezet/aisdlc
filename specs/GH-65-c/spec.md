---
ticket: GH-65-c
title: Ruby OpenGrep rules distinguish dangerous calls from permitted use
status: approved
depends-on: GH-65-b
stacks: [slop-guard catalogue, bash]
---

# GH-65-c — Ruby rule/fixture contract

Source: https://github.com/emgiezet/aisdlc/issues/65 · decomposition: `specs/GH-65/decomposition.md`

## Problem

A safe Ruby `send` call is flagged, while insecure random, mass assignment and SQL interpolation rules miss their bad fixtures. Offline fixture existence checks do not exercise the Ruby matchers. Consumers need the rule ID to identify the unsafe example without accusing the safe one.

## Scope

In:
- Restore hits for `slopguard.ruby.insecure-random`, `slopguard.ruby.mass-assignment-without-permit`, `slopguard.ruby.sql-string-interpolation`; remove the good-fixture hit for `slopguard.ruby.send-user-input` while preserving its bad-fixture hit.
- Repair corresponding `AP-RB-SEC-00{1,5,6,7}` fixture pairs when necessary, expand the copied-tree OpenGrep integration case to cover these IDs, and add an Unreleased changelog entry.

Out:
- Rework of C# (`GH-65-a`) or Rust (`GH-65-b`) detectors, JVM/Go/Node (`GH-65-d`), React/Laravel and all-rule assertion (`GH-65-e`). Existing slice checks must remain passing.
- Catalogue/AP IDs, mappings, tool pin, generated skills and detection dispatch.

Change budget: 220 added lines, 11 files, 2 modules

## Context

- `plugins/slop-guard/rules/opengrep/ruby.yaml` — Ruby rule IDs and AP mappings.
- `plugins/slop-guard/tests/fixtures/ruby/{bad,good}/AP-RB-SEC-00{1,5,6,7}.rb` — corresponding fixture pairs, including placeholder examples.
- `plugins/slop-guard/tests/integration/opengrep.sh` — scoped real-binary regression from `GH-65-a`.
- `plugins/slop-guard/CHANGELOG.md` — Unreleased section.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-7 | OpenGrep operator | scans the copied fixture tree with the full rules directory | each of the four named Ruby rule IDs has at least one hit on its corresponding `ruby/bad/AP-RB-SEC-00{1,5,6,7}.rb` fixture | integration |
| UC-8 | OpenGrep operator | scans the same tree's good fixtures | each of the four Ruby IDs has zero hits under any `good/` directory; previous C# and Rust checks still pass | integration |

## Non-functional

- Use the pinned real binary and preserve failures for scan/JSON errors. Examples must show an actual dangerous call and a corresponding safe operation, not rule-name markers.

## Open questions

none
