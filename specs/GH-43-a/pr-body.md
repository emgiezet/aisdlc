## GH-43-a — task.json records each phase's agent session — id, runtime, transcript path, runtime version
**QA verdict: PASS** · UC coverage: 5/5 automated · Tests: 163 passed · Skipped: 0

🤖 Written by an agent from `specs/GH-43-a/spec.md`. Review the spec's `Out:` scope first —
that is where an unattended run is most likely to have overstepped.

Part of #43

### What the spec asked for

| id | action | expected observable result |
|----|--------|----------------------------|
| UC-1 | claude task runs implement and qa to `done` | `task.json .sessions` has two entries, `phase` implement and qa, `runtime` claude, each with the `session_id` its phase json returned and ISO `started`/`ended` |
| UC-2 | same, worktree at `/tmp/x.y/wt` | each `transcript` is `$HOME/.claude/projects/-tmp-x-y-wt/<session_id>.jsonl` |
| UC-3 | omp task runs one phase | one entry with `runtime` omp, `session_id` equal to uuid in file written under `sessions/`, `transcript` that file's absolute path |
| UC-4 | task with three phases | `task.json .runtime_version` equals first line of `<runtime> --version`; `--version` ran once per task |
| UC-5 | claude phase whose json has no `session_id` | entry present with `session_id: null` and `transcript: null`; phase outcome unchanged |

### How to verify

```
make selftest        # selftest.sh — 163 tests, 0 failures
CI= make validate    # full validate — 53 tests, 0 failures
```

Scope: PASS (scope-report.md)
Verify: PASS (verify-report.md — `CI= make validate` exit 0, `make selftest` exit 0, UC coverage 5/5, no tests weakened)

### Review here first

- `plugins/sdlc/bin/aisdlc` — `run_phase`: appends session object to `task.json .sessions` after every runtime-invoking phase; session_id sourced from `<phase>.json .session_id`
- `plugins/sdlc/bin/aisdlc` — `invoke_omp`: passes `--session-dir` and records the omp session uuid from the resulting `.jsonl` filename
- `evals/harness/stub-claude` / `stub-omp`: return per-phase `session_id` / write `<ts>_<uuid>.jsonl` so all 5 UC tests can run without the real runtimes

### Not covered

Nothing. All 5 UCs are covered by automated regression tests.
