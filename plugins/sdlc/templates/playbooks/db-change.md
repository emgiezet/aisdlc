# Playbook — Database change

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
The `.claude/rules/` file covering migrations attaches on its own.

## Sequence

1. **Read the current schema before writing anything.** Find the table in the schema
   documentation *and* in the code that maps it. Never infer a schema from a variable name.
2. **Decide whether this is one migration or two.** Schema changes and data backfills are always
   separate migrations. Unrelated schema changes are separate migrations.
3. **Write the migration with both directions.** Up and down. A migration you cannot roll back is
   only acceptable when the down direction is genuinely impossible — say so in a comment and flag
   it in the pull request body.
4. **Check destructiveness.** Dropping a column or table, renaming, narrowing a type, or adding a
   NOT NULL column to a populated table is a two-step deploy: add the new shape, migrate reads
   and writes, remove the old shape in a later change. Never combine them.
5. **Index the access paths you just created** — every foreign key, and every column the new query
   filters or sorts on.
6. **Update the application layer** in the same commit: models, factories, fixtures, and any
   contract schema that exposes the changed fields.
7. **Get it reviewed** before opening the pull request. Migrations are the change class where an
   agent mistake is hardest to undo.

## Test requirements

- A test that runs the migration up, then down, then up again on a scratch database.
- A test per new constraint proving it rejects invalid data.
- Existing tests touching the changed table are **updated** in the same commit, never skipped. A
  test you cannot make pass is a signal the schema change is wrong.
- For a backfill: a test with rows in the pre-migration shape asserting the post-migration values.

## Verify

Run this project's migration commands, then the full test suite for every stack that reads the
changed table. Add:

- Query plan inspection for anything the change makes hotter on a large table.
- Confirm no already-deployed migration file was edited: `git diff --name-only` shows only the
  new migration plus application-layer files.

## Done when

Up and down both proven, constraints tested, application layer and contracts updated, review
clean, and any destructive step deferred to its own change.
