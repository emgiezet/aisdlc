# QA report — GH-71
Verdict: PASS

Checked the draft spec against implementation head `4480d80ba5` and base `9c912df`. Verification map: none. No UI UCs.

## UC coverage

| UC | Automated boundary | Observed |
|---|---|---|
| UC-1 | `evals/harness/selftest.sh`, `GH-71 UC-1` | With both CLIs, task stores `omp`; queued line says auto-detected and no spend cap |
| UC-2 | `GH-71 UC-2` | With only Claude Code, task stores `claude` |
| UC-3 | `GH-71 UC-3` | Conflicting settings obey flag > config > environment > default; `auto` resolves at all three explicit sources |
| UC-4 | `GH-71 UC-4` | With neither CLI, `add` fails, names both options, and writes no task |
| UC-5 | `GH-71 UC-5` | Unknown runtime returns failure and does not queue a task |
| UC-6 | `GH-71 UC-6` | The worker finishes on the stored Claude runtime despite the changed environment, and runs a legacy record without `runtime` on Claude |

Coverage: 6/6 automated; no UC skipped.

## Test suites

Tiers (new tests): unit 0 / integration 5 / e2e 0. New checks exercise the real CLI plus persisted queue/worker state; the external model CLIs are the only substitutes. Existing checks were strengthened or tagged without weakening assertions.

- `make selftest`: 453 passed, 0 failed, 0 skipped; all 14 GH-71 assertions passed.
- `CI=true make validate`: passed; Slop Guard 725/0, SDLC 102/0, 25 config checks with zero skips/failures.
- `make eval-dry`: all 13 trigger sets passed. `bash -n` and ShellCheck 0.11.0 `-S warning` passed on the runner and selftest.
- Real installed CLIs, scratch repo: `aisdlc add GH-65-a --no-pr --base HEAD` printed `on omp (auto-detected), no spend cap`; explicit `--runtime claude` printed `on claude, budget $5`. Task JSON stored both concrete runtimes. Before the output fix, the omp case printed `budget $5`.

## Findings

None blocking. The queue message now distinguishes the Claude API cap from runtimes/billing where no cap is enforced; there is no change to billing enforcement.

## Not verified

- No live model phases, production credentials, or API billing were exercised. The worker regression suite uses the repository's omp and Claude subprocess stubs; the real-CLI smoke only queued tasks.
