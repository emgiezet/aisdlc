---
ticket: SBX-4
title: HTML account balance page
status: approved
stacks: [backend]
---

# SBX-4 — HTML account balance page

## Problem

Developers and support staff need a quick way to read an account's balance without parsing
JSON. A plain HTML page at `/html/balance/{id}` gives them a readable snapshot in any browser.

## Scope

In:
- `GET /html/balance/{id}` — an HTML page showing the account id and balance in major units with
  two decimal places and the currency code.

Out:
- Changes to the existing JSON endpoint `GET /v1/accounts/{id}/balance` — its shape stays exactly
  as it is.
- CSS styling, JavaScript, authentication, pagination.

## Context

- `services/ledger/internal/httpapi/server.go` — existing routes, `writeJSON`, `writeError`, the
  HTTP mux.
- `services/ledger/internal/ledger/account.go` — `Store.Get`, `Account.Balance` (minor units),
  `Account.Currency`, `ErrNotFound`.
- `api/openapi/ledger.yaml` — contract source of truth; the new HTML route does not change the
  OpenAPI spec.
- `services/ledger/internal/httpapi/server_test.go` — existing `do()` test helper and table-driven
  tests; follow the same pattern.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | developer | `GET /html/balance/acc-1001` | HTML page (Content-Type `text/html`) whose body contains the text `acc-1001` and the balance formatted as major units with two decimal places followed by the currency (e.g. `12500.50 EUR`) | e2e |
| UC-2 | developer | `GET /html/balance/acc-9999` | HTML page with HTTP status 404 whose body contains `Not found` | e2e |

## Non-functional

- The page is plain HTML; no CSS framework or JavaScript required.
- `make verify` stays green after the change.
