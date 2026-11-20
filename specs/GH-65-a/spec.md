---
ticket: GH-65-a
title: C# OpenGrep rules match bad fixtures without flagging good ones
status: approved
stacks: [slop-guard catalogue, bash]
---

# GH-65-a — C# rule/fixture contract

Source: https://github.com/emgiezet/aisdlc/issues/65 · decomposition: `specs/GH-65/decomposition.md`

## Problem

OpenGrep flags the safe C# process-start fixture but misses five unsafe C# fixtures. The existing offline fixture check cannot detect either defect. Operators cannot trust the C# rule results as a detection contract.

## Scope

In:
- Restore matches for `slopguard.cs.crypto-weak-algorithm`, `slopguard.cs.insecure-random`, `slopguard.cs.ldap-injection`, `slopguard.cs.path-traversal`, `slopguard.cs.xxe-xml`; remove the good-fixture hit from `slopguard.cs.process-start-user-input` while retaining its bad-fixture hit.
- Add `tests/integration/opengrep.sh` to exercise the pinned binary against a copy of `tests/fixtures/`, reporting per-rule failures for the C# group. Continue to expand this same test in slices `GH-65-b` through `GH-65-e`.
- Correct corresponding C# fixture pairs when necessary so bad examples exercise the actual unsafe operation and good examples show the safe counterpart; add an Unreleased changelog entry.

Out:
- Rust (`GH-65-b`), Ruby (`GH-65-c`), JVM/Go/Node (`GH-65-d`) and React/Laravel (`GH-65-e`) defects; do not suppress or assert them in this slice.
- Rule IDs, AP IDs, catalogue, mappings, binary pin, generated skills and detection dispatch changes.
- Replacing or weakening `tests/opengrep_test.sh` offline checks.

Change budget: 350 added lines, 15 files, 2 modules

## Context

- `plugins/slop-guard/rules/opengrep/csharp.yaml` — C# rule IDs and `metadata.ap_id` bindings.
- `plugins/slop-guard/tests/fixtures/csharp/{bad,good}/AP-CS-SEC-00{3,4,5,6,7,8}.cs` — paired fixtures for the six IDs in scope.
- `plugins/slop-guard/tests/opengrep_test.sh` — existing offline rule and fixture-presence checks.
- `plugins/slop-guard/tests/tool-integration` — sources `tests/integration/*.sh`, provides `it_skip_unless_tool`, `it_ok`, `it_bad`, and counts skips as failures under `SLOPGUARD_IT_REQUIRE=1`.
- `plugins/slop-guard/tests/integration/medium.sh` — existing pinned OpenGrep integration precedent.
- `plugins/slop-guard/CHANGELOG.md` — Unreleased entry for shipped fixes.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | OpenGrep operator | scans a copied fixture tree with the entire rules directory | each of the six listed C# rule IDs produces at least one result in its own `csharp/bad/AP-CS-SEC-00{3,4,5,6,7,8}.cs` fixture, including process-start | integration |
| UC-2 | OpenGrep operator | scans the same tree's good fixtures | each of those six C# IDs produces zero results under **any** `good/` directory, including the original process-start hit | integration |
| UC-3 | integration runner | runs the new case without an available OpenGrep binary | `it_skip_unless_tool opengrep` records one skip; `SLOPGUARD_IT_REQUIRE=1` makes the integration suite exit nonzero | integration |
| UC-4 | integration runner | runs the new case with OpenGrep but the scan fails or yields invalid JSON | the case fails rather than treating the result as an empty successful scan | integration |

## Non-functional

- Run OpenGrep 1.30.0 over a copied fixture tree, not the source `tests/` tree (OpenGrep ignores `tests/` by default); report check IDs rather than accept a different rule's hit on the same file.
- A parse error or failed scan is a failure, never an empty-results success. Keep fixtures valid examples of their intended bad/good behavior, not bare marker strings.

## Open questions

none
