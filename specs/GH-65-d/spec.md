---
ticket: GH-65-d
title: JVM Go and Node OpenGrep rules leave their good fixtures silent
status: approved
depends-on: GH-65-c
stacks: [slop-guard catalogue, bash]
---

# GH-65-d — JVM, Go and Node rule/fixture contract

Source: https://github.com/emgiezet/aisdlc/issues/65 · decomposition: `specs/GH-65/decomposition.md`

## Problem

Four rules in the JVM, Go and Node rule files flag safe fixtures. The current tests prove fixture files exist but cannot distinguish safe behavior from an unsafe match. Each affected detector needs to keep its bad-fixture match without flagging good examples.

## Scope

In:
- Remove good-fixture hits from `slopguard.jvm.jackson-default-typing`, `slopguard.jvm.xml-external-entity` (both reported locations), `slopguard.go.http-client-without-timeout`, and `slopguard.node.prototype-pollution-merge`; preserve a bad-fixture hit for each rule.
- Adjust matched fixture pairs (`AP-JVM-SEC-00{5,7}`, `AP-GO-PERF-001`, `AP-NODE-SEC-001`) where necessary; extend the copied-tree OpenGrep integration checks and the Unreleased changelog.

Out:
- C#/Rust/Ruby rule redesign (`GH-65-a`–`GH-65-c`); React and Laravel repairs and all-rule assertion (`GH-65-e`). Earlier checks remain enforced.
- Rule/AP IDs, catalogue, mappings, tool pin, generated skills and dispatch.

Change budget: 300 added lines, 13 files, 2 modules

## Context

- `plugins/slop-guard/rules/opengrep/{jvm,go,node}.yaml` — four named rule IDs and AP metadata.
- `plugins/slop-guard/tests/fixtures/java/{bad,good}/AP-JVM-SEC-00{5,7}.java` — JVM matched pairs.
- `plugins/slop-guard/tests/fixtures/go/{bad,good}/AP-GO-PERF-001.go` and `plugins/slop-guard/tests/fixtures/node/{bad,good}/AP-NODE-SEC-001.js` — other matched pairs.
- `plugins/slop-guard/tests/integration/opengrep.sh` — progressively enforced real-binary case.
- `plugins/slop-guard/CHANGELOG.md` — Unreleased section.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-9 | OpenGrep operator | scans a copy of the fixture tree with the full rules directory | each of the four named IDs hits its matching `bad/` AP fixture at least once | integration |
| UC-10 | OpenGrep operator | scans the copied tree's good fixtures | all four IDs have zero hits under any `good/` directory (both JVM XML reported locations gone), and C#/Rust/Ruby checks still pass | integration |

## Non-functional

- Use the pinned binary; failed scans and invalid JSON remain test failures. Keep the bad samples genuinely insecure and good samples safe, not annotation-based exceptions.

## Open questions

none
