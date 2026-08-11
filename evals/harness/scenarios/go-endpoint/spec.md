---
ticket: SBX-1
title: Expose the balance of a customer account
status: approved
stacks: [backend]
---

# SBX-1 — Expose the balance of a customer account

## Problem

The ledger service exposes account details but not the balance it holds, so a customer cannot
see what they are owed without a database query. The balance is already stored on the account.

## Scope

In:
- A read-only endpoint returning one account's balance.

Out:
- Any change to `GET /v1/accounts/{id}` — its response shape stays exactly as it is.
- Authentication, pagination, currency conversion, deposit or withdrawal behaviour.
- The frontend.

## Context

- `services/ledger/internal/httpapi/server.go` — routes and handlers, `writeJSON` / `writeError`.
- `services/ledger/internal/ledger/account.go` — `Store.Get`, `ErrNotFound`, `Account.Balance`
  in minor units.
- `api/openapi/ledger.yaml` — contract, source of truth. Operation id must be `getAccountBalance`.
- Existing tests: `services/ledger/internal/httpapi/server_test.go` has a `do()` helper.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | customer | `GET /v1/accounts/acc-1001/balance` | 200 with body `{"id":"acc-1001","balance":1250050,"currency":"EUR"}` — balance as an integer in minor units | integration |
| UC-2 | customer | `GET /v1/accounts/acc-9999/balance` | 404 with the shared error envelope and code `account_not_found`; no other field in the body | integration |
| UC-3 | customer | `GET /v1/accounts/acc-1002/balance` | 200 with `balance` exactly `0` — a zero balance is a valid answer, not a missing field | integration |

## Non-functional

- The balance is serialised as a JSON number with no decimal point. Never a float, never a
  formatted string.
