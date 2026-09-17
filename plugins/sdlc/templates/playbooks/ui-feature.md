# Playbook — UI feature

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
The `.claude/rules/` file for the frontend attaches on its own.

## Sequence

1. **Check for a mockup.** If `specs/<TICKET>/mockup/index.html` exists, it is the visual contract
   that was approved — match its structure and copy, not your own idea of the layout. No mockup
   and the spec has UI acceptance criteria → invoke the `mockup` skill for <TICKET> and get it approved first.
2. **Reuse before building.** Grep the component library for an existing primitive. A second
   Button/Modal/Input variant is a defect, not a feature.
3. **Types from the contract.** Data shapes come from the generated client or the shared types —
   never hand-written duplicates of server types.
4. **Data access behind the project's data layer**, not inside the component. Components receive
   data or call the project's hook/store abstraction; they never call `fetch` directly.
5. **Build the component.** Loading, empty, and error states are part of the component, not a
   follow-up.
6. **Accessibility as you go.** Every interactive element reachable by keyboard and labelled —
   tests query by role, so an inaccessible component is also an untestable one.
7. **Validate at both edges**: the form input and the server response.

## Test requirements

- One test per acceptance criterion, named with its `UC-<n>` id, querying by role and asserting on
  what the user sees.
- Every state the component can render gets a case: loading, empty, error, populated, and each
  conditional branch of the UI.
- Network mocked at the boundary the project already uses — never a hand-rolled stub.
- Multi-screen flows from the spec get an end-to-end scenario; a single component does not.

See the `dense-testing` skill for the density floors.

## Verify

Run the verification block from the frontend rules file: lint, types, tests. Add:

- A production build — a type-clean component can still break the bundle.
- The end-to-end scenarios, if the flow warranted one.

## Done when

Mockup matched where one exists, no duplicated primitive or server type, every acceptance
criterion has a passing test with its `UC-<n>` id, every render state covered, and lint, types,
tests and build are green.
