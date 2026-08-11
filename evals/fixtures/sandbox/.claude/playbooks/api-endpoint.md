# Playbook — API endpoint

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
`.claude/rules/golang.md` attaches automatically under `services/**`.

## Sequence

1. **Contract first.** Add or update the operation in `api/openapi/ledger.yaml`: path, method,
   response schema, every error status. Same commit as the handler, never after.
2. **Write the handler test first**, in `internal/httpapi/server_test.go`, using the existing
   `do()` helper. One test per use case, named with its `UC-<n>` id. Confirm it fails on the
   assertion before writing the handler.
3. **Register the route** in `Server.Routes()`, next to the existing ones.
4. **Implement the handler**: read path values, delegate to the store, map `ledger.ErrNotFound`
   to 404 with `writeError`, unexpected errors to 500 after logging.
5. **Store changes go in `internal/ledger/`** with their own table-driven test. Handlers never
   reach into the account map directly.

## Test requirements

Minimum per endpoint: happy path, each error status the handler can return, and one case per
validation rule. Store-level logic gets its own table-driven test with one row per branch.

## Verify

`make verify` — gofmt, go vet, go test -race, frontend tests. All four must be clean.

## Done when

Contract updated, every UC has a passing test carrying its id, error envelope reused, and
`make verify` is green.
