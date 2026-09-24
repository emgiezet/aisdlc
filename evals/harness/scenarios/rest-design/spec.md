---
ticket: SBX-5
title: List customer accounts
status: approved
stacks: [backend]
---

# SBX-5 — List customer accounts

## Problem

The ledger service can return one account by id, but nothing can enumerate them. An operator
listing accounts today has to read the store directly, and any listing added carelessly will grow
without bound as accounts are added.

## Scope

In:
- A read-only collection endpoint returning accounts, paginated.

Out:
- Any change to `GET /v1/accounts/{id}` — its response shape stays exactly as it is.
- Authentication, filtering, sorting by anything other than `id`, deposit or withdrawal
  behaviour.
- The frontend.

## Context

- `services/ledger/internal/httpapi/server.go` — `Routes`, handlers, `writeJSON` / `writeError`.
- `services/ledger/internal/ledger/account.go` — `Store`, seeded with `acc-1001` and `acc-1002`,
  `ErrNotFound`.
- `api/openapi/ledger.yaml` — contract, source of truth. Operation id must be `listAccounts`.
- Existing tests: `services/ledger/internal/httpapi/server_test.go` has a `do()` helper.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | client | `GET /v1/accounts` | 200; `data` holds both accounts ordered by `id` ascending, each item with exactly the keys `id`, `name`, `currency`; `next_cursor` is `null` | integration |
| UC-2 | client | `GET /v1/accounts?limit=1` | 200; `data` holds only `acc-1001`; `next_cursor` is the string `"acc-1001"` | integration |
| UC-3 | client | `GET /v1/accounts?limit=1&cursor=acc-1001` | 200; `data` holds only `acc-1002`; `next_cursor` is `null` | integration |
| UC-4 | client | `GET /v1/accounts?limit=101` | 400 with the shared error envelope and code `invalid_limit`; no second error shape in the body | integration |
| UC-5 | client | `GET /v1/accounts/acc-1001` | unchanged: 200 with exactly `id`, `name`, `currency` | integration |

## Non-functional

- The default `limit` is 20 and the maximum is 100. A `limit` above the maximum is rejected, never
  silently clamped.
- The listing order is `id` ascending, and `id` is the cursor's tie-breaker.
- An empty page is `200` with an empty array, never `404`.
