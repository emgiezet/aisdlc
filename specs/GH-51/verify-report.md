PASS

# GH-51 verification

Coordinator verification of the integrated first wave:

- `make selftest`: 232 passed, 0 failed; real CLI runs against isolated repositories with stub model providers.
- `CI= make validate`: all checks passed.
- `bash -n` on changed shell scripts: exit 0.
- Docker `koalaman/shellcheck:stable -S warning` on the runner, selftest, stub-claude, and size-budget test: exit 0.

| Criterion | Observed evidence |
|---|---|
| UC-1 | Declared source-only branch passes; bookkeeping-only 3001-line branch still exits 1 with BLOCKED, preserving the size ceiling. |
| UC-2 | Undeclared source remains GAPS; own qa-report.md is absent from classification. |
| UC-3 | Prohibited source yields BLOCKED, task failed, and no ship phase. |
| UC-4 | Literal own spec prefix and exact root bookkeeping files are excluded; sibling/nested paths and suffix-named source remain visible; custom spec directory works. |

## Regression evidence

The first-wave regressions against unchanged production code produced 197 passed, 34 failed. Relevant report-exclusion assertions failed before the fix and passed in the integrated run. Missing-new-helper errors in that control are not treated as independent behavioral proof.

A separate 3001-line AGENTS.md-only smoke first returned PASS without a Size section; after the early-return correction the same fixture returned exit 1 and BLOCKED with size accounting.

Independent read-only code review: APPROVED after correction of reported findings.

No paid Claude/omp model evaluation was performed; runner/provider interactions were exercised through the repository stubs.
