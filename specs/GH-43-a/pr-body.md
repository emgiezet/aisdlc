## GH-43-a — Link every phase to the agent session that ran it

**QA verdict: PASS** · UC coverage: 5/5 automated · Tests: selftest 163 passed · validate 53 passed · Skipped: 0

🤖 Written by an agent from `specs/GH-43-a/spec.md`. Review the spec's `Out:` scope first —
that is where an unattended run is most likely to have overstepped.

### What the spec asked for

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | queue | a claude task runs implement and qa to `done` | `task.json .sessions` has two entries, `phase` `implement` and `qa`, `runtime` `claude`, each with the `session_id` its phase json returned and ISO `started`/`ended` | selftest |
| UC-2 | queue | same, worktree at `/tmp/x.y/wt` | each `transcript` is `$HOME/.claude/projects/-tmp-x-y-wt/<session_id>.jsonl` | selftest |
| UC-3 | queue | an omp task runs one phase | one entry with `runtime` `omp`, `session_id` equal to the uuid in the file the phase wrote under `sessions/`, `transcript` that file's absolute path | selftest |
| UC-4 | queue | a task with three phases | `task.json .runtime_version` equals the first line of `<runtime> --version`; the runtime's `--version` ran once for the task | selftest |
| UC-5 | queue | a claude phase whose json has no `session_id` *(inferred negative)* | entry present with `session_id: null` and `transcript: null`; the phase's pass/fail outcome is unchanged | selftest |

### How to verify

```sh
bash evals/harness/selftest.sh        # 163 passed, 0 failed, 0 skipped
CI= make validate                     # 53 passed, 0 failed, 0 skipped
```

Full suite output: `specs/GH-43-a/qa/selftest.txt` and `specs/GH-43-a/qa/validate.txt`.

### Review here first

1. **`plugins/sdlc/bin/aisdlc:1061–1065`** — transcript path derivation for claude runtime.
   `tr '/.' '-'` encodes the worktree path into the `~/.claude/projects/` directory name.
   Only `/` and `.` are substituted; any other non-alphanumeric character in the worktree path
   (spaces, colons, underscores with different semantics) is passed through unchanged. Verify
   this matches Claude's actual project-directory encoding convention before relying on the path.

2. **`plugins/sdlc/bin/aisdlc:1037–1039`** — `runtime_version` set-once guard.
   `task_get "$repo" .runtime_version "$id"` must return an empty string (not the literal
   `null`) when the field is absent, otherwise the guard misfires and `--version` is called on
   every phase instead of once.

### Not covered

Nothing. All 5 UCs are covered by automated regression tests. No UC was verified by hand only.
