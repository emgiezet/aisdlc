PASS

# GH-54 verification

Coordinator verification of the integrated first wave:

- `make selftest`: 232 passed, 0 failed; real CLI runs against isolated repositories with stub model providers.
- `CI= make validate`: all checks passed.
- `bash -n` on changed shell scripts: exit 0.
- Docker `koalaman/shellcheck:stable -S warning` on the runner, selftest, stub-claude, and size-budget test: exit 0.

| Criterion | Observed evidence |
|---|---|
| UC-1 | Exact In entry overrides the same spec Out cross-reference and yields PASS. |
| UC-2 | Directory In entry cannot exempt a prohibited file. |
| UC-3 | Overlapping *, ?, and bracket patterns cannot exempt their matched file from spec Out. |
| UC-4 | Repository prohibition still marks an exact-In file out of bounds. |
| UC-5 | Context-only mention does not exempt a file from spec Out. |
| UC-6 | Exact-In exemption plus an undeclared source file yields GAPS and continues. |

## Regression evidence

The first-wave regressions against unchanged production code produced 197 passed, 34 failed. Relevant exact-In precedence assertions failed before the fix and passed in the integrated run. Missing-new-helper errors in that control are not treated as independent behavioral proof.

Independent read-only code review: APPROVED after correction of reported findings.

No paid Claude/omp model evaluation was performed; runner/provider interactions were exercised through the repository stubs.
