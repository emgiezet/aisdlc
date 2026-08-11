# Project: Sandbox Ledger

Two-stack fixture used to evaluate the AI SDLC harness: a Go HTTP service holding customer
ledger accounts, and a dependency-free JavaScript frontend module for display formatting.

## Task Router

Find the row matching your task and read **only** the files it names. Do not preload other
playbooks or rules.

| Your task | Read |
|-----------|------|
| Add or change an HTTP API endpoint | `.claude/playbooks/api-endpoint.md` |
| Change display formatting in the frontend | `.claude/playbooks/frontend.md` |
| Write or fix tests, chase coverage | `.claude/playbooks/testing.md` |
| Deliver an approved spec end-to-end | run `/sdlc-implement <TICKET>` |
| Anything else | this file plus the `.claude/rules/` file for the paths you touch |

`.claude/rules/*.md` are **path-scoped** — they attach automatically to the files you edit.
Playbooks are **task-scoped**: this table is the only way in.

## Layout

- `services/ledger/` — Go service. `cmd/api/` entry point, `internal/ledger/` store,
  `internal/httpapi/` HTTP layer.
- `frontend/` — JavaScript display helpers, tested with `node:test`.
- `api/openapi/ledger.yaml` — API contract, source of truth.
- `specs/<TICKET>/` — agent-facing specs.

## Invariants

1. Conventional commits: `type(scope): description`.
2. Money is always minor units (cents) as an integer. Never a float.
3. `api/openapi/ledger.yaml` is the contract source of truth — it changes in the same commit
   as the handler.
4. All new functionality requires tests. Never delete, skip, or weaken a test to get green.
5. Every endpoint returns the shared error envelope: `{"error":{"code":…,"message":…}}`.
6. Run `make verify` before considering a task done.

## Commands

- `make verify` — everything CI runs: gofmt, go vet, go test, frontend tests
- `make test-go` · `make test-js` · `make lint`
