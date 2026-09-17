# Playbook — Tests and coverage

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
Load the `dense-testing` skill — it holds the density floors, the per-stack recipes, and the rules
this playbook enforces.

## Sequence

1. **Find the gap before writing anything.** Which acceptance criteria (`UC-<n>` in
   `specs/<TICKET>/spec.md`) have no test carrying their id? Which public functions in the recent
   diff have no test? That list is the work.
2. **Integration tests before unit tests.** One integration test per `UC-<n>`, named with its id,
   exercising the real path end to end. These are what catch a hallucinated implementation; unit
   tests only catch a wrong branch.
3. **Then fill the branch grid.** Every error return, validation rule, and conditional in the
   changed code gets its own case. Parameterised where the language supports it.
4. **Assert on observable behaviour** — response body, stored row, rendered text, emitted event.
   Never assert that a mock was called when the real effect is checkable.
5. **Run the full suite, not just the new file.** A new test that passes while breaking two
   existing ones is a net loss.

## Non-negotiable

- Never delete a test, mark it skipped, or loosen an assertion to make the suite green. If a test
  contradicts the spec, stop and report the contradiction — one of them is wrong, and deciding
  which is a human call, not a cleanup task.
- Never write a test that asserts current buggy behaviour just to get a green run.
- A flaky test is a defect: fix the race or the fixture, never retry around it.

On Claude and Codex, the `Stop` hook enforces the first rule and blocks a session that removed tests or added skips. On Grok, Stop is passive — the check fires as an advisory warning instead. The no-delete/no-skip invariants remain mandatory on every host.

## Verify

Run the verification block from the `.claude/rules/` file for each stack you touched. Then report
in the spec's terms:

- `UC-<n>` ids with at least one passing test, out of the total in the spec.
- Test count before and after, and the skip count — which must be zero.

## Done when

Every `UC-<n>` has a passing test carrying its id, every branch introduced by the change has a
case, nothing was skipped or weakened, and every touched stack's suite is green.
