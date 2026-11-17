# QA report — GH-65-a
Verdict: GAPS (1 findings, 0 blocking)

## UC coverage

| UC | Required observation | Automated test / evidence | Verified |
|---|---|---|---|
| UC-1 | Each of six C# IDs hits its own numbered bad fixture | `integration/opengrep.sh`: six `GH-65-a UC-1` assertions; `qa/suite-7.log` | Yes, real OpenGrep |
| UC-2 | Those IDs are silent under every good directory | `integration/opengrep.sh`: six `GH-65-a UC-2` assertions; `qa/suite-7.log` | Yes, real OpenGrep |
| UC-3 | Missing scanner records one skip; required-tools runner fails | `qa/runner-contract-test.sh`: two `UC-3` cases; `qa/runner-contract.log` | Yes |
| UC-4 | Failed scan / invalid JSON cannot pass | `qa/runner-contract-test.sh`: four `UC-4` cases (nonzero exit, malformed JSON, missing results, parse errors); `qa/runner-contract.log` | Yes |

Covered: 4/4 UCs automated. Ticket assertions: 13 → 19. No ticket UC skipped.
Verification map: none. Browser: none; no UI UCs.

The pinned scanner reports `1.30.0` (`qa/opengrep-version.txt`). The real-binary case scans a copied fixture tree with the entire rules directory, checks exact check IDs, and rejects scanner errors. Spec-first expectations are in `qa/expectations.txt`.

## Test suites

All suite shells exported:
```sh
export PATH=/tmp/qa-bin:$PATH
export CLAUDE_PLUGIN_DATA=/tmp/slopguard-data-GH-65-a
export CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=plugin-only
```

Tiers (new tests): unit 0 / integration 6 / e2e 0

Reason for integration-only additions: UC-3 and UC-4 explicitly require integration coverage of runner accounting and exit status. The tests execute unchanged copies of the shipped runner and its OpenGrep case; only the external scanner is fault-injected. There is no separate application unit invariant to duplicate.

| Exact command | Observed result | Evidence |
|---|---|---|
| `CI= make validate` | Corrected-launcher rerun: exit 0, All checks passed; 725 slop-guard and 102 SDLC assertions passed; config validation: 22 validated, 3 skipped, 0 failed | `qa/suite-1-corrected.log` |
| `plugins/slop-guard/tests/run-tests` | 725 passed, 0 failed; exit 0 | `qa/suite-2.log` |
| `plugins/sdlc/tests/run-tests` | 102 passed, 0 failed; exit 0 | `qa/suite-3.log` |
| `bash plugins/slop-guard/tests/catalog_test.sh` | 26 passed, 0 failed; exit 0 | `qa/suite-4.log` |
| `plugins/slop-guard/scripts/gen-skills --check` | Deterministic output check PASSED; exit 0 | `qa/suite-5.log` |
| `plugins/slop-guard/scripts/validate-configs` | Corrected-launcher rerun: 22 validated, 3 skipped, 0 failed; exit 0 | `qa/suite-6-corrected.log` |
| `SLOPGUARD_IT_REQUIRE=1 SLOPGUARD_IT_DEBUG=1 make tool-integration` | Corrected-launcher rerun: 55 passed, 1 failed, 0 skipped, 2 known; exit 2; all 13 ticket assertions passed | `qa/suite-7-corrected.log` |
| `bash -n plugins/slop-guard/tests/tool-integration plugins/slop-guard/tests/integration/opengrep.sh` | Exit 0 | `qa/suite-8.log` |
| `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -S warning plugins/slop-guard/tests/tool-integration plugins/slop-guard/tests/integration/opengrep.sh` | Exit 0, no warnings | `qa/suite-9.log` |
| `bash specs/GH-65-a/qa/runner-contract-test.sh` | 6 passed, 0 failed, 0 skipped; exit 0 | `qa/runner-contract.log` |
| `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -S warning specs/GH-65-a/qa/runner-contract-test.sh` | Exit 0, no warnings | `qa/new-test-shellcheck.log` |

No existing tests were changed. No implementation or spec was changed. `make selftest` is not required by the Bash rules here: neither `bin/aisdlc` nor `evals/harness` changed.

## Findings

1. **[minor, non-blocking] Approved file budget exceeded** — `specs/GH-65-a/spec.md:28` allows 15 files. `git diff --name-only origin/main...HEAD -- . ':!specs' | wc -l` returned **16** implementation files. `git diff --numstat origin/main...HEAD -- . ':!specs' | awk '{n+=$1} END {print n}'` returned **334** added lines, within the 350-line limit. The extra direct-process and resolver-reenabled fixture files are relevant regression examples, not unrelated changes; nevertheless the explicit file limit is unmet. All four behavioral UCs pass; this finding, not a behavioral failure, determines GAPS.

## Not verified

- Full local real-tool integration is not green: after the PHP launcher's environment-forwarding correction, PHPStan's missing-return-type case still fails, now because its parallel worker crashes with exit 139 / segmentation fault (`qa/suite-7-corrected.log`). This is a different failure from the original missing-environment-variable artefact; no C# UC depends on PHPStan. The successful implementation-head CI run linked below is the available non-local coverage.
- The original launcher-affected outputs remain in `qa/suite-1.log`, `qa/suite-6.log`, and `qa/suite-7.log` as historical evidence, superseded by the `-corrected.log` reruns. The original config-validation failure is resolved: PHPStan validation now passes. Psalm is now reachable by the integration runner: its bad case is quarantined `known` and its good case passes, so the corrected integration run has zero skips and two known cases (Psalm and zizmor).
- The supplied baseline's flaky-local ESLint `no-object-parameters` failure passed in both of this ticket's runs. No claim is made that it is permanently resolved.
- Config validation still skips Psalm, tflint, and zizmor through its direct PATH lookup. It does not validate OpenGrep rules itself (its output says so); the real OpenGrep full-rules scan passed instead. These limitations are outside the touched C# rules, not silently counted as passes.
- CI at implementation head `4506b194e588c0b084eabb0648a647280ba07e7e` reports successful Validate and runner-and-fixture checks, including the real-tool suite: https://github.com/emgiezet/aisdlc/actions/runs/42201785412/job/127838570377 . Snapshot: `qa/pr-checks.json`. CI for this QA evidence commit has not been observed.
