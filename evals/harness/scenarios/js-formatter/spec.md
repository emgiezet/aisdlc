---
ticket: SBX-3
title: Show a balance with its account label in one string
status: approved
stacks: [frontend]
---

# SBX-3 — Show a balance with its account label in one string

## Problem

Every screen that lists accounts formats the label and the balance separately and joins them
by hand, so the separator differs between views. One helper should own the joined form.

## Scope

In:
- One new exported function in `frontend/src/format.mjs` that renders an account and its
  balance as a single display string.

Out:
- Changing `formatAccountId` or `formatBalance` behaviour or signatures.
- Adding any dependency. React components. The Go service.

## Context

- `frontend/src/format.mjs` — `formatAccountId` (`acc-1001` → `#1001`) and `formatBalance`
  (`1250050, 'EUR'` → `12500,50 EUR`). Reuse both; do not reimplement their logic.
- `frontend/src/format.test.mjs` — existing tests use `node:test` and `node:assert/strict`.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | user | `formatAccountSummary({id:'acc-1001', name:'Northwind Trading', currency:'EUR', balance:1250050})` | returns exactly `Northwind Trading (#1001) — 12500,50 EUR` | unit |
| UC-2 | user | passes an account whose `balance` is not an integer | throws an `Error` whose message names minor units; nothing is returned | unit |

## Non-functional

- Pure function, no I/O. The em dash separator is part of the contract: `name (#id) — amount`.
