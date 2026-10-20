verdict: GAPS (3 findings, 1 blocking)

# QA Report — GH-44

Ticket: GH-44 — scope-check reports structural erosion on changed files (SlopCodeBench metric)
Branch: ai/GH-44-structure-erosion-check
Diff base: 7b84f469b4eaf22151f29ec27fabeaec75ef4e6c
verification map: none

---

## UC × Test Coverage

| UC | Description | Test(s) | Result | Notes |
|----|-------------|---------|--------|-------|
| UC-1 | `## Structure` lists function with `8 -> 14` and its SLOC, names largest CC increase, `new hotspot` finding, verdict `GAPS` | selftest.sh:667–680 (5 assertions); structure_test.sh:185–191 (SLOC unit, gap-added) | ✅ pass | SLOC assertion added in this QA run; selftest verifies CC change, finding, verdict |
| UC-2 | Before/after erosion matches formula to 2 decimals; rise > 0.05 → one `erosion` finding naming both values | structure_test.sh:58–71 | ✅ pass | |
| UC-3 | `## Structure` says `skipped: lizard not installed`; no finding; phase returns 0 | selftest.sh:703–715; structure_test.sh:194–207 (body-format unit, gap-added) | ❌ **FAIL** | Implementation writes `not installed`; spec requires `skipped: lizard not installed`. Unit test added in this run confirms the bug. |
| UC-4 | Only `.md` files changed → no `## Structure` section | selftest.sh:731–733 | ✅ pass | |
| UC-5 | New function at CC 27 → `hotspot over 25` + `new hotspot` findings | structure_test.sh:89–105 | ✅ pass | |
| UC-6 | CC 30 stable → no `new hotspot` or `hotspot over 25` finding | structure_test.sh:122–134 | ✅ pass | |
| UC-7 | Relaxed profile (0.5 / 1) suppresses findings; section still lists function | structure_test.sh:165–182 | ✅ pass (partial) | Threshold values tested inline; `_budget_profile_float` profile-file parser not exercised |
| UC-8 | `/sdlc:review` → `[major]` for `new hotspot`, `[blocker]` for `hotspot over 25`, each naming split/`/sdlc:decompose` | selftest.sh:739–750 (instruction-file keyword check) | ⚠️ partial | Instruction-file content correct; no live model run; remedy text not asserted |

Automated: 6/8 · Partial: 2/8 · Failing: 1/8

---

## Test Suite Output

### plugins/sdlc/tests/run-tests (after gap tests added)

```
sdlc hook test suite
  ok    PreToolUse (Grok): force-push camelCase payload blocked with {decision:deny}
  ok    PreToolUse (Claude): force-push blocked with exit 2 and reason on stderr
  ok    PreToolUse (Grok): safe command allows silently (exit 0, no stdout)
  ok    PreToolUse (Claude): safe command allows silently (exit 0, no stdout)
  ok    Stop (Grok): deleted test file → advisory on stderr, exits 0, no block
  ok    Stop (Claude): deleted test file → blocks with exit 2 and reason on stderr
  ok    SessionStart (Grok): registered command resolves via GROK_PLUGIN_ROOT, exits 0
  ok    hooks.json: all referenced hook files exist and are executable
  ok    stop: deletion listed with a reason passes and is reported as retired
  ok    stop: ledger entry without a reason does not retire the test
  ok    stop: glob entry retires every matching deletion; comment lines ignored
  ok    stop: only unlisted deletions are reported
  ok    stop (headless): a ledger entry written during the run is ignored
  ok    stop (headless): a ledger entry committed on the default branch retires the test
  ok    stop: SystemExit( in a test and a skip marker outside test files are not flagged
  ok    stop: xit( added to a test file is flagged
  ok    stop: the ledger does not excuse a skipped test
  ok    omp adapter: destructive bash (git push --force) is blocked with guard message
  ok    omp adapter: benign bash command is allowed
  ok    omp adapter: write tool with t.Skip content is allowed (no write binding in hooks.json)
  ok    omp adapter: missing hook script allows (fail-open) and decision is null
  ok    omp adapter: unknown tool (read) spawns nothing and returns undefined
  ok    omp adapter: turn_end sends an unchanged stop advisory once, and again after a clean turn
change budget
  ok    size: added lines count code only (30+5+7)
  ok    size: files touched include the emptied file, exclude vendor/lock/specs
  ok    size: module = first two path segments
  ok    size: module list names the real directories
  ok    size: vendored and spec paths never reach the module list
  ok    eval: exactly at budget is clean
  ok    eval: one line over budget is GAPS
  ok    eval: past the hard ceiling is BLOCKED
  ok    eval: thin edits across many modules are named as shotgun surgery
  ok    eval: a focused change produces no findings
  ok    eval: a large change inside two modules is over budget but not shotgun surgery
  ok    budget: the spec's own budget wins
  ok    budget: the profile answers when the spec is silent
  ok    budget: the built-in default is the last resort
  ok    budget: the repo may lower its own hard ceiling
verify: test file detection
  ok    test path: evals/harness/selftest.sh
  ok    test path: selftest.sh
  ok    test path: scripts/deploy_test.sh
  ok    test path: lib/test_parse.sh
  ok    test path: hooks/guard.bats
  ok    test path: plugins/x/tests/run-tests
  ok    test path: pkg/stub_test.go
  ok    test path: src/a.test.ts
  ok    test path: app/test_api.py
  ok    source path: evals/harness/run.sh
  ok    source path: scripts/latest.sh
  ok    source path: lib/contest.sh
  ok    source path: plugins/sdlc/bin/aisdlc
  ok    source path: src/testing.ts
  ok    source path: docs/test-plan.md
structure
  ok    UC-2: before erosion equals 0.00 (formula)
  ok    UC-2: after erosion equals 0.78 (formula)
  ok    UC-2: erosion finding names before (0.00) and after (0.78)
  ok    UC-5: new_hotspot record for CC-27 function absent before
  ok    UC-5: hotspot25 record for CC-27 function
  ok    UC-5: new hotspot finding emitted
  ok    UC-5: hotspot over 25 finding emitted
  ok    UC-6: no new_hotspot for function already at CC 30
  ok    UC-6: no hotspot25 for function already above CC 25
  ok    UC-6: no structure findings for stable CC 30 function
  ok    UC-7 baseline: findings present with default thresholds
  ok    UC-7: no finding with relaxed thresholds (0.5 / 1)
  ok    UC-7: section lists GoFunc with CC 8 -> 14 despite no findings
  ok    UC-1 SLOC: hotspot table includes SLOC value (100)
  FAIL  UC-3 unit: skip body format: expected 'skipped: lizard not installed', got: 'not installed' (implementation bug: _struct_run_lizard must emit 'skip:skipped: lizard not installed')

67 passed, 1 failed
```

Skipped: 0

---

## Findings

### [1] [blocking] UC-3: skip section body is `not installed`, spec requires `skipped: lizard not installed`

**File:** `plugins/sdlc/bin/aisdlc:1530`  
**Test:** `plugins/sdlc/tests/structure_test.sh:194–207` (added this run, failing)

`_struct_run_lizard` emits `skip:not installed` when lizard is absent from `PATH`. The `run_scope_check` handler at aisdlc:1706 strips the `skip:` prefix (`struct_body="${struct_result#skip:}"`) → body becomes `not installed`. `_write_structure_section` writes that verbatim, so `scope-report.md` contains the string `not installed` rather than the spec-required `skipped: lizard not installed`.

The selftest assertion at selftest.sh:706 (`grep -qF 'not installed'`) is satisfied by both strings and masked the discrepancy.

**Fix:** change aisdlc:1530 to `printf 'skip:skipped: lizard not installed'`.

---

### [2] [minor] Non-functional: `lizard failed` paths also missing `skipped:` prefix and exit code

**File:** `plugins/sdlc/bin/aisdlc:1552, 1561`

Both lizard-non-zero-exit cases emit `skip:lizard failed`. After prefix-stripping, the section body becomes `lizard failed`, not `skipped: lizard failed` with an exit code, as the non-functional requirement specifies. No test exercises either path.

---

### [3] [minor] UC-7: `_budget_profile_float` profile-file parser not exercised by any test

**File:** `plugins/sdlc/bin/aisdlc` (`_budget_profile_float`)  
**Test:** `plugins/sdlc/tests/structure_test.sh:172`

`structure_test.sh` passes threshold values `"0.5"` and `"1"` directly to `_struct_text`, bypassing the awk parser that reads `Erosion delta max:` from an `sdlc.md` profile. A regression in the parser would not be caught.

---

### [4] [minor] UC-8: remedy text not asserted; no live model run possible

**File:** `evals/harness/selftest.sh:739–750`

The selftest checks four keywords in `review.md` but does not assert the remedy phrase "split the function or run /sdlc:decompose". Spec marks UC-8 as "live run (sandbox)"; no sandbox was available. The instruction-file content is correct (verified by grep at `plugins/sdlc/commands/review.md:104–106`).

---

## Not Verified

- **UC-8 live run**: sandbox not available. Model output not observed. Instruction-file content confirmed correct; severity labels `[major]` and `[blocker]` present.
- **"lizard runs at most twice" (non-functional)**: code inspection only — `_struct_run_lizard` has exactly one before-pass call (aisdlc:1550) and one after-pass call (aisdlc:1559); no test asserts the count.
- **Unparseable-but-zero-exit lizard output (non-functional)**: not detected by the implementation; no test covers this path.
