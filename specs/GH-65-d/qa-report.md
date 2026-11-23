Verdict: PASS
# QA report — GH-65-d

Fresh independent QA of implementation/spec head `74fba77546f6ab1ded4e668fc35fbe2fbf6e910b` against the PR's current base `origin/fix/gh65-3-ruby`. Spec was read before implementation/tests; required observations are recorded in `qa/budget-refresh/expectations.txt`.

## UC coverage

| UC | Required observable | Automated test | Evidence | Verified |
|---|---|---|---|---|
| UC-9 | Each named JVM/Go/Node ID detects its own matching bad AP fixture in a copied full-tree scan | `plugins/slop-guard/tests/integration/opengrep.sh:103-110`, four `GH-65-d UC-9` assertions | `qa/budget-refresh/tool-integration-corrected.log:81-87` | Yes, four passing assertions |
| UC-10 | Four IDs silent across every good directory, including both XML locations; earlier C#/Rust/Ruby contracts still pass | `plugins/slop-guard/tests/integration/opengrep.sh:111-118`, four `GH-65-d UC-10` assertions plus previous-slice contracts | `qa/budget-refresh/tool-integration-corrected.log:49-88` | Yes, four passing assertions and all earlier contracts |

Covered: 2/2 UCs automated · 0 manual-only · 0 failing · 0 skipped.

Independent full-rules copied-tree scan using pinned OpenGrep **1.30.0** and `--disable-nosem` exited 0 with `errors: []`. Target-rule findings: Go 12, Jackson 1, XML 2, Node 9; zero target findings under any good directory. Filtered actual locations, scanner stderr and version are in `qa/budget-refresh/runtime-results.json`, `runtime-scan.stderr` and `opengrep-version.txt`. Java good samples use explicit named-subtype allowlisting and disabled StAX external entities/DTD; bad samples remain insecure. No suppression annotation was used. The shared gate rejects failed scans, malformed/missing results and scanner errors.

verification map: none
browser: none — no UI UCs.

## Change budget

The owner-approved `spec.md:27` budget is **340 added lines / 13 files / 2 modules**. Current-base measurement:

```sh
git diff --numstat origin/fix/gh65-3-ruby...HEAD -- . ':!specs'
```

Actual: **337 added, 18 deleted, 13 non-spec files, 1 module (`plugins/slop-guard`)**. All three limits pass. Full numstat and revision are preserved in `qa/budget-refresh/`. This supersedes the previous 337-versus-300 minor finding; the implementation was not changed.

## Test suites

Tiers (new tests): unit 0 / integration 0 / e2e 0

No test gaps required Phase-2 additions. Existing eight UC assertions exercise the real parser/scanner integration, the lowest tier capable of proving the fixture/rule contract; no redundant unit or e2e cases were added.

Final verification environment: `CLAUDE_PLUGIN_DATA=/home/mgz/.local/share/claude/plugins/slop-guard`; PHP via existing `/tmp/slopguard-tool-bumps-2026-11/bin/php` Docker launcher. `CI= make validate` used ordinary PATH plus that launcher and pinned ShellCheck; config/integration commands additionally used managed tool `current` directories on PATH and `CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=plugin-only`.

| Exact command | Actual final result | Skips | Evidence under `qa/budget-refresh/` |
|---|---|---|---|
| `bash -n plugins/slop-guard/tests/integration/opengrep.sh` | exit 0 | 0 | `bash-syntax.log` |
| `shellcheck -S warning plugins/slop-guard/tests/integration/opengrep.sh` | exit 0, no diagnostics | 0 | `shellcheck.log` |
| `plugins/slop-guard/scripts/gen-skills --check` | exit 0; output is deterministic | 0 | `gen-skills.log` |
| `plugins/slop-guard/scripts/validate-configs` | exit 0; **25 validated, 0 skipped, 0 failed** | 0 | `validate-configs-corrected.log` |
| `bash plugins/slop-guard/tests/catalog_test.sh` | exit 0; **26 passed, 0 failed** | 0 | `catalog.log` |
| `CI= make validate` | exit 0; slop-guard **725 passed, 0 failed**; configs **25 validated, 0 skipped, 0 failed**; SDLC **102 passed, 0 failed**; All checks passed | 0 | `validate-corrected.log` |
| `make selftest` | exit 0; **436 passed, 0 failed** | 0 | `selftest.log` |
| `SLOPGUARD_IT_REQUIRE=1 make tool-integration` | exit 0; **83 passed, 0 failed, 0 skipped, 2 known** | 0 | `tool-integration-corrected.log` |

Tests before → after QA: slop-guard **725 → 725**, SDLC **102 → 102**, catalogue **26 → 26**, selftest **436 → 436**, real-tool integration **83 → 83**. No tests added, deleted, weakened or newly skipped.

Initial matrix failures are preserved, not hidden: the obsolete `/home/mgz/.local/share/slop-guard` cache lacked anti-slop and PHP tools; exporting every managed binary on PATH also defeated unit tests' deliberately missing-tool environment. Investigation identified missing `@spacemansh/anti-slop`, absent PHP tool directories, and missing-tool assertions finding globally exported tools. The corrected run selected the complete existing cache and isolated the unit-suite PATH, without repository edits. All affected commands then passed; initial logs remain alongside corrected logs.

## Findings

None. **0 findings, 0 blocking.**

## Not verified

- The pre-existing quarantined zizmor unsafe-checkout and Psalm TaintedSql cases remain known failures, not passing assertions (`qa/budget-refresh/tool-integration-corrected.log:12,91`; `plugins/slop-guard/tests/integration/KNOWN-FAILING:14,21`). Neither exercises UC-9/UC-10; no quarantine was changed.
- No ticket UC remains unverified. All touched-stack verification commands completed successfully with zero skips after the environment correction. Paid model-driven e2e evaluation was not run; it is outside these UCs and requires human authorization.
- No implementation/spec file, tool pin, generated skill, CI configuration or version field was modified during QA.
