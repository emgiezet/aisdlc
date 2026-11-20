# QA report — GH-65-a
Verdict: PASS

## UC coverage

| UC | Required observation | Automated test / evidence | Verified |
|---|---|---|---|
| UC-1 | Each of six C# IDs hits its own numbered bad fixture | `tests/integration/opengrep.sh`: six `GH-65-a UC-1` assertions | Passed |
| UC-2 | Those IDs are silent under every good directory | `tests/integration/opengrep.sh`: six `GH-65-a UC-2` assertions | Passed |
| UC-3 | Missing scanner records one skip; required-tools runner fails | `qa/runner-contract-test.sh`: two `UC-3` cases | Passed |
| UC-4 | Failed scan / invalid JSON cannot pass | `qa/runner-contract-test.sh`: four `UC-4` cases; real-scan control in `tests/integration/opengrep.sh` | Passed |

Reviewed independently of the rule and fixture implementation on `d355c90`,
with current `main` (`1f67172`) integrated.

Covered: 4/4 UCs automated. Ticket assertions: 13 → 19. No ticket UC skipped.
Verification map: none. Browser: none; no UI UCs.

The lockfile-verified scanner reports `1.30.0`. The real-binary case scans a copied fixture tree with the entire rules directory, checks exact check IDs, and rejects scanner errors. Spec-first expectations from the original independent pass are in `qa/expectations.txt`.

## Test suites

| Command | Observed result |
|---|---|
| `SLOPGUARD_IT_REQUIRE=1 SLOPGUARD_IT_DEBUG=1 bash "$qa_plugin/tests/tool-integration"` with the unmodified runner, OpenGrep integration case, copied fixtures and pinned plugin data | 13 passed, 0 failed, 0 skipped, 0 known |
| `bash specs/GH-65-a/qa/runner-contract-test.sh` | 6 passed, 0 failed, 0 skipped. One missing-tool skip was deliberately induced in the child runner and tested in both optional and required modes. |
| Docker ShellCheck `-S warning` on `tool-integration`, `integration/opengrep.sh` and `qa/runner-contract-test.sh` | Exit 0, no warnings |
| `CI= make validate` | Exit 0: 725 Slop Guard and 102 SDLC assertions passed; local config validation ran 17 checks and skipped 10 unavailable tools. |

Tiers (new tests): unit 0 / integration 6 / e2e 0. UC-3 and UC-4 require integration coverage of runner accounting and exit status. The committed tests execute the shipped code and fault-inject only the external scanner.

No rules, fixtures, specs or assertions were changed during the follow-up QA.

## Findings

None for this slice. The earlier 16-file result is superseded: the debug-wrapper fix is now in `main`, so only 15 non-spec files and 331 added lines remain against the approved limits of 15 files and 350 lines.

## Not verified

- The focused run did not run unrelated analyzer integration cases. The full local suite's previous unrelated PHPStan failure is preserved in `qa/suite-7-corrected.log`; the previous GitHub run with the QA evidence was green ([44047978333](https://github.com/emgiezet/aisdlc/actions/runs/44047978333)).
- Strict CI on the refreshed head is a separate gate and has not been observed at report time. No UI is in scope.
