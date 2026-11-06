---
ticket: SDLC-014
title: Reverse traceability in verify
status: draft
stacks: [bash, instructions]
---

# SDLC-014 — Reverse traceability in verify

## Problem

The queue checks that every acceptance-table UC is named by a changed test, but it does not
check the opposite direction. A branch can therefore add behaviour outside the approved use
cases and still pass the UC coverage row. Maintainers have no machine-readable account of
which changed behaviour belongs to the spec and which has no requirement behind it.

## Scope

In:
- `verify` writes `specs/<TICKET>/traceability.json`, alongside its existing report, with
  `coverage[]` for the spec's UCs and `reverse[]` for changed behaviour with no UC mapping.
- Trace rows use the vocabulary `OK`, `GAP`, `ORPHAN`, `Deferred`, and `N/A`; UC ids remain
  `UC-<n>` and point to evidence in the branch, not a second requirement-id hierarchy.
- An unmapped changed behaviour is an `ORPHAN` finding visible in the JSON and verify report.
- Retain the existing forward coverage gate and ordinary verification-command results.
- Deterministic extraction and fixtures for the mapping contract agreed before approval.

Out:
- Asking a model to decide whether a change is behaviour or whether a mapping is truthful.
- Replacing QA, scope-check, the review findings ledger, or the human spec-approval gate.
- Introducing hierarchical requirement ids, a new workflow engine, or historical backfill.
- Treating a UC mention anywhere in a repository as proof that a changed test covers it.

Change budget: 240 added lines, 5 files, 4 modules

## Context

- `plugins/sdlc/bin/aisdlc` — `run_verify`, specifically the "Every UC in the acceptance
  table has a test that names it" block; `_is_test_path` identifies test paths. The existing
  UC coverage row scans changed test files and records missing ids in `verify_failures`.
- `plugins/sdlc/commands/qa.md` — Phase 3 writes the UC coverage table to `qa-report.md`;
  Phase 2 requires new tests to carry their UC id.
- `plugins/sdlc/skills/spec-authoring/references/spec-template.md` — stable UC table and
  Scope sections; no second requirement-id format is needed.
- `evals/harness/selftest.sh` — runner fixtures and verify assertions.
- `docs/ai-sdlc.md` — user-facing queue and verification documentation.
- External model, paths relative to the read-only comparison clone: the JSON schema has
  `coverage[]` and `reverse[]`, with `reverse` restricted to produced items tracing to no
  upstream id (`core/sensors/aidlc-traceability.md:68-89`); the status vocabulary is declared
  at `core/sensors/aidlc-traceability.md:86-89`. This is a schema model, not a claim that the
  source solves detection of changed behaviour in this bash runner.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | queue runner | verifies a spec with UC-1 and a changed test naming UC-1 | `traceability.json` parses as JSON, contains `coverage[]` and `reverse[]`, and has one `coverage` row for UC-1 with status `OK` and the changed test's repository-relative path as evidence | selftest |
| UC-2 | queue runner | verifies a spec whose UC-2 has no changed test naming it | UC-2 has status `GAP` in `coverage[]`; the existing UC coverage row and `verify_verdict` remain FAIL and the report names UC-2 | selftest |
| UC-3 | queue runner | verifies a fixture containing a changed behaviour with no UC mapping under the agreed extraction contract | `reverse[]` contains that behaviour's identity and repository-relative evidence with status `ORPHAN`; `verify-report.md` names the same orphan | selftest |
| UC-4 | queue runner | verifies the UC-3 fixture after its behaviour is mapped to a declared UC | that behaviour no longer appears as an `ORPHAN` in `reverse[]`; the declared UC remains represented in `coverage[]` | selftest |
| UC-5 | queue runner | verifies a mapping fixture containing each permitted status | emitted rows preserve exactly `OK`, `GAP`, `ORPHAN`, `Deferred`, or `N/A`, without case changes or a second status vocabulary | unit |
| UC-6 | queue runner | repeats verify on unchanged inputs | the coverage and reverse mappings are identical, with stable ordering and no duplicate UC rows; existing command-check results still appear in `verify-report.md` | selftest |

`test` = the lowest tier that can observe the result: `selftest` | `unit` | `integration`.

## Open questions

- [ ] What is the deterministic definition of "changed behaviour"? Decide between changed
  non-test files carrying explicit UC mappings, changed hunks carrying UC mentions, or another
  explicit declaration. A changed file is not necessarily a behaviour, and a UC mention is not
  proof of a relationship. Specify the mapping location, row identity, evidence granularity,
  treatment of deletions, and exclusions for docs/generated/config-only changes before approval;
  UC-3 and UC-4 cannot be implemented honestly until this contract is fixed.
- [ ] Should `ORPHAN` fail verify, or remain a reported finding consumed by scope-check/review?
  Set the verdict policy and any severity explicitly; this draft does not silently add a gate.
- [ ] Who can mark a row `Deferred` or `N/A`, where is its reason stored, and which statuses
  satisfy forward coverage? Preserve UC-2's current failure until a different policy is approved.
- [ ] What schema/version field and evidence-row shape should consumers rely on? Decide how
  multiple tests for one UC and multiple UCs for one behaviour are represented, and what an
  absent UC table produces without weakening today's verify checks.
