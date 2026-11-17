# QA report — GH-65-e
Verdict: GAPS (1 findings, 1 blocking)

## UC coverage
| UC | Requirement | Passing automated evidence | Verified |
|---|---|---|---|
| UC-11 | Three React/Laravel IDs hit their own bad AP fixture | `tests/integration/opengrep.sh:125–146`: 3 real-binary assertions | yes |
| UC-12 | Those IDs have no findings anywhere under good/ | Same named UC-12 assertions: 3 passing, including the React sanitized href/src fixture | yes |
| UC-13 | Every configured exact ID hits its metadata-bound bad AP; missing hits fail naming ID | Whole-ruleset UC-13 assertions: 56 own-AP checks and 13 variant checks; `qa/gate_test.py` additionally proves missing/wrong-ID hits, new-rule discovery, scan failure, malformed JSON and offline skip decisions | yes |
| UC-14 | Every configured exact ID has no good-tree findings | Whole-ruleset UC-14 assertions: 56 passing; `qa/gate_test.py` proves a hit in another AP's good file fails naming the offending ID | yes |

Covered: 4/4 UCs automated. No ticket UC is skipped or failing. The verdict is blocked by the approved scope budget, not by detector behavior.

The pinned OpenGrep resolved from the assigned plugin data directory reports `1.30.0` (`qa/opengrep-version.log`). The shipped integration test scans a copied fixture tree using the entire rule directory and `--no-rewrite-rule-ids`; earlier group assertions remain present and pass. New unit tests exercise the shipped gate's decisions with synthetic scanner output, not the detectors; detector coverage comes exclusively from the real-binary integration suite.

verification map: none
browser: none — no UI UCs.

## Test suites
Tiers (new tests): unit 8 / integration 0 / e2e 0

All suite shells exported `PATH=/tmp/qa-bin:$PATH`, `CLAUDE_PLUGIN_DATA=/tmp/slopguard-data-GH-65-e`, and `CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=plugin-only`. Complete output is committed under `qa/`.

| Exact command | Result | Skips |
|---|---|---|
| `bash -n plugins/slop-guard/tests/integration/opengrep.sh plugins/slop-guard/tests/opengrep_test.sh` | exit 0 | 0 |
| `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -S warning plugins/slop-guard/tests/integration/opengrep.sh plugins/slop-guard/tests/opengrep_test.sh` | exit 0, no diagnostics | 0 |
| `CI= make validate` | exit 2; embedded unit suite 725 passed / 0 failed; config stage 21 validated / 1 failed | 3 config checks; built-in shellcheck unavailable, separately completed above |
| `plugins/slop-guard/tests/run-tests` | exit 0; 725 passed / 0 failed | 0 |
| `plugins/sdlc/tests/run-tests` | exit 0; 102 passed / 0 failed | 0 |
| `bash plugins/slop-guard/tests/catalog_test.sh` | exit 0; 26 passed / 0 failed | 0 |
| `plugins/slop-guard/scripts/gen-skills --check` | exit 0; deterministic output | 0 |
| `plugins/slop-guard/scripts/validate-configs` | exit 1; 21 validated / 1 failed | 3 |
| `SLOPGUARD_IT_REQUIRE=1 make tool-integration` | exit 2; 212 passed / 1 failed / 1 known | 1 |
| `python3 specs/GH-65-e/qa/gate_test.py` | exit 0; 8 tests, OK | 0 |

Tests before → after: 725 → 733 for the slopguard offline runner plus the explicit new QA unit-suite invocation; the existing runner itself remains at 725 and does not auto-discover `qa/gate_test.py`. Other suite counts above are separate, not added into this comparison. The baseline gate suite did not exist (0 → 8); no existing tests were changed. The new offline-skip test asserts skip behavior and itself passes; it is not a skipped test.

## Findings
1. **[major, blocking] Approved added-line budget exceeded** — `specs/GH-65-e/spec.md:28`; implementation expansion includes `plugins/slop-guard/rules/opengrep/react.yaml:44` and `plugins/slop-guard/tests/integration/opengrep.sh:125`. `git diff origin/fix/gh65-4-runtime...HEAD --numstat -- . ':!specs'` measures **361 added lines**, 41 deleted lines, and 10 non-spec files against the approved **240 added-line / 11-file** budget. The source alone exceeds the line cap; QA evidence is excluded. `qa/scope.log` records the per-file counts. Passing behavior does not approve a larger review surface; the spec was not changed.

## Not verified
- A completely green local real-tool suite: the unrelated PHPStan `missingType.return → AP-PHP-MAINT-003` case fails and Psalm is absent, matching the supplied environmental baseline. The unrelated isolated ESLint `anti-slop/no-object-parameters` case passes here (unlike that baseline). The existing zizmor known-failure remains known; no quarantine was edited.
- Complete baseline-config validation: PHPStan fails because `env.SLOPGUARD_CACHE_DIR` is unavailable inside this host's Docker PHP launcher (`/tmp/qa-bin/php` forwards HOME but not that variable); Psalm, tflint and zizmor config checks skip because unavailable. These paths are unchanged by this ticket. `CI= make validate` stops at that config stage; no later stages are claimed as executed by it.
- The implementation head `c770c9a181b48111c95d7aa1fd673b628e7b6dd2` has successful CI evidence for the real pinned-tool workflow: [Validate run](https://github.com/emgiezet/aisdlc/actions/runs/42211070613/job/127869550704) and [runner-and-fixture](https://github.com/emgiezet/aisdlc/actions/runs/42211070613/job/127869550568), captured in `qa/pr-head-checks.json`. This is implementation-head evidence, not a claim that the subsequent QA commit's CI has run. No ticket UC depends on an environmental exemption.
