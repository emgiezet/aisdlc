---
ticket: GH-94
title: Move the Psalm pin to a mature 7.x release without losing PHP security coverage
status: draft
stacks: [bash, slop-guard catalogue]
---

# GH-94 — Mature Psalm 7 pin

## Problem

Slop Guard still provisions Psalm 6.16.1 for PHP projects, although stable Psalm 7 releases now exceed the repository's seven-day publication hold. The earlier hold recorded in PR #78 no longer justifies that pin. Users need the newer analyser without losing baseline-config compatibility or SQL-taint findings on CI's PHP 8.3.

## Scope

In:
- Upgrade only the Psalm lock entry to the newest stable 7.x release whose GitHub publication timestamp is strictly older than seven days at implementation-start UTC; record that timestamp, cutoff, selected tag and excluded newer tags in the rationale. Freeze this selection for the run rather than chasing releases during verification.
- Update all four existing PHAR asset URLs and locally recomputed SHA-256 values; document the upgrade and any actual compatibility changes in the Slop Guard changelog.
- Make only Psalm-7-required config, harness or JSON-parser adaptations; retain baseline analysis policy and existing security mappings.
- Prove real Psalm/PHPStan fixture compatibility on PHP 8.3, including a passing, non-quarantined Psalm SQL-taint case and the overlay-mode regression. Adjust only the Psalm quarantine entry when its actual test passes.

Out:
- PHPStan or any other analyser pin; npm/Python bundles; new update automation or changes to the publication-hold policy.
- Catalogue/AP IDs, security categories, severity/CWE mappings, changed-file filtering semantics, enforcement modes or tool/config-source precedence.
- Laravel/plugin API migrations, consumer-project configuration rewrites, Psalm purity-annotation adoption, or broad PHP fixture refactors.
- CI workflow/PHP-version changes, plugin release versions, generated skills, eval fixtures, unrelated quarantines or retired tests.
- Weakening assertions, hiding Psalm config/runtime failures, disabling taint analysis, new suppressions/baselines, skips or new quarantine entries to obtain green results.

Change budget: 220 added lines, 12 files, 1 modules

## Context

- `plugins/slop-guard/tools/tools.lock.json`, `tools.psalm` — version, executable and four platform asset records; `plugins/slop-guard/tools/tools.lock-rationale.md`, “Version bump procedure” and “7-day publication rule” — selection/hash contract. Verified GitHub releases at `2026-11-23T08:32:12Z` give cutoff `2026-11-16T08:32:12Z`: [7.7.0](https://github.com/vimeo/psalm/releases/tag/7.7.0), published `2026-11-16T00:50:00Z`, is the newest eligible stable 7.x; [7.8.0](https://github.com/vimeo/psalm/releases/tag/7.8.0), published `2026-11-16T16:29:54Z`, and every higher 7.x are still held. Recompute eligibility at implementation start; 7.8.0 becomes eligible later on drafting day.
- `plugins/slop-guard/configs/baseline/psalm.xml`; `plugins/slop-guard/scripts/validate-configs`, Psalm harness; `.github/workflows/validate.yml`, setup-php step — runtime/config constraints. Tagged [7.7.0 composer.json](https://github.com/vimeo/psalm/blob/7.7.0/composer.json) requires 64-bit PHP `~8.2.27 || ~8.3.16 || ~8.4.3 || ~8.5.0 || ~8.6.0` and XML/mbstring/tokenizer extensions; PHP 8.3 must be at least 8.3.16. Tagged [config.xsd](https://github.com/vimeo/psalm/blob/7.7.0/config.xsd) retains `errorLevel`, `findUnusedCode`, `findUnusedBaselineEntry`, `cacheDirectory`, `projectFiles` and `ignoreFiles`. Tagged [UPGRADING.md](https://github.com/vimeo/psalm/blob/7.7.0/UPGRADING.md) lists plugin-API/taint-internals BC changes, and the [7.0.0 announcement](https://github.com/vimeo/psalm/releases/tag/7.0.0) announces default-on security analysis; neither establishes fixture success. Recheck these tagged files if a later eligible target is selected.
- `plugins/slop-guard/lib/stop.sh`, `_stop_run_psalm` — JSON normalization, `^Tainted` selection, changed-PHP-basename filtering and `finding_add` security mapping; `plugins/slop-guard/tests/stop_test.sh`, Psalm stub section; `plugins/slop-guard/tests/config_mode_test.sh`, section 7 — parser and overlay regression anchors. Parser changes are conditional on observed real Psalm 7 output, not speculative API churn.
- `plugins/slop-guard/tests/integration/stop.sh`, Psalm bad/good cases; `plugins/slop-guard/tests/integration/medium.sh`, PHPStan bad/good cases; `plugins/slop-guard/tests/integration/KNOWN-FAILING`, Psalm SQL-taint label; `plugins/slop-guard/tests/tool-integration`, `_it_is_known` and required-tool mode — real-tool evidence and the expiring-quarantine contract. The existing good Psalm fixture defines an uncalled safe function; a meaningful negative test must actually analyse a reachable safe query. `plugins/slop-guard/CHANGELOG.md` is the release-note destination.
- `.claude/sdlc.md`, change budget/test tiers — one-module estimate against `git log` and `git show --numstat`: pin refresh #77 (`1f67172`) added 14 changelog/3 integration lines plus lock updates; #91's refresh (`fb8989e`) added 16 changelog lines plus lock updates; #78's follow-up (`bed756e`) added 5 changelog/14 rationale lines plus lock updates. The 220-line allowance adds focused parser/config/fixture regressions to that mechanical baseline; 12 named implementation files remain below 400 lines/15 files/6 modules. Lock files and specs are excluded by the profile; this estimate conservatively includes the tools lock in its file allowance. Source: [issue #94](https://github.com/emgiezet/aisdlc/issues/94) and [PR #78](https://github.com/emgiezet/aisdlc/pull/78); #78 explicitly did not verify Psalm 7 fixtures.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | maintainer | Provisions the selected mature Psalm 7 PHAR into fresh plugin data using plugin-only tool resolution on supported PHP 8.3 | Doctor succeeds, the installed Psalm reports the selected exact 7.x version, and all four lock asset records point to that immutable tag with the SHA-256 computed from its local download. Rationale records publication/cutoff evidence proving no higher stable 7.x was eligible when selected; changelog names the upgrade. | integration |
| UC-2 | maintainer | Validates the shipped Psalm baseline against the selected binary with fixture project paths | The real analyser accepts the shipped XML policy and analyses the good PHP fixtures without config-schema, unknown-option, path or runtime errors; `validate-configs --strict` reports Psalm PASS, not SKIP. The checked policy is the shipped baseline with only fixture path/cache localization, not an independently maintained permissive substitute. | integration |
| UC-3 | PHP user | Runs the balanced stop gate on the existing reachable `$_GET` → `PDO::query` bad fixture using real Psalm 7 | The gate reports `AP-PHP-SEC-001` from `TaintedSql` with unchanged security/blocker/CWE-89 mapping. The named integration case is an ordinary pass, absent from `KNOWN-FAILING`, rather than known/skipped. | integration |
| UC-4 | PHP user | Runs the stop gate on a reachable parameterized-query fixture analysed by real Psalm 7 | Psalm completes without config/runtime failure and produces no `TaintedSql`; the gate emits no `AP-PHP-SEC-001` for that fixture. An uncalled function or failed analyser is not evidence of safety. **Added negative-case strengthening.** | integration |
| UC-5 | PHP user | Processes a changed PHP file's Psalm `TaintedSql` output in overlay mode | Stored findings retain the SQL-taint finding with `tool=psalm`, `tool_rule=TaintedSql`, `category=security`, `severity=blocker`, `ap_id=AP-PHP-SEC-001` and `CWE-89`; overlay does not silence it. Extend the existing overlay regression using the observed Psalm 7 issue shape. | unit |
| UC-6 | stop-gate parser | Processes a non-`Tainted*` Psalm issue for a changed PHP file | No finding is added by the Psalm taint runner for that issue; Psalm 7's broader/default-on analysis does not turn ordinary type issues into security findings. **Added negative case.** | unit |
| UC-7 | stop-gate parser | Processes a `TaintedSql` issue whose PHP basename is absent from the changed-PHP-file set | No finding is added for that issue; the existing changed-file boundary remains intact after any output adaptation. **Added negative case.** | unit |
| UC-8 | maintainer | Runs the existing PHPStan bad/good integration pair with the unchanged PHPStan pin on PHP 8.3 | The bad fixture still reports `AP-PHP-MAINT-003` and the fully typed good fixture remains silent; both cases pass without skips or quarantine. | integration |

## Non-functional

- Every UC has a test name containing its `UC-<n>` identifier. Reuse existing regression locations; offline unit tests must not download PHARs or invoke Docker/network services.
- Verify real tools with fresh `CLAUDE_PLUGIN_DATA` and `CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=plugin-only`; record `php --version`, extensions, selected Psalm version and raw taint-output evidence. Do not use a project Psalm 6 installation or a stub as proof of Psalm 7 compatibility.
- Implementation verification: fresh `plugins/slop-guard/bin/slopguard doctor --install --all`; `plugins/slop-guard/scripts/validate-configs --strict`; `SLOPGUARD_IT_REQUIRE=1 make tool-integration`; `plugins/slop-guard/tests/run-tests`; catalogue checks and shell syntax/shellcheck for changed scripts according to the profile. No Psalm case may be skipped/known; unrelated existing quarantines are not part of this ticket. Record any baseline-independent failure honestly rather than changing unrelated tools.
- Keep baseline `errorLevel=3`, unused-code policy and security issue mappings equivalent. Only a demonstrated Psalm 7 incompatibility permits an XML/parser adjustment; document the exact upstream change and verification evidence.

## Open questions

None. Release eligibility is evaluated once at implementation start under the existing publication rule; the draft-time candidate is evidence, not permission to choose a younger release. No new authorization boundary or owner-policy decision is introduced.
