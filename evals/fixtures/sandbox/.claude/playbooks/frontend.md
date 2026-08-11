# Playbook — Frontend formatting

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
`.claude/rules/javascript.md` attaches automatically under `frontend/**`.

## Sequence

1. **Check for an existing helper.** `frontend/src/format.mjs` already handles account ids and
   balances. Extend it rather than adding a second module for the same concern.
2. **Write the test first** in the matching `<name>.test.mjs`, one `test()` per use case, named
   with its `UC-<n>` id. Confirm it fails before implementing.
3. **Implement the pure function.** Named export, JSDoc, integer minor units in, string out.
4. **Cover the rejection paths** — every invalid input the spec names throws an `Error` whose
   message identifies the value.

## Test requirements

One `test()` per UC plus one per rejection path. Assert exact output strings, not substrings —
formatting is the behaviour under test.

## Verify

`make verify`, or `cd frontend && npm run lint && npm test` while iterating.

## Done when

Every UC has a passing test carrying its id, every rejection path is covered, no new
dependency was added, and `make verify` is green.
