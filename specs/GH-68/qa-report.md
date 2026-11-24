# QA report — GH-68
Verdict: PASS

Checked draft `spec.md` against implementation head `b25c9c9602` and base `9c912df`. Verification map: none. No UI UCs.

## UC coverage

| UC | Automated boundary | Observed |
|---|---|---|
| UC-1 | `tests/catalog_test.sh`, `GH-68 UC-1`, runs the real generator in a clean directory and parses its frontmatter | 13 skills, 0 failures; `agent-discipline` present |
| UC-2 | `tests/catalog_test.sh`, `GH-68 UC-2`, parses shipped frontmatter | 15 skills, 0 failures; omp RPC also exposed all 15 shipped names |
| UC-3 | `tests/catalog_test.sh`, `GH-68 UC-3`, injects `context: fork` into an otherwise valid skill in a temporary package | Nonzero exit; diagnostic names `shipped/nonportable` and `context` |
| UC-4 | `tests/catalog_test.sh`, `GH-68 UC-4`, hashes skill files before and after regeneration | Identical; `gen-skills --check` also passed |

Coverage: 4/4 automated; no UC skipped.

## Test suites

Tiers (new tests): unit 0 / integration 1 / e2e 0. The added rejection case runs the evaluator and real generator; a unit mock would not test the package boundary. Existing positive checks were mapped to UC IDs.

- `python3 plugins/slop-guard/evals/skill-frontmatter.py`: 13 generated and 15 shipped, zero failures.
- `bash plugins/slop-guard/tests/catalog_test.sh`: 27 passed, 0 failed (previous PR head: 25, with one combined generated/shipped assertion and no injected invalid skill).
- `plugins/slop-guard/scripts/gen-skills --check`: deterministic. `bash -n` and ShellCheck 0.11.0 `-S warning` on the generator and catalogue test passed.
- `CI=true make validate`: passed; Slop Guard 725/0, SDLC 102/0, 25 config checks, zero skips/failures.
- `SLOPGUARD_IT_REQUIRE=1 SLOPGUARD_IT_DEBUG=1 make tool-integration`: 56 passed, 0 failed, 0 skipped, 2 known.
- Local omp `--mode rpc --no-session --no-extensions --no-context-files --plugin-dir`: the `available_commands_update` event exposed the exact 15 skill names from the shipped package, including `agent-discipline`, `deslop` and `secure-review`. No model call.

## Findings

None blocking. The portability tradeoff is deliberate: shared metadata no longer forces glob activation or host-native forks; the descriptions and agent instructions carry discovery and delegation.

## Not verified

- Live model invocation and agent delegation on Claude Code or omp were not driven; omp discovery, not model behavior, was exercised.
- The two existing real-tool quarantines (zizmor bad checkout and Psalm taint) remain known, not passing. Neither covers this spec.
