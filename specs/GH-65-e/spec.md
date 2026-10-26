---
ticket: GH-65-e
title: React and Laravel OpenGrep fixes with a whole-ruleset fixture gate
status: approved
depends-on: GH-65-d
stacks: [slop-guard catalogue, bash]
---

# GH-65-e — complete issue #65 fixture contract

Source: https://github.com/emgiezet/aisdlc/issues/65 · decomposition: `specs/GH-65/decomposition.md`

## Problem

React flags sanitized URLs; two Laravel rules miss their bad fixtures. Even after individual repairs, newly added or unchanged OpenGrep rules can regress because the offline test checks only fixture existence. Operators need one runnable contract for every configured rule.

## Scope

In:
- Remove good-fixture hits for `slopguard.react.href-js-scheme` (both reported locations); restore bad-fixture hits for `slopguard.php.laravel.mass-assignment-request-all` and `slopguard.php.laravel.unbounded-all`.
- Repair matching `AP-TS-SEC-004`, `AP-PHP-SEC-005`, and `AP-PHP-PERF-002` fixture pairs as necessary.
- Expand `tests/integration/opengrep.sh` from the scoped checks to *every* rule discovered in `rules/opengrep/`: each rule hits its own AP bad fixture at least once and has no hit anywhere under `good/`. Maintain an offline skip and a mandatory check where the pinned binary is installed. Correct stale offline-test commentary and add an Unreleased changelog entry.

Out:
- Redesign of already repaired detectors from `GH-65-a`–`GH-65-d`; removal/quarantine of failing tests or of pre-existing OpenGrep rules.
- Catalogue/AP IDs, mappings, tool pin, generated skills, detection dispatch, CI setup and changes outside this issue's OpenGrep fixture contract.

Change budget: 240 added lines, 11 files, 2 modules

## Context

- `plugins/slop-guard/rules/opengrep/react.yaml`, `plugins/slop-guard/rules/opengrep/php-laravel.yaml` — three named rule IDs and AP bindings.
- `plugins/slop-guard/rules/opengrep/*.yaml` — full rule set; discover IDs dynamically rather than hardcode a count.
- `plugins/slop-guard/tests/fixtures/ts/{bad,good}/AP-TS-SEC-004.tsx` and `plugins/slop-guard/tests/fixtures/php/{bad,good}/AP-PHP-{SEC-005,PERF-002}.php` — affected pairs.
- `plugins/slop-guard/tests/integration/opengrep.sh` — progressively scoped real-binary checks from `GH-65-a`.
- `plugins/slop-guard/tests/opengrep_test.sh` — offline fixture-presence checks and now-stale commentary.
- `plugins/slop-guard/tests/tool-integration` — integration discovery, `it_skip_unless_tool` and CI skip gate.
- `plugins/slop-guard/CHANGELOG.md` — Unreleased section.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-11 | OpenGrep operator | scans the copied fixture tree with the entire rule directory | each of the three named React/Laravel IDs has at least one hit in its own `bad/` AP fixture | integration |
| UC-12 | OpenGrep operator | scans the same fixture tree's good examples | those three IDs have zero hits anywhere under `good/`, including both React sanitized URL locations | integration |
| UC-13 | integration runner | runs `make tool-integration` with pinned OpenGrep installed against the copied fixture tree | every configured rule ID has ≥1 hit in its own AP bad fixture; missing hits fail with the rule ID | integration |
| UC-14 | integration runner | runs `make tool-integration` with pinned OpenGrep installed against the copied good fixtures | every configured rule ID has zero hits anywhere under `good/`; each offending rule ID fails the test | integration |

## Non-functional

- Scan a copy of `tests/fixtures/` so OpenGrep's default `tests/` ignore does not hide the samples. Match by full rule ID and corresponding `metadata.ap_id`; a hit from another rule in the file cannot satisfy the criterion. Derive the set of IDs from rule files so new rules are checked automatically.
- Retain all previously enforced group checks, including a failing scan/JSON parse and good-fixture hits outside a rule's own AP pair.

## Open questions

none
