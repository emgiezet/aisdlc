# Playbook — Tests and coverage

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.

## Sequence

1. **Find the gap first.** Which `UC-<n>` ids from `specs/<TICKET>/spec.md` have no test
   carrying their id? Which exported functions in the recent diff have no test? That is the work.
2. **Integration-level tests before unit tests.** For the service that means a test through
   `Routes()` with `httptest`; for the frontend, the exported function with real inputs.
3. **Then fill the branch grid** — one case per error return, per validation rule, per
   conditional. Table-driven in Go.
4. **Assert on observable output** — status code, decoded body, returned string. Never on
   internal state.

## Non-negotiable

- Never delete a test, skip it (`t.Skip`, `test.skip`), or loosen an assertion to get green.
- Never assert current buggy behaviour to make a run pass.
- A test contradicting the spec is a contradiction to report, not a test to remove. In an
  unattended run: write `specs/<TICKET>/BLOCKED.md` and exit non-zero.

## Verify

`make verify`. Then report: UC ids with a passing test out of total UC ids, test count before
and after, and the skip count (which must be zero).

## Done when

Every UC has a passing test carrying its id, every branch in the change has a case, nothing was
skipped or weakened, and `make verify` is green.
