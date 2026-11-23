---
ticket: GH-92
title: Align GitHub tracker prerequisites with JSON PR checks
status: draft
stacks: [instructions, bash]
---

# GH-92 — Align GitHub tracker prerequisites with JSON PR checks

## Problem

The GitHub tracker descriptors admit gh 2.40 while their **get-pr-checks** operation uses a JSON flag introduced in gh 2.50. Users on older admitted builds cannot retrieve PR checks through review, merge, fix-pr, autopilot or merge-buddy. The shipped template and this repository's configured descriptor expose the same mismatch; authentication alone currently admits an incompatible CLI.

Source: [issue #92](https://github.com/emgiezet/aisdlc/issues/92), read with its labels and comments (no comments). The reported gh 2.46.0 failure is accepted as reported, not rerun.

## Scope

In:
- Make both GitHub descriptors state gh >= 2.50 and reject an incompatible CLI through **auth-check**, before checking authentication or permitting subsequent operations.
- Preserve **get-pr-checks** and its JSON array of `name`, `state`, `link`, `workflow`; do not change callers or native check-state semantics.
- Add offline executable descriptor-contract coverage in `plugins/sdlc/tests/github_tracker_test.sh` and register it in the existing test runner. Test both actual descriptor bodies, not a rewritten copy of their shell logic.

Out:
- Changes to descriptor operations other than the prerequisites and **auth-check**; **get-pr-checks** remains the existing native JSON command.
- Changes to `plugins/sdlc/commands/review.md`, `merge.md`, `fix-pr.md`, `autopilot.md`, or `merge-buddy.md`; no new required-check policy, retries, polling, or state remapping.
- Changes to `plugins/sdlc/bin/aisdlc`, other tracker providers, descriptor installation/update logic, CI configuration, Makefile limits, manifest versions, analyzer pins, or lockfiles.
- Auto-installing or upgrading gh, changing authentication, switching accounts, or mutating GitHub while testing.
- A `statusCheckRollup` fallback, a second compatibility path, a general version-check framework, or a standalone helper shipped outside the descriptor.

Change budget: 220 added lines, 4 files, 2 modules

## Context

- `plugins/sdlc/templates/trackers/github.md`: **Prerequisites**, **auth-check**, **get-pr-checks** (currently lines 10, 20–22, 89–90); shipped template is 113 lines. `.claude/trackers/github.md`: corresponding sections at lines 10, 20–22, 75–76; configured copy is 98 lines. Preserve their unrelated differences; synchronize only the affected contract.
- `plugins/sdlc/templates/trackers/TEMPLATE.md`: provider rules and **get-pr-checks** contract. `plugins/sdlc/skills/pipeline-contracts/SKILL.md`: descriptor resolution and operation vocabulary. `.claude/sdlc.md`: configured provider, two applicable stacks, UC test-name convention, 400-line / 15-file / 6-module ceiling; no contract directory or ADR location.
- `plugins/sdlc/commands/review.md` Phase 3 and CI handling, `merge.md` gate 2, `fix-pr.md` CI handling, `autopilot.md` First action, and `merge-buddy.md` check collection consume **get-pr-checks**. They are read-only context and require no migration when the native return shape is retained.
- `plugins/sdlc/tests/run-tests`: explicitly sources suites and supplies `ok`/`bad` counters; a new suite needs registration. Inspection of `plugins/sdlc/tests` found no `trackers/github.md` references or GitHub descriptor contract tests. `plugins/sdlc/tests/structure_test.sh` demonstrates standalone/sourced shell-test conventions, but is not a descriptor linter.
- `plugins/sdlc/bin/aisdlc`: `tracker_github_*` functions cover claims and labels; searching the entire runner found no `gh pr checks` invocation or `statusCheckRollup` usage. The issue's `bin/aisdlc` means this plugin path; no root `bin/aisdlc` exists.
- `Makefile` instruction-budget loop (lines 168–173): `make validate` enforces <=120 lines for shipped descriptor templates. Keep the configured copy within the same ceiling without changing the Makefile or unrelated sections.
- Upstream verified on 2026-11-23: [v2.50.0 release](https://github.com/cli/cli/releases/tag/v2.50.0), fetched through `gh api repos/cli/cli/releases/tags/v2.50.0`, has `published_at: 2024-05-29T16:11:45Z` and explicitly lists JSON output for `gh pr checks` ([cli/cli#9079](https://github.com/cli/cli/pull/9079)). [`checks.go` v2.49.2](https://github.com/cli/cli/blob/v2.49.2/pkg/cmd/pr/checks/checks.go) has no JSON exporter; [`checks.go` v2.50.0](https://github.com/cli/cli/blob/v2.50.0/pkg/cmd/pr/checks/checks.go) registers `name`, `state`, `link`, `workflow` and `AddJSONFlags`.
- Rejected alternative evidence: [`api/query_builder.go` v2.40.0](https://github.com/cli/cli/blob/v2.40.0/api/query_builder.go), `StatusCheckRollupGraphQLWithoutCountByState` and `IssueGraphQL`, and [`api/queries_pr.go` v2.40.0](https://github.com/cli/cli/blob/v2.40.0/api/queries_pr.go), `CheckContext` / `CheckSuite`, were fetched through `gh api`. The older CLI supports `statusCheckRollup` and exposes workflow names, but CheckRun and StatusContext fields differ (`name`/`context`, `detailsUrl`/`targetUrl`, `status`+`conclusion`/`state`).
- Sizing: `git log` on descriptor paths followed by `git show --numstat` identified descriptor precedents `566b97d` (3 template additions plus 99 harness-test additions), `86fe584` (13 template additions in a much broader cutover), and `7fc9503` (92 lines for the original GitHub descriptor). Estimate ~20 descriptor additions, <=198 test/helper lines, and 2 runner-registration lines across 4 files: `plugins/sdlc` and `.claude/trackers`. Requested pin-refresh comparisons were also inspected: #77 `1f67172` has 3 integration-test additions and mostly lock churn; #91 `fb8989e` has 88 additions across 4 pin/changelog files; #78 `5e90b65` has 607 additions, mostly its generated npm lock. These are weaker analogues than descriptor-contract changes; none justifies lock or analyzer scope here. No decomposition threshold is crossed.

### Recommended decision and rejected alternative

Recommend raising the minimum to gh 2.50 and enforcing it in **auth-check**. This is one of the issue's explicitly permitted outcomes, preserves native check normalization and JSON fields, and fits the descriptor's seven remaining template lines without introducing a second implementation of check aggregation. The trade-off is explicit: gh 2.40–2.49 users must upgrade instead of continuing with their distribution build. Spec approval accepts that compatibility change; this draft does not authorize implementation.

Reject re-expressing **get-pr-checks** through `gh pr view --json statusCheckRollup` for this ticket. It can keep older clients working, but returning the existing shape requires union-aware field/state/workflow normalization and parity tests rather than returning the raw rollup. That additional behavior and maintenance are unnecessary when the issue permits a truthful minimum. Do not implement both alternatives or claim that older gh lacks rollup support.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | descriptor consumer | reads Prerequisites in either GitHub descriptor | Both state gh >= 2.50 and retain the requirement that **auth-check** pass before other operations; neither admits 2.40 as sufficient. | unit |
| UC-2 | authenticated operator | executes either descriptor's **auth-check** with a supported gh version | Exit 0 with no output after successful authentication. Cover boundary `2.50.0`, patch `2.50.1`, multi-digit minor `2.100.0`, future major `3.0.0`, and a normal distribution suffix such as `gh version 2.50.0 (Ubuntu package)`; comparison uses numeric version components. **Added:** parser boundary cases. | unit |
| UC-3 | operator on older gh | executes either descriptor's **auth-check** with `2.40.0`, `2.46.0`, `2.49.2`, or `1.99.0` | Exit 1 and exactly one diagnostic line `gh >= 2.50 required`; authentication is not attempted and no later tracker operation is permitted by the descriptor contract. **Added:** older-major and boundary coverage. | unit |
| UC-4 | operator with an unavailable or unidentifiable gh | executes either descriptor's **auth-check** when gh is absent, `gh --version` fails, or its output lacks a valid numeric version | Exit 1 and exactly one diagnostic line `gh >= 2.50 required`, with no raw shell/CLI error or usage text; authentication is not attempted. **Added:** fail-closed version-detection cases. | unit |
| UC-5 | unauthenticated operator on supported gh | executes either descriptor's **auth-check** while `gh auth status` fails | Exit 1 and exactly the existing diagnostic line `gh not authenticated`; raw authentication output stays hidden. **Added:** existing authentication-failure regression coverage. | unit |
| UC-6 | caller on supported gh | executes either descriptor's **get-pr-checks** with a PR number against a fake gh returning a mixed check result | The operation still requests `gh pr checks <n> --json name,state,link,workflow` and returns the JSON array unchanged, including `SUCCESS`, `FAILURE`, and `PENDING` entries with all four fields. No wrapper object, status remapping, or rollup fields replace the existing return shape. | unit |

## Non-functional

- Each descriptor remains <=120 lines, particularly the shipped template checked by `make validate`; do not compress unrelated sections to buy space or relax the budget.
- Keep the gate self-contained in the descriptor with ordinary shell/core utilities; no additional runtime dependency or network version lookup. Detect incompatibility before authentication; preserve the authentication check's existing quiet success and one-line failure contract.
- Unit tests extract and execute each real operation body with an isolated fake gh, without GitHub/network access or dependence on the host gh version. Parameterize the same assertions over both descriptors; include `GH-92 UC-<n>` in test names, and cover both sides of every new decision branch. Do not merely grep for a version string or test a duplicate implementation.
- Version-gate and authentication tests require no PR mutations, account switching, token changes, or real login. Check-call logs may prove the negative no-auth boundary; observable outputs and exit status remain the primary assertions.
- Implementation verification: `plugins/sdlc/tests/run-tests`, `bash -n` and the profile's ShellCheck command for changed shell files, plus `CI= make validate` for instructions and descriptor limits. This spec-only branch changes no executable files and does not run those suites.

## Open questions

None. The issue explicitly permits the minimum-version option, and upstream evidence resolves its threshold. The recommended compatibility trade-off is recorded for the human approving this draft.
