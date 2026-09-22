---
ticket: SDLC-009
title: Test environment and browser QA — test-env, integration-tests, browser pass in auto-qa, ux-review
status: draft
stacks: [instructions, runner]
---

# SDLC-009 — Test environment and browser QA

## Problem

`auto-qa` proves a UI change by reading tests and running `curl`. A spec row that says "the
button is disabled while saving" has no observable result until something opens a browser, and
nothing in the pipeline boots the application or knows how to. UI PRs therefore ship with
`Not verified` sections a human has to close by hand — the review cost the harness exists to
remove.

## Scope

In:
- Browser descriptor bodies for `playwright` and `agent-browser` (operations named in SDLC-005).
- `/sdlc:test-env [--down]`: discover, generate portable bring-up, boot, health-check, warm reuse.
- `/sdlc:integration-tests <ticket>`: explore the running app, write E2E tests for UI UCs in the
  repo's runner, run them, diagnose failures from artefacts.
- `auto-qa` browser pass: walk UI UCs, screenshot per UC, referenced from `qa-report.md`; `ship`
  attaches them via `attach-image-evidence`.
- `/sdlc:ux-review <pr#>`: walk the PR's UI against `.claude/rules/design-system.md`.
- Sandbox: a `ui-flow` harness scenario over the fixture's JS frontend.

Out:
- Shipping a browser or a runtime: the descriptor installs what the provider documents; a repo
  without either gets `Browser descriptor: none` and every step here is skipped with one line.
- Visual regression baselines, pixel diffs, accessibility audits.
- Mobile/device emulation beyond the viewport the descriptor's `open` takes.

## Context

- `specs/SDLC-005/spec.md` — `Browser descriptor:` profile key; operations `boot-check open goto
  click fill assert-text screenshot close`; tracker `attach-image-evidence`.
- `plugins/sdlc/agents/auto-qa.md` § "Order of work" step 5 (hand-verify uncovered UCs — the
  browser pass replaces `curl` for UI UCs) and the `qa-report.md` format (new `Screenshots` column).
- `plugins/sdlc/commands/ship.md` Phase 2 step 5 — evidence comment gains the images.
- `plugins/sdlc/templates/sdlc.md` § "Test conventions" `End-to-end runner`, `Integration tests
  need` — `test-env` reads both; § "Stacks and verification" for boot discovery.
- `plugins/sdlc/templates/playbooks/ui-feature.md` — the playbook that names the states a UI UC
  must cover.
- `evals/fixtures/sandbox/` JS frontend and `evals/harness/scenarios/go-endpoint/scenario.json` —
  the scenario format `ui-flow` extends with an `artifacts_exist` assertion.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | developer | `/sdlc:test-env` on a repo with compose or a Makefile run target | `.aisdlc/test-env/{up.sh,down.sh,env.json}` generated; app booted; `env.json` has `base_url`, `started_at`, `health_url`, `provider`; a second call within the same session reuses the instance and prints `warm` | e2e |
| UC-2 | developer | `/sdlc:test-env` where no boot method is discoverable | stops with `cannot boot: no compose, Makefile target, or profile command found` and writes `up.sh` as a template with the three places to fill | e2e |
| UC-3 | developer | `/sdlc:test-env --down` | `down.sh` runs; `env.json` removed; nothing else touched | e2e |
| UC-4 | qa agent | `/sdlc:integration-tests <T>` with `End-to-end runner: Playwright` | one test per UI UC in the spec, named with the UC id, using locators read from the running DOM (no hard-coded ids invented), fixtures created at runtime; suite runs; each failure diagnosed from trace/screenshot as `app bug | test bug | env` in the report | e2e |
| UC-5 | qa agent | `/sdlc:qa <T>` on a spec with UI UCs and a configured browser descriptor | `specs/<T>/qa/UC-<n>.png` per UI UC; `qa-report.md` coverage table has a `Screenshot` column linking each; a UC whose observable result cannot be seen on screen is `Not verified` with the reason; `/sdlc:ship` posts the images through `attach-image-evidence` | e2e |
| UC-6 | qa agent | `/sdlc:qa <T>` with `Browser descriptor: none` | the browser pass is skipped with one line `browser: none — UI UCs verified by tests only`; verdict rule unchanged | e2e |
| UC-7 | designer | `/sdlc:ux-review <pr#>` | PR UI walked in the browser against `.claude/rules/design-system.md`; findings each tagged `[SCREENSHOT: path]` or `[RULE: line]`, with a `Done when:`; posted as one PR comment; no labels changed; no `design-system.md` → refuses with `run /sdlc:ux-setup first` | e2e |
| UC-8 | maintainer | `make harness-eval SCENARIO=ui-flow` | scenario asserts `artifacts_exist: ["specs/SBX-4/qa/UC-1.png"]` and `qa_verdict: PASS`; `make selftest` covers the `artifacts_exist` scorer offline | unit |

## Non-functional

- Every browser step goes through the descriptor; no command names `playwright` or
  `agent-browser` directly.
- `test-env` scripts are POSIX shell, run on Linux, macOS and WSL2, and never require root.
- Screenshots are evidence, not tests: the verdict still comes from assertions, and a screenshot
  never turns `GAPS` into `PASS`.
- `make validate`, `make selftest`, `make eval-dry` stay green; the `ui-flow` scenario is added
  to the CI "Scenario specs" check but not run there (it costs money).

## Open questions

- [ ] none
