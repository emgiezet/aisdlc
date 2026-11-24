Verdict: PASS
# QA report — GH-65-e

## UC coverage
| UC | Requirement | Passing automated evidence | Verified |
|---|---|---|---|
| UC-11 | Three React/Laravel IDs hit their own bad AP fixture | `tests/integration/opengrep.sh:125–146`: 3 real-binary assertions | automated |
| UC-12 | Those IDs have zero findings anywhere under good/ | 3 named UC-12 assertions, including sanitized React href/src | automated |
| UC-13 | Every exact rule ID hits its metadata-bound bad AP; missing hits name the rule | 56 own-AP and 13 adversarial-variant assertions; `qa/gate_test.py` covers missing/wrong IDs, new-rule discovery, scan failure, invalid JSON and offline behavior | automated |
| UC-14 | Every configured ID has zero good-tree findings | 56 named assertions; `qa/gate_test.py` rejects a good hit outside the rule's own AP pair | automated |

Covered: 4/4 UCs automated · 0 manual · 0 failing · 0 skipped.
Pinned OpenGrep reports 1.30.0. The real integration suite scans copied fixtures with the full rule directory and exact IDs, retaining all earlier language-group assertions.

verification map: none
browser: none — no UI UCs.

## Change budget
After `git fetch origin`, current PR base is `fix/gh65-4-runtime` (including owner commit `74fba77`).
`git diff --numstat origin/fix/gh65-4-runtime...HEAD -- . ':!specs'` measures **361 added lines, 41 deleted lines, 10 files, 1 module** (`plugins/slop-guard`; first-two-segment convention in `plugins/sdlc/bin/aisdlc:1434–1455`).
Approved `spec.md:28`: **365 added lines, 11 files, 2 modules**. All dimensions comply; the former budget finding is resolved by the owner's approval, not a code exemption. Per-file evidence: `qa/fresh/budget.txt`.

## Test suites
Tiers (new tests this rerun): unit 0 / integration 0 / e2e 0.
The existing QA gate suite has 8 unit tests; all were rerun without modification. Tests before → after: unchanged (725 slopguard + 102 sdlc + 436 selftest + 26 catalogue + 214 integration + 8 gate).

Environment: `CLAUDE_PLUGIN_DATA=$HOME/.local/share/claude/plugins/slop-guard`, `CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=plugin-only`; corrected runs prepend `$PWD/specs/GH-65-e/qa/bin` and the pinned shellcheck directory to PATH. The committed PHP launcher uses local Docker image `aisdlc-tool-bumps-php:8.3` because the host has no PHP; it forwards cache variables and host paths. `slopguard doctor --install --all` completed with every tool present and version-matched (`qa/fresh/doctor.log`).

| Exact command | Real result | Skips |
|---|---|---|
| `bash -n plugins/slop-guard/tests/integration/opengrep.sh plugins/slop-guard/tests/opengrep_test.sh` | exit 0 | 0 |
| `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -S warning plugins/slop-guard/tests/integration/opengrep.sh plugins/slop-guard/tests/opengrep_test.sh` | exit 0, no diagnostics | 0 |
| `TMPDIR=$HOME/.cache/pr83-qa-tmp CI= make validate` | exit 0; 725 slopguard + 102 sdlc passed, 0 failed; 25 configs validated; All checks passed | 0 |
| `make selftest` | exit 0; 436 passed, 0 failed | 0 |
| `bash plugins/slop-guard/tests/catalog_test.sh` | exit 0; 26 passed, 0 failed | 0 |
| `plugins/slop-guard/scripts/gen-skills --check` | exit 0, deterministic | 0 |
| `plugins/slop-guard/scripts/validate-configs` | exit 0; 25 validated, 0 failed | 0 |
| `SLOPGUARD_IT_REQUIRE=1 make tool-integration` | exit 0; 214 passed, 0 failed, 2 pre-existing known cases | 0 |
| `python3 specs/GH-65-e/qa/gate_test.py` | exit 0; Ran 8 tests, OK | 0 |

Exact full output is committed under `qa/fresh/`; `validate-isolated.log`, `configs-php.log`, and `integration-php.log` are the final corrected runs. Initial no-PHP runs recorded two missing-tool skips (integration exit 2). The first corrected validation encountered `/tmp` quota exhaustion during the unchanged concurrent state test (`jq: error: writing output failed: Disk quota exceeded`; 724 passed, 1 failed). Moving only TMPDIR to the home filesystem yielded 725/725, zero skips, with no test or implementation changes. All attempts remain in evidence; no failure was suppressed or assertion weakened.

## Findings
None. Zero blocking findings.

## Not verified
- The pre-existing quarantined zizmor checkout and Psalm TaintedSql cases remain `known`, not passing; no quarantine or test was altered. Neither is a GH-65-e UC.
- Hosted CI for this new evidence commit has not yet completed. No claim is made that local verification substitutes for the merge gate's CI check.
