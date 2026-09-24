# Playbook — GraphQL API

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
The `.claude/rules/` file for the paths you edit attaches on its own — do not open it from here.

## Sequence

1. **Schema first.** Load the `graphql-api-design` skill and add the type, field or mutation to
   <the schema file or the code-first type definitions this project uses> in the same commit as
   the resolver. It decides three things before any code: nullability (owned scalars non-null,
   anything across a service boundary nullable, never `[T]!`), the mutation's single `input:`
   argument and its `<Mutation>Payload` with a typed domain-error union, and whether a list field
   is a bounded Relay connection or a hard-bounded plain list.
2. **Locate the seam.** Grep for the nearest sibling resolver and copy its structure — how it
   reaches the data layer, how it reads the request context, where authorization lives. A new
   module needs a reason you can state.
3. **Write the test first.** One test per acceptance criterion, named with its `UC-<n>` id when
   working from a spec. Minimum per field or mutation: happy path, authorization denial, one
   domain-error member of the payload union, and the empty or absent case. Run it and confirm it
   fails on the assertion — a schema validation error is not a red test.
4. **Implement the resolver thin.** <The layering this project uses: what validates, what holds
   the business rules, what loads data. Name the directories.> Anything crossing an entity
   boundary loads through a per-request DataLoader; a resolver that queries per parent is a
   defect, not a performance note.
5. **Authorization per field.** Every field that exposes restricted data states who may read it.
   A check only at the query root is a hole: the same type is reachable through other paths.
6. **Errors in their place.** Expected domain failures are typed members of the payload union and
   the resolver returns normally. Unauthenticated, malformed query and downstream outage go to
   top-level `errors[]` with a stable `extensions.code`. Never an internal message.
7. **Regenerate downstream artefacts** — typed clients, the committed schema snapshot, fixtures,
   documentation — in the same commit.

## Test requirements

Beyond the four cases in step 3, add a case for every branch you introduce: each input validation
rule, each member of the error union, each nullable field's absent case. Integration tests
execute real documents against the schema and assert on the response JSON — `data`, and `errors`
with its `extensions.code` — not on resolver internals. Add one batching test per DataLoader:
N parents must produce one load call. See the `dense-testing` skill for the density floors.

## Verify

Run the verification block from the `.claude/rules/` file for the stack you touched, in order:
lint, then types or static analysis, then tests. Add:

- <the schema diff check this project uses> — every entry it reports as breaking is a blocker
  unless the field is `@deprecated` with a stated window.
- <the codegen check, if typed clients are generated — the generated output is committed and
  `git diff` is clean after regenerating>

## Done when

Every acceptance criterion has a passing test carrying its `UC-<n>` id, nullability is deliberate
per field, authorization is explicit per field, growable lists are bounded connections, the schema
diff reports no unannounced breaking change, and the stack's verification commands are green.
