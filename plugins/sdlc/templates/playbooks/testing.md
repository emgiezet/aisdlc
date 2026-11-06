# Playbook — Tests and coverage

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
Load the `dense-testing` skill — it holds the density floors, the per-stack recipes, and the rules
this playbook enforces.

## Sequence

1. **Find the gap before writing anything.** Which acceptance criteria (`UC-<n>` in
   `specs/<TICKET>/spec.md`) have no test carrying their id? Which public functions in the recent
   diff have no test? That list is the work.
2. **One test per `UC-<n>`, at the tier the spec's `test` column names**, carrying its id.
   `unit` is the default: in-process, mocked collaborators, no socket and no database.
   `integration` only where a persisted row, migration or transaction boundary is the result
   being proven; `e2e` only for a critical journey. Tier definitions and the CI stage each one
   runs at: `dense-testing`'s `references/test-tiers.md`.
3. **Then fill the branch grid at the unit tier.** Every error return, validation rule and
   conditional in the changed code gets its own case, parameterised where the language supports
   it. This is where most of the test count comes from.
4. **Prove each behaviour once.** A rule pinned by a unit test is not re-asserted by an
   integration or e2e test — duplicated assertions are paid for on every CI run.
5. **Assert on observable behaviour** — response body, stored row, rendered text, emitted event.
   Never assert that a mock was called when the real effect is checkable.
6. **Run each selected suite, not just the new file.** A new test that passes while breaking two
   existing ones is a net loss.

## Non-negotiable

- Never delete a test, mark it skipped, or loosen an assertion to make the suite green. If a test
  contradicts the spec, stop and report the contradiction — one of them is wrong, and deciding
  which is a human call, not a cleanup task.
- Never write a test that asserts current buggy behaviour just to get a green run.
- A flaky test is a defect: fix the race or the fixture, never retry around it.

The `Stop` hook enforces the first rule automatically and will block a session that removed tests
or added skips.

## Verify

Run the verification block from the `.claude/rules/` file for each stack you touched. Then report
in the spec's terms:

- `UC-<n>` ids with at least one passing test, out of the total in the spec.
- Test count before and after, and the skip count — which must be zero.
- New tests per tier: `unit` / `integration` / `e2e` — new unit tests outnumber the other two
  combined, or say why they do not.

## Done when

Every `UC-<n>` has a passing test carrying its id, every branch introduced by the change has a
case, nothing was skipped or weakened, and every touched stack's suite is green.
