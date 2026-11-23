# QA report — GH-65-c
Verdict: PASS

## UC coverage

| UC | Required observation | Automated test | Result |
|---|---|---|---|
| UC-7 | Copied fixture tree scanned with the full rules directory; each Ruby ID hits its corresponding bad fixture | `plugins/slop-guard/tests/integration/opengrep.sh:80-87`, four `GH-65-c UC-7` cases | PASS: send → 001; mass assignment → 005; SQL interpolation → 006; insecure random → 007 |
| UC-8 | Each Ruby ID silent anywhere under good/; preceding C#/Rust checks retained | `plugins/slop-guard/tests/integration/opengrep.sh:89-95`, four `GH-65-c UC-8` cases plus preceding contracts | PASS: four Ruby negative checks and 24 preceding checks |

Covered: 2/2 UCs automated; 0 ticket skips. No coverage gaps requiring added tests.

Verification map: none. Browser: none — no UI UCs.

Reviewed only `origin/fix/gh65-2-rust-ruby...HEAD` at implementation head `014f6e7064fe2fac279cefc0f8f904ba4d2c8a60`. Spec was read before diff/tests; independent expectations and subsequent AP mapping confirmation are in `qa/expectations.txt`.

Non-functional: resolved OpenGrep is 1.30.0 with the linux-amd64 lock's exact SHA-256 (`qa/opengrep-version.txt`). The full scan succeeded with valid error-free JSON, and the shared scan/JSON error guard remains intact. Fixtures contain actual dangerous calls and safe dispatch lambdas, strong parameters, bound SQL and SecureRandom, not name markers. An independent copied-tree scan returned exit 0, no errors and seven Ruby bad-fixture findings with no good-fixture findings (`qa/scan-summary.json`, `qa/scan.stderr`).

## Test suites

Every suite shell exported:

```sh
export PATH=/tmp/qa-bin:$PATH
export CLAUDE_PLUGIN_DATA=/tmp/slopguard-data-GH-65-c
export CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=plugin-only
```

| Exact command | Final observed result | Exit | Skips |
|---|---|---|---|
| `bash -n plugins/slop-guard/tests/integration/opengrep.sh` | no diagnostics | 0 | 0 |
| `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -S warning plugins/slop-guard/tests/integration/opengrep.sh` | no diagnostics | 0 | 0 |
| `CI= make validate` | 725 slop-guard tests passed; 22 configs validated, 3 skipped, 0 failed; 102 SDLC tests passed; All checks passed | 0 | 3 config tools |
| `plugins/slop-guard/tests/run-tests` | 725 passed, 0 failed | 0 | 0 |
| `plugins/sdlc/tests/run-tests` | 102 passed, 0 failed | 0 | 0 |
| `bash plugins/slop-guard/tests/catalog_test.sh` | 26 passed, 0 failed | 0 | 0 |
| `plugins/slop-guard/scripts/gen-skills --check` | deterministic output, PASSED | 0 | 0 |
| `CI= plugins/slop-guard/scripts/validate-configs` | 22 validated, 3 skipped, 0 failed | 0 | 3 config tools |
| `SLOPGUARD_IT_REQUIRE=1 make tool-integration` | 74 passed, 1 failed, 0 skipped, 2 known; every ticket assertion passed | 2 | 0 |

Logs: `qa/*.log`. Non-green out-of-ticket results are bounded below; PASS means this ticket satisfies its approved UCs, not that every aggregate run was green.

Tiers (new tests): unit 0 / integration 0 / e2e 0

QA added no tests: the required positive/negative assertions already existed and ran against the real pinned binary. The implementation's Ruby cases are integration-tier because its UCs explicitly require real matcher execution; mocking the matcher would not prove them.

Before → after QA: unit slop-guard 725 → 725 passing; SDLC 102 → 102; catalogue 26 → 26. Real-tool integration initially had 73 passing / 1 failed / 1 skipped / 1 known; after correcting the external PHP launcher it had 74 passing / 1 failed / 0 skipped / 2 known. No test code changed; the remaining failure changed from PHPStan to intermittent Checkov.

### Isolated Checkov diagnostic

After the final full suite's non-UC Checkov failure, ran its existing bad/good cases once with debug capture:

```sh
export SLOPGUARD_IT_DEBUG=1
(cd plugins/slop-guard/tests && bash -c 'eval "$(sed -n "1,250p" tool-integration)"; eval "$(sed -n "174,192p" integration/medium.sh)"; printf "%d passed, %d failed, %d skipped, %d known\n" "$PASS" "$FAIL" "$SKIP" "$KNOWN"; test "$FAIL" -eq 0')
```

Result: `2 passed, 0 failed, 0 skipped, 0 known`, exit 0 (`qa/checkov-debug.log`). This is a diagnostic execution of existing cases, not added coverage.

## Findings

None for GH-65-c. No implementation, fixtures, approved spec, existing tests or quarantine entries were changed during QA.

## Not verified

- Consistently green whole-machine integration: final full run failed only Checkov `(M): S3 without event notifications → AP-TF-SEC-018`, although that case passed in the initial full suite and the single debug rerun. Record as **load-flaky-local**; host load/time limits are an inference, not a verified cause. All eight Ruby and 24 preceding OpenGrep assertions passed in both full runs. Successful implementation-head CI: https://github.com/emgiezet/aisdlc/actions/runs/42201880083/job/127838883324 (`qa/ci-head.json`). `gh run view ... --log` returned no log bytes, so no CI test counts are claimed.
- Config validator tool discovery: Psalm, tflint and zizmor are skipped by that validator under the assigned per-ticket data dir. This is not a skip in any ticket assertion. The integration runner does resolve Psalm and reports its existing quarantined `TaintedSql` case; the other known case is zizmor AP-CI-005. Neither exercises UC-7/8.
- Initial environment artefacts are retained in `qa/initial-*.log`: PHPStan failed because the external Docker PHP launcher did not forward `SLOPGUARD_CACHE_DIR`; initial validate also reported a transient kube-linter `no-liveness-probe` lookup failure. A ticket-base archive reproduced the PHPStan config failure (`qa/base-validate-configs.log`). After the launcher was fixed externally, all affected commands were rerun: PHPStan passed, `make validate` passed and direct config validation passed. The old main baseline is superseded; the coordinator's corrected main baseline is `/tmp/qa-toolint-main-2.log`, not used as a locally executed ticket result here. The initial local ESLint case passed, despite its earlier baseline intermittency.
- `make selftest` was not required: neither `bin/aisdlc` nor `evals/harness` changed. Paid model e2e was not run; no ticket UC requires it.
