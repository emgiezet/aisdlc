# QA report — GH-65-d
Verdict: PASS

## UC coverage

Reviewed approved spec before implementation/tests; pre-diff observables are in `qa/expectations.txt`. Diff base: `origin/fix/gh65-3-ruby`; implementation head: `002bc5d565a296f5de6274382a11b193f8054046`.

| UC | Required observable | Automated test | Evidence | Verified |
|---|---|---|---|---|
| UC-9 | Each named JVM/Go/Node rule detects its matching bad AP fixture in a copied full-tree scan | `tests/integration/opengrep.sh:103-110`, four `GH-65-d UC-9` cases | `qa/tool-integration-corrected.log:81-87` | Yes, four passing assertions |
| UC-10 | All four IDs silent throughout all good directories; C#/Rust/Ruby checks retained | `tests/integration/opengrep.sh:111-118`, four `GH-65-d UC-10` cases, plus earlier-slice contracts | `qa/tool-integration-corrected.log:49-88` | Yes, four passing assertions and 32 prior-slice assertions |

Covered: 2/2 UCs automated; no ticket UC skipped. Existing assertions match the specified observables, so no additional tests were needed.

Independent copied-tree scan with pinned OpenGrep **1.30.0**, full rules directory and `--disable-nosem` also exited 0 with `errors: []`: Go 12, Jackson 1, XML 2, Node 9 findings, all under bad directories; zero target-rule good-directory findings. This additionally exercised the new Go return/zero-timeout and Node request-key fixtures. Actual locations are in `qa/runtime-results.json`; command and stderr are preserved alongside it. Safe Java fixtures use explicit named subtypes and disabled StAX DTD/external entities, not suppression annotations; bad fixtures retain unsafe operations. The existing scan gate rejects nonzero exit, invalid JSON, missing results and scanner errors.

verification map: none
browser: none — no UI UCs.

## Test suites

Tiers (new tests): unit 0 / integration 0 / e2e 0

All commands ran in the isolated ticket worktree with:

```sh
export PATH=/tmp/qa-bin:$PATH
export CLAUDE_PLUGIN_DATA=/tmp/slopguard-data-GH-65-d
export CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=plugin-only
```

| Exact command | Actual result | Skips | Log |
|---|---|---|---|
| `bash -n plugins/slop-guard/tests/integration/opengrep.sh` | exit 0 | 0 | `qa/bash-syntax.log` |
| `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -S warning plugins/slop-guard/tests/integration/opengrep.sh` | exit 0; no diagnostics | 0 | `qa/shellcheck.log` |
| `plugins/slop-guard/scripts/gen-skills --check` | exit 0; deterministic output check PASSED | 0 | `qa/gen-skills.log` |
| `plugins/slop-guard/scripts/validate-configs` | exit 0; **22 validated, 3 skipped, 0 failed** | 3 | `qa/validate-configs-corrected.log` |
| `bash plugins/slop-guard/tests/catalog_test.sh` | exit 0; **26 passed, 0 failed** | 0 | `qa/catalog.log` |
| `plugins/slop-guard/tests/run-tests` | exit 0; **725 passed, 0 failed** | 0 | `qa/slopguard-tests.log` |
| `plugins/sdlc/tests/run-tests` | exit 0; **102 passed, 0 failed** | 0 | `qa/sdlc-tests.log` |
| `CI= make validate` | exit 0; slop-guard **725 passed, 0 failed**, configs **22 validated, 3 skipped, 0 failed**, SDLC **102 passed, 0 failed**; All checks passed | 3 config checks | `qa/validate-corrected.log` |
| `SLOPGUARD_IT_REQUIRE=1 make tool-integration` | exit 0; **83 passed, 0 failed, 0 skipped, 2 known** | 0 | `qa/tool-integration-corrected.log` |

Tests before → after QA: slop-guard **725 → 725**, SDLC **102 → 102**, catalogue **26 → 26**, real-tool integration **81 → 83**. No tests were added; the integration increase reflects the environment correction below, not a coverage change.

The initial runs (`qa/validate.log`, `qa/validate-configs.log`, `qa/tool-integration.log`) recorded PHPStan failures caused by the Docker PHP launcher dropping `SLOPGUARD_CACHE_DIR`. After the coordinator corrected the external launcher, all affected commands were rerun once; the table shows these final results. PHPStan now passes. Psalm became resolvable by the integration runner on the corrected run: its safe case passes and its unsafe case is reported as the existing quarantine in `tests/integration/KNOWN-FAILING:21`, explaining the second known result. The baseline's flaky-local ESLint `anti-slop/no-object-parameters` case passes in both local executions. All ticket and preceding-slice OpenGrep assertions pass in both runs.

## Findings

1. **[minor, non-blocking] Approved added-line budget exceeded** — `specs/GH-65-d/spec.md:27` allows 300 added lines; `git diff --numstat origin/fix/gh65-3-ruby...HEAD -- . ':!specs'` totals **337 added, 18 deleted, 13 files**. The extra Go/Node fixtures remain within the named runtime-rule scope, and do not undermine the passing UC contracts, but the approved numeric budget was exceeded.

## Not verified

- The existing quarantined zizmor and Psalm unsafe-detection cases remain unverified as passing: `qa/tool-integration-corrected.log:12,91` records both as known failures. Neither exercises UC-9/UC-10; no quarantine entry was modified. PR-head CI executed successfully at [Validate run 42201906215](https://github.com/emgiezet/aisdlc/actions/runs/42201906215/job/127838968487), for the exact implementation head above; captured metadata: `qa/pr-checks.json`. CI is supporting evidence, not a replacement for local UC coverage.
- Configuration-only checks for Psalm, tflint and zizmor were skipped because the validator did not find those executables in its PATH (`qa/validate-configs-corrected.log`). The real-tool integration resolver nevertheless executed their relevant suite cases; all OpenGrep runtime contracts were exercised locally. `CI= make validate` was run with the prescribed empty CI value, not strict tool-availability mode.
- No ticket UC remains unverified. No implementation or spec files were modified, no tests were removed/weakened or newly skipped, and no tool pins or known-failing entries were changed.
