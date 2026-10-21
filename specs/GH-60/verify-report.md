PASS

# GH-60 verification

Coordinator verification of the integrated first wave:

- `make selftest`: 232 passed, 0 failed; real CLI runs against isolated repositories with stub model providers.
- `CI= make validate`: all checks passed.
- `bash -n` on changed shell scripts: exit 0.
- Docker `koalaman/shellcheck:stable -S warning` on the runner, selftest, stub-claude, and size-budget test: exit 0.

| Criterion | Observed evidence |
|---|---|
| UC-1 | Retained local-tracker worktree contains a symlink resolving to the canonical repo tracker. |
| UC-2 | Stub ship writes cwd-relative tracker state and real inbox output lists local#1. |
| UC-3 | PR record JSON remains identical after actual clean removes the worktree. |
| UC-4 | Missing canonical tracker directory is created and linked. |
| UC-5 | Forced symlink failure fails the task, retains its worktree, and starts no model phase. |
| UC-6 | GitHub tracker worktree receives no local tracker directory or symlink. |

## Regression evidence

The first-wave regressions against unchanged production code produced 197 passed, 34 failed. Relevant symlink/persistence/failure-lifecycle assertions failed before the fix and passed in the integrated run. Missing-new-helper errors in that control are not treated as independent behavioral proof.

Independent read-only code review: APPROVED after correction of reported findings.

No paid Claude/omp model evaluation was performed; runner/provider interactions were exercised through the repository stubs.
