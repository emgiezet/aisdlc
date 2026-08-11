---
paths:
  - services/**
---
# Go Standards (sandbox)

## Stack: Go 1.22+, standard library only. No third-party dependencies.

## Style
- gofmt is mandatory. `go vet ./...` must be clean.
- Exported identifiers documented with a comment starting with the identifier name.
- Import groups separated by blank lines: stdlib, then internal.

## Errors
- Always check returned errors. Never assign to `_`.
- Sentinel errors for expected conditions (`ledger.ErrNotFound`), checked with `errors.Is`.
- Wrap with context: `fmt.Errorf("getting account %s: %w", id, err)`.
- Never panic outside `main()`.

## HTTP layer
- Routes registered in `Server.Routes()` using `net/http` patterns: `GET /v1/accounts/{id}`.
- Path parameters via `r.PathValue("id")`.
- Handlers decode, validate, delegate to the store, and map errors to status codes. No
  business logic in handlers.
- Success responses via `writeJSON`; failures via `writeError` with a snake_case code. Never
  hand-roll a response shape.
- Money is `int64` minor units in both the store and the JSON payload.

## Testing
- Table-driven tests where there is more than one case.
- HTTP handlers tested with `httptest.NewRequest` / `httptest.NewRecorder` through
  `Routes()`, asserting status code and decoded body.
- Test names carry the spec use case id when implementing a spec: `TestGetBalance_UC1_…`.

## Verification (run after EVERY change)
- `gofmt -l .` (must print nothing)
- `go vet ./...`
- `go build ./...`
- `go test -race ./...`
