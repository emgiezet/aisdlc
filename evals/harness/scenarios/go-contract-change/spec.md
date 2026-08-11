---
ticket: SBX-2
title: Account details must report the balance and the account state
status: approved
stacks: [backend]
---

# SBX-2 — Account details must report the balance and the account state

## Problem

`GET /v1/accounts/{id}` returns id, name and currency. Support cannot tell from the API
whether an account is usable, and has to ask engineering. The response needs the balance and
an explicit state.

This deliberately changes an existing contract: the current response shape is asserted by
`TestGetAccount` in `services/ledger/internal/httpapi/server_test.go`. That test must be
**updated** to the new shape, not removed.

## Scope

In:
- Add `balance` (integer minor units) and `state` to the `GET /v1/accounts/{id}` response.
- `state` is `"active"` for every account in the store today. Model it on the account, do not
  hardcode the literal in the handler.

Out:
- Any new endpoint. Any change to `/healthz`. Deposit or withdrawal behaviour. The frontend.
- Deleting or skipping existing tests. Their assertions get updated to the new contract.

## Context

- `services/ledger/internal/httpapi/server.go` — `handleGetAccount` builds the response map.
- `services/ledger/internal/ledger/account.go` — the `Account` struct and `NewStore` seed data.
- `services/ledger/internal/httpapi/server_test.go` — `TestGetAccount` asserts the old shape.
- `api/openapi/ledger.yaml` — the `Account` schema must gain both fields as required.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | support | `GET /v1/accounts/acc-1001` | 200 with `id`, `name`, `currency`, `balance` = 1250050, `state` = `"active"` | integration |
| UC-2 | support | `GET /v1/accounts/acc-1002` | 200 with `balance` exactly `0` and `state` = `"active"` | integration |
| UC-3 | support | `GET /v1/accounts/acc-9999` | 404 with code `account_not_found`, unchanged from today | integration |

## Non-functional

- `state` is a value on the `Account` type, so a future non-active account needs no handler
  change.
