# QA report — GH-65-b
Verdict: GAPS (1 findings, 0 blocking)

## UC coverage

| UC | Required observation | Automated test / evidence | Verified |
|---|---|---|---|
| UC-5 | Each of five Rust IDs hits its own numbered bad fixture in a copied-tree, full-rules scan | `plugins/slop-guard/tests/integration/opengrep.sh:48-55`: five `GH-65-b UC-5` cases; additional SAFETY-string case at lines 71-77 | PASS, six assertions |
| UC-6 | Each Rust ID is silent everywhere under good/; inherited C# checks remain passing | `plugins/slop-guard/tests/integration/opengrep.sh:57-62`: five `GH-65-b UC-6` cases; C# contracts at lines 23-46 | PASS, five Rust and twelve C# assertions |

Covered: 2/2 UCs automated; 0 manual-only; 0 failing; 0 ticket skips.
Verification map: none. Browser: none — no UI UCs.

Spec was read before the diff and tests. Scope is `origin/fix/gh65-1-csharp...HEAD` at implementation head `c906579`, excluding `specs/` from budgets. Expectations are recorded in `qa/expectations.txt`.

Non-functional checks: OpenGrep 1.30.0 has the lock's exact linux-amd64 SHA-256 (`qa/opengrep-version.txt`). Existing tests scan a copied fixture tree with the complete rules directory and retain the scan-exit/JSON/error guard. An independent copied-tree scan also exited 0 with no errors; its exact Rust and C# results are in `qa/scan-summary.json`, with scanner stderr in `qa/scan.stderr`. All five required Rust IDs hit their own bad fixtures, including the additional SAFETY-string adversarial fixture; none hit any good fixture. Bad examples contain real operations rather than stubs. Good counterparts use documented FFI, a reference dereference, `f32::from_bits`, validated UTF-8 and a fixed executable with allowlisted subcommands. No IDs, pins, mappings, catalogue, dispatch or generated skills changed.

## Test suites

Suite shells exported:

```sh
export CLAUDE_PLUGIN_DATA=/tmp/slopguard-data-GH-65-b
export CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=plugin-only
# After the first installation attempt, provide the absent host PHP runtime:
export PATH="$PWD/specs/GH-65-b/qa/bin:$PATH"
```

The committed PHP launcher runs the available `aisdlc-tool-bumps-php:8.3` Docker image with host paths and cache environment preserved. Initial doctor failed only PHPStan/Psalm installation because host PHP was absent (`qa/install.log`); the corrected doctor installed both and reported all tools present and version-matched (`qa/install-with-php.log`). Unit/catalogue/generated-skill checks and changed-test lint ran before that launcher was needed.

| Exact command | Observed output / result | Exit | Skips | Evidence |
|---|---|---|---|---|
| `plugins/slop-guard/bin/slopguard doctor --install --all` (with PHP launcher) | `All tools present and version-matched.` | 0 | 0 | `qa/install-with-php.log` |
| `SLOPGUARD_IT_REQUIRE=1 make tool-integration` | `67 passed, 0 failed, 0 skipped, 2 known` | 0 | 0 | `qa/tool-integration.log` |
| `plugins/slop-guard/tests/run-tests` | `725 passed, 0 failed` | 0 | 0 | `qa/slopguard-unit.log` |
| `plugins/sdlc/tests/run-tests` | `102 passed, 0 failed` | 0 | 0 | `qa/sdlc-unit.log` |
| `CI= make validate` | `725 passed, 0 failed`; `25 validated, 0 skipped (not validated — tools absent), 0 failed`; `102 passed, 0 failed`; `All checks passed.` | 0 | 0 | `qa/validate.log` |
| `bash plugins/slop-guard/tests/catalog_test.sh` | `26 passed, 0 failed` | 0 | 0 | `qa/catalogue.log` |
| `plugins/slop-guard/scripts/gen-skills --check` | `gen-skills: --check PASSED: output is deterministic.` | 0 | 0 | `qa/gen-skills.log` |
| `CI= plugins/slop-guard/scripts/validate-configs` | `25 validated, 0 skipped (not validated — tools absent), 0 failed` | 0 | 0 | `qa/configs.log` |
| `bash -n plugins/slop-guard/tests/integration/opengrep.sh` | No diagnostics | 0 | 0 | `qa/bash-syntax.log` |
| `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -S warning plugins/slop-guard/tests/integration/opengrep.sh` | No diagnostics | 0 | 0 | `qa/shellcheck.log` |
| `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -S warning specs/GH-65-b/qa/bin/php` | No diagnostics | 0 | 0 | `qa/php-launcher-shellcheck.log` |

Tiers (new tests): unit 0 / integration 0 / e2e 0

No test gaps needed closing: existing UC-tagged integration assertions directly prove both requested UCs with the real pinned scanner. No implementation, spec or existing tests were edited. The implementation adds eleven integration assertions; the integration-only shape is justified by both UCs explicitly requiring real scanner behavior, not a mockable application unit invariant.

Before → after QA: 894 → 894 passing assertions (725 slop-guard + 102 SDLC + 67 real-tool; duplicate catalogue and aggregate reruns excluded), 2 → 2 existing known failures, 0 → 0 skips. Ticket assertions: 11 → 11. No tests were added, deleted, skipped, weakened or focused.

## Findings

1. **[minor, non-blocking] Approved file budget exceeded** — `specs/GH-65-b/spec.md:27` allows **13 files**. The stacked-base diff, excluding `specs/`, contains **14 files**, **122 added lines**, and **1 module** (`qa/budget.txt`). Lines and modules satisfy the 270-line / 2-module limits. The extra `plugins/slop-guard/tests/fixtures/rust/bad/AP-RS-SEC-001-string.rs:1` is a relevant adversarial example, not unrelated scope, but the explicit file limit is unmet. This finding determines GAPS despite both behavioral UCs passing.

## Not verified

- The two existing quarantined integration failures remain unproven: zizmor's missing-persist-credentials detection and Psalm's TaintedSql detection. The runner reports both as `known`, not as passed or skipped. Neither exercises this ticket's Rust/C# contracts; quarantine entries were not changed.
- No independent fault-injection rerun of inherited GH-65-a scanner-error cases was added: the copied-tree scan and its failure guard are unchanged in this stacked diff, and the real full scan passed. This is not a claim that the scanner detects every Rust program or that safe fixtures compile/link as a complete Rust crate.
- `make selftest` was not run: neither `bin/aisdlc` nor `evals/harness` changed. No paid model e2e, remote CI observation, GitHub operation or push was performed.
