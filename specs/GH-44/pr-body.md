## GH-44 — scope-check reports structural erosion on changed files (SlopCodeBench metric)
**QA verdict: PASS** · UC coverage: 7/8 automated · 1 static instruction-file check · Tests: 75 (run-tests) + 163 (selftest) · Skipped: 0

> **Post-review fixes (since original QA):**
> - Unparseable-but-zero-exit lizard output → `skipped: lizard failed` (was unhandled)
> - Real header-less CSV format acceptance test added (`structure_test.sh`)
> - `_budget_profile_float` profile float-parser tests added
> - Budget updated to 860 lines to include the review-requested tests (839 measured at HEAD)

🤖 Written by an agent from `specs/GH-44/spec.md`. Review the spec's `Out:` scope first —
that is where an unattended run is most likely to have overstepped.

### What the spec asked for

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | queue | scope-check on a branch that raises one Go function from CC 8 to CC 14, default profile | `## Structure` lists that function with `8 -> 14` and its SLOC, names it as the largest CC increase, has a `new hotspot` finding; verdict `GAPS` | selftest |
| UC-2 | queue | scope-check computes erosion from a captured lizard CSV with known CC/NLOC values | before and after erosion equal the formula's value to 2 decimals; a rise above 0.05 yields one `erosion` finding naming both values | unit |
| UC-3 | queue | scope-check when lizard is not on `PATH` and a `.go` file changed | `## Structure` says `skipped: lizard not installed`; no structure finding; phase returns 0 | selftest |
| UC-4 | queue | scope-check on a change that touches only `.md` files | no `## Structure` section in `scope-report.md` | selftest |
| UC-5 | queue | a function absent at the merge base appears with CC 27 | one `hotspot over 25` finding and one `new hotspot` finding for it | unit |
| UC-6 | queue | a function at CC 30 before and CC 30 after, nothing else over 10 | no `new hotspot` or `hotspot over 25` finding | unit |
| UC-7 | queue | profile sets `Erosion delta max: 0.5` and `New hotspots max: 1`; one function goes 8 -> 14 | no structure finding; the section still lists the function | unit |
| UC-8 | reviewer agent | `/sdlc:review` on a PR whose `scope-report.md` has `new hotspot` and `hotspot over 25` findings | review output has `[major]` for the first and `[blocker]` for the second, each naming split-the-function or `/sdlc:decompose` | live run (sandbox) |

### How to verify

```sh
bash plugins/sdlc/tests/structure_test.sh   # 22 passed, 0 failed
bash plugins/sdlc/tests/run-tests           # 75 passed, 0 failed (includes structure suite)
AISDLC_HEADLESS=1 make selftest             # 163 passed, 0 failed
```

Verify report: `specs/GH-44/verify-report.md` — all checks PASS.

### Review here first

- `plugins/sdlc/bin/aisdlc:1452` — `_struct_text`: erosion formula (`mass = CC * sqrt(NLOC)`), hotspot threshold logic, finding text generation; regressions here affect all verdict output
- `plugins/sdlc/bin/aisdlc:1577` — `run_scope_check`: integration of `_struct_run_lizard` into the scope-check phase; verdict assembly (`PASS` → `GAPS` on any structure finding, never `BLOCKED`)
- `plugins/sdlc/commands/review.md:104` — new import rules mapping `new hotspot` → `[major]` and `hotspot over 25` → `[blocker]`; wrong severity here affects every future reviewer agent run

### Not covered

- **UC-8 live run**: sandbox not available; instruction-file content confirmed correct by static assertions in `selftest.sh` lines 793–807 (non-blocking — instruction-file UC with asserted rule text)
- **"lizard runs at most twice" (non-functional)**: code inspection only; no test asserts the call count
- **Finding text is ASCII (`->` not `→`)**: code inspection only; no dedicated test asserts the character

Closes #44
