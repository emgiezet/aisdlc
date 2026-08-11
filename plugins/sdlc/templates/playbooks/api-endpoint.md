# Playbook — API endpoint

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
The `.claude/rules/` file for the paths you edit attaches on its own — do not open it from here.

## Sequence

1. **Contract first.** <If this project has a contract directory: find or add the operation
   there — request schema, response schemas, every error status — and change it in the same
   commit as the code, never after. If it does not, delete this step rather than inventing a
   contract format.>
2. **Locate the seam.** Grep for the nearest sibling endpoint and copy its structure. Prefer an
   existing module over a new one; a new one needs a reason you can state.
3. **Write the test first.** One test per acceptance criterion, named with its `UC-<n>` id when
   working from a spec. Minimum per endpoint: happy path, input validation rejection,
   authorization denial, not-found. Run it and confirm it fails on the assertion — a compile
   error is not a red test.
4. **Implement thin.** <The layering this project uses: what validates, what holds the business
   rules, what shapes the response. Name the directories.> The transport layer holds no business
   logic.
5. **Wire authorization explicitly.** Every endpoint states who may call it. An endpoint with no
   authorization decision is a defect, even when the answer is "any authenticated caller".
6. **Error shape.** Reuse the existing error envelope. Never leak internal messages, queries, or
   stack traces to the caller.
7. **Regenerate downstream artefacts** — typed clients, fixtures, documentation — in the same
   commit.

## Test requirements

Beyond the four cases in step 3, add a case for every branch you introduce: each validation rule,
each error return, each conditional on the request. Integration tests exercise the full
request→response cycle against a real datastore; unit tests cover the business layer in
isolation. See the `dense-testing` skill for the density floors.

## Verify

Run the verification block from the `.claude/rules/` file for the stack you touched, in order:
lint, then types or static analysis, then tests. Add:

- <the contract check, if this project has contracts — e.g. the response validates against the
  schema, and the contract file shows up in `git diff`>

## Done when

Every acceptance criterion has a passing test carrying its `UC-<n>` id, authorization is
explicit, the error shape matches its neighbours, and the stack's verification commands are green.
