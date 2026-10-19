---
ticket: GH-42-b
title: unknown/object type contracts and Reflect access as AP-TS-MAINT-007/008
status: approved
stacks: [slop-guard catalogue, bash]
depends-on: GH-42-a
---

# GH-42-b — Detect contracts that throw type information away

Source: https://github.com/emgiezet/aisdlc/issues/42 · plan: `specs/GH-42/decomposition.md`

## Problem

Agents satisfy the type checker by declaring the weakest contract that compiles: parameters,
returns, aliases and dictionary values typed `unknown` or `object`, and property access routed
through `Reflect.get` / `Reflect.apply`. The code type-checks and carries no evidence. After
`GH-42-a` the ESLint port is installed and D36 assigns these rules to `AP-TS-MAINT-007` and
`AP-TS-MAINT-008`, but neither id exists yet.

## Scope

In:
- `rules/catalog.yaml`: `AP-TS-MAINT-007` "unknown or object in a type contract" and
  `AP-TS-MAINT-008` "Reflect.get / Reflect.apply instead of typed access" — severity `warn`,
  category `maintainability`, `cwe: []`, original text, own `bad`/`good`.
- `rules/mapping/eslint.yaml`: `anti-slop/no-unknown-parameters`, `no-unknown-returns`,
  `no-unknown-type-aliases`, `no-object-parameters`, `no-unsafe-dictionary-type` →
  `AP-TS-MAINT-007`; `anti-slop/no-reflect-get`, `no-reflect-apply` → `AP-TS-MAINT-008`.
- `configs/baseline/eslint.config.mjs`: those seven rules at `warn` in the TypeScript block.
- Regenerated `skills/ts-react-antipatterns/`; fixtures `tests/fixtures/ts/{bad,good}/AP-TS-MAINT-00{7,8}.ts`;
  their cases in `tests/integration/fast.sh`; `CHANGELOG.md` entry.

Out:
- D36 and its table (written in `GH-42-a`), the package pin, the plugin registration.
- `AP-TS-PERF-005` and `AP-TS-MAINT-009` — `GH-42-c`.
- Changing `AP-TS-MAINT-001` or the `@typescript-eslint/no-explicit-any` mapping.
- Rule options beyond the port's defaults.

Change budget: 210 added lines, 12 files, 1 modules

## Context

- `GH-42-a` — `specs/GH-42-a/spec.md` (mapping table, `AP-TS-MAINT-005/006` entries as the shape).
- `plugins/slop-guard/rules/catalog.yaml`, `rules/mapping/eslint.yaml`,
  `configs/baseline/eslint.config.mjs` (TypeScript block), `scripts/gen-skills`.
- `plugins/slop-guard/tests/integration/fast.sh` — the `AP-TS-MAINT-005` cases added by `GH-42-a`.
- Upstream valid cases at `c44ef22`: `cause: unknown`, the subject of a type predicate
  (`(x: unknown): x is Foo`), and generic constraints `T extends Record<string, unknown>` are allowed.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-8 | agent | writes `function save(input: unknown) {}` | fast tier reports `AP-TS-MAINT-007` from `anti-slop/no-unknown-parameters` | integration |
| UC-9 | agent | writes `function load(): Promise<unknown> {}` | `AP-TS-MAINT-007` from `anti-slop/no-unknown-returns` | integration |
| UC-10 | agent | writes `type Payload = unknown;` | `AP-TS-MAINT-007` from `anti-slop/no-unknown-type-aliases` | integration |
| UC-11 | agent | writes `function f(o: object) {}` and `const m: Record<string, unknown> = {}` | `AP-TS-MAINT-007` from `no-object-parameters` and from `no-unsafe-dictionary-type` | integration |
| UC-12 | agent | writes `Reflect.get(user, 'name')` and `Reflect.apply(fn, null, args)` | `AP-TS-MAINT-008` from each of `no-reflect-get` and `no-reflect-apply` | integration |
| UC-13 | agent | the good fixture: `cause: unknown`, `(x: unknown): x is Foo`, `T extends Record<string, unknown>`, `user.name` *(inferred negative)* | no `AP-TS-MAINT-007` or `AP-TS-MAINT-008` finding | integration |
| UC-14 | maintainer | `scripts/gen-skills --check` | exit 0; `reference/AP-TS-MAINT-007.md` and `-008.md` exist with the catalogue's `bad` and `good` blocks | unit |

## Non-functional

- Generated `SKILL.md` within 150 lines / 3000 tokens.
- `CI= make validate` and `make tool-integration` pass.

## Open questions

none
