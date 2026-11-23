# QA report — GH-65-b
Verdict: PASS

## UC coverage

| UC | Required observation | Automated test / evidence | Verified |
|---|---|---|---|
| UC-5 | Each of five Rust IDs hits its own numbered bad fixture in a copied-tree, full-rules scan | `plugins/slop-guard/tests/integration/opengrep.sh:48-55`: five `GH-65-b UC-5` cases; additional SAFETY-string case at lines 71-77 | PASS, six assertions |
| UC-6 | Each Rust ID is silent everywhere under good/; inherited C# checks remain passing | `plugins/slop-guard/tests/integration/opengrep.sh:57-62`: five `GH-65-b UC-6` cases; C# contracts at lines 23-46 | PASS, five Rust and twelve C# assertions |

Covered: 2/2 UCs automated; 0 manual-only; 0 failing; 0 ticket skips.
Verification map: none. Browser: none — no UI UCs.

Fresh independent verification on 2026-11-23 read the approved spec before the implementation diff and tests. Current PR base is `main`; `git diff --numstat origin/main...HEAD -- . ':!specs'` at `e89f4a8` measures **122 added lines, 14 files, 1 module** (`plugins/slop-guard`). All are within the owner's **270 added lines, 14 files, 2 modules** budget at `spec.md:27`. Exact measurements and spec-first expectations: `qa/fresh/budget.txt`, `qa/fresh/expectations.txt`. This supersedes the previous 13-file-budget finding.

Non-functional checks: the fresh real-tool suite used version-matched OpenGrep 1.30.0, copied the fixture tree, scanned the complete rules directory, and passed its exit/JSON/errors guard. All five required Rust IDs hit their own bad fixtures, including the SAFETY-string adversarial case; none hit any good fixture. Inherited C# assertions also passed. Bad examples contain real unsafe operations; safe counterparts use documented FFI, references, `f32::from_bits`, validated UTF-8 and fixed/allowlisted process arguments. IDs, pins, catalogue, mappings, dispatch and generated skills are unchanged.

## Test suites

Suite shells exported:

```sh
export CLAUDE_PLUGIN_DATA=/tmp/budget-gh65b-tools
export CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=plugin-only
export TMPDIR=/home/mgz/budget-gh65b-install-tmp
export PATH="$PWD/specs/GH-65-b/qa/bin:$PATH"
```

The existing committed PHP launcher supplies PHP 8.3 through Docker. Initial checks with the host cache failed (30 passing, 1 failing, 27 skipped integration assertions; 17 validated/10 skipped configs). A reusable but newer cache also mismatched pins (57 passing, 1 failing, 5 skipped; 21 validated/5 skipped configs). These were environment failures, not accepted results. A dedicated pinned toolchain was installed; tmpfs quota interrupted tflint, so its storage was moved to the host filesystem and the existing pinned AWS 0.48.0 ruleset cache reused. Doctor then reported every tool present and version-matched. All attempts and final outputs are retained in `qa/fresh/`.

| Exact command | Observed output / result | Exit | Skips | Fresh evidence |
|---|---|---|---|---|
| `plugins/slop-guard/bin/slopguard doctor --install --all` | `All tools present and version-matched.` | 0 | 0 | `qa/fresh/install-home.log` |
| `SLOPGUARD_IT_REQUIRE=1 make tool-integration` | `67 passed, 0 failed, 0 skipped, 2 known` | 0 | 0 | `qa/fresh/integration-final.log` |
| `plugins/slop-guard/tests/run-tests` | `725 passed, 0 failed` | 0 | 0 | `qa/fresh/slopguard.log` |
| `plugins/sdlc/tests/run-tests` | `102 passed, 0 failed` | 0 | 0 | `qa/fresh/sdlc.log` |
| `make selftest` | `441 passed, 0 failed` | 0 | 0 | `qa/fresh/selftest.log` |
| `CI= make validate` | `725 passed, 0 failed`; `25 validated, 0 skipped (not validated — tools absent), 0 failed`; `102 passed, 0 failed`; `All checks passed.` | 0 | 0 | `qa/fresh/validate-final.log` |
| `bash plugins/slop-guard/tests/catalog_test.sh` | `26 passed, 0 failed` | 0 | 0 | `qa/fresh/catalogue.log` |
| `plugins/slop-guard/scripts/gen-skills --check` | `gen-skills: --check PASSED: output is deterministic.` | 0 | 0 | `qa/fresh/generated.log` |
| `CI= plugins/slop-guard/scripts/validate-configs` | `25 validated, 0 skipped (not validated — tools absent), 0 failed` | 0 | 0 | `qa/fresh/configs-final.log` |
| `bash -n plugins/slop-guard/tests/integration/opengrep.sh` | No diagnostics | 0 | 0 | `qa/fresh/syntax.log` |
| `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -S warning plugins/slop-guard/tests/integration/opengrep.sh` | No diagnostics | 0 | 0 | `qa/fresh/shellcheck.log` |

Tiers (new tests): unit 0 / integration 0 / e2e 0

No test gaps needed closing: existing UC-tagged integration assertions directly prove both requested UCs with the real pinned scanner. No implementation, spec or existing tests were edited. The implementation adds eleven integration assertions; the integration-only shape is justified by both UCs explicitly requiring real scanner behavior, not a mockable application unit invariant.

Before → after QA: 1335 → 1335 passing assertions (725 slop-guard + 102 SDLC + 67 real-tool + 441 selftest; duplicate catalogue and aggregate reruns excluded), 2 → 2 existing known failures, 0 → 0 final skips. Ticket assertions: 11 → 11. No tests were added, deleted, skipped, weakened or focused.

## Findings

None. Both UCs are automated and passing; the current-base diff satisfies the widened approved budget.

## Not verified

- The two existing quarantined integration failures remain unproven: zizmor's missing-persist-credentials detection and Psalm's TaintedSql detection. The runner reports both as `known`, not as passed or skipped. Neither exercises this ticket's Rust/C# contracts; quarantine entries were not changed.
- No independent fault-injection rerun of inherited GH-65-a scanner-error cases was added: the copied-tree scan and its failure guard are unchanged in this stacked diff, and the real full scan passed. This is not a claim that the scanner detects every Rust program or that safe fixtures compile/link as a complete Rust crate.
- No paid model e2e was run; no sandbox fixture or CI configuration was modified. Initial prerequisite failures are disclosed above rather than counted as passing. Earlier `qa/` evidence remains historical; this verdict uses the fresh outputs in `qa/fresh/`.
