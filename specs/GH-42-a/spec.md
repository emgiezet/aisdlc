---
ticket: GH-42-a
title: anti-slop mapping decision, the ESLint port pinned, and type-assertion slop as AP-TS-MAINT-005/006
status: approved
stacks: [slop-guard catalogue, bash]
---

# GH-42-a — Map anti-slop into the catalogue; detect fabricated type evidence

Source: https://github.com/emgiezet/aisdlc/issues/42 · plan: `specs/GH-42/decomposition.md`

## Problem

slop-guard names TypeScript type-safety slop with one broad entry, `AP-TS-MAINT-001`. Agents
also write code that passes the type checker by fabricating type evidence — `(y as unknown) as
Foo`, an unexplained `as User`, a known value widened to `unknown` and asserted back — and none
of it can be named or enforced today. dmmulroy/anti-slop catalogues these patterns; nothing
records which of its rules slop-guard adopts.

## Scope

In:
- `plugins/slop-guard/docs/decisions.md`: decision **D36** in the decisions table, plus a subsection with one row per
  anti-slop rule at upstream commit `c44ef22` (the commit `@spacemansh/anti-slop` 0.3.0 tracks):
  23 rows, each exactly one of `covered by <AP id>`, `added as <AP id> (<slice>)`,
  `rejected: <reason>`. The rows are the table under **Mapping** below, verbatim in meaning.
- `plugins/slop-guard/tools/node/package.json` + `plugins/slop-guard/tools/node/package-lock.json`: `"@spacemansh/anti-slop": "0.3.0"`, exact.
- `plugins/slop-guard/configs/baseline/eslint.config.mjs`: import the plugin from `@spacemansh/anti-slop/eslint`,
  register it once in the TypeScript block, enable the four rules of this slice at `warn`.
- `plugins/slop-guard/rules/catalog.yaml`: `AP-TS-MAINT-005` and `AP-TS-MAINT-006` (severity `warn`, category
  `maintainability`, `cwe: []`, original text, own `bad`/`good`).
- `plugins/slop-guard/rules/mapping/eslint.yaml`: entries for the four rule ids of this slice.
- `plugins/slop-guard/skills/ts-react-antipatterns/`: regenerated.
- `plugins/slop-guard/tests/fixtures/ts/` bad and good fixtures: `AP-TS-MAINT-005.ts` and
  `AP-TS-MAINT-006.ts` in each of `bad/` and `good/`.
- `plugins/slop-guard/tests/integration/fast.sh`: fixture cases for `AP-TS-MAINT-005` and `AP-TS-MAINT-006`.
- `plugins/slop-guard/tests/catalog_test.sh`: the D36-table invariant.
- `plugins/slop-guard/CHANGELOG.md` `## Unreleased` entry with a **Why** paragraph.
- `.gitignore`: ignore runtime artefacts the hooks and the ESLint dispatcher write into the tree
  (`plugins/slop-guard/sessions/`, `plugins/slop-guard/tools/node/eslint.config.mjs`).

**Mapping** (D36):

| anti-slop rule | decision |
|---|---|
| `no-chained-type-assertions` | added as `AP-TS-MAINT-005` (GH-42-a) |
| `require-safety-comment-for-type-assertion` | added as `AP-TS-MAINT-005` (GH-42-a) |
| `no-known-value-widening` | added as `AP-TS-MAINT-006` (GH-42-a) |
| `no-widen-then-assert` | added as `AP-TS-MAINT-006` (GH-42-a) |
| `no-unknown-parameters` | added as `AP-TS-MAINT-007` (GH-42-b) |
| `no-unknown-returns` | added as `AP-TS-MAINT-007` (GH-42-b) |
| `no-unknown-type-aliases` | added as `AP-TS-MAINT-007` (GH-42-b) |
| `no-object-parameters` | added as `AP-TS-MAINT-007` (GH-42-b) |
| `no-unsafe-dictionary-type` | added as `AP-TS-MAINT-007` (GH-42-b) |
| `no-reflect-get` | added as `AP-TS-MAINT-008` (GH-42-b) |
| `no-reflect-apply` | added as `AP-TS-MAINT-008` (GH-42-b) |
| `no-reduce-accumulator-copy` | added as `AP-TS-PERF-005` (GH-42-c) |
| `no-module-mocking` | added as `AP-TS-MAINT-009` (GH-42-c) |
| `no-runtime-typeof` | covered by `AP-TS-MAINT-001` — prevention text only; the rule fires on idiomatic narrowing |
| `no-array-filter-map` | rejected: a two-pass micro-optimisation, not low-evidence code |
| `no-conditional-empty-object-spread` | rejected: a style preference with no defect class behind it |
| `no-shape-in-symbol-names` | rejected: a naming taste of the upstream author |
| `require-readable-spacing` | rejected: formatting belongs to the project's formatter |
| `no-manual-effect-error-tag` | rejected: Effect-only architecture policy; the catalogue has no Effect framework |
| `no-manual-tag-comparison` | rejected: Effect-only, as above |
| `no-manual-tagged-construction` | rejected: Effect-only, as above |
| `no-service-constructor-imports` | rejected: Effect-only, as above |
| `prefer-effect-match` | rejected: Effect-only, as above |

Out:
- `AP-TS-MAINT-007/008` (`GH-42-b`) and `AP-TS-PERF-005`, `AP-TS-MAINT-009` (`GH-42-c`): their
  rules stay off in the baseline config here.
- Oxlint, vendoring upstream source, the Effect entry point `@spacemansh/anti-slop/eslint/effect`.
- Changing `AP-TS-MAINT-001`'s text, detectors or severity.
- `tools/tools.lock.json` (`eslint-stack` already points at the node lockfile), `lib/dispatch.sh`,
  the security overlay, `rules/stacks.json`.
- The vendored copy in `trasti-sdlc` — another repository.
- Hand edits under `skills/ts-react-antipatterns/` — regenerate only.

Change budget: 420 added lines, 17 files, 2 modules

## Context

- `plugins/slop-guard/rules/catalog.yaml` — `AP-TS-MAINT-001` … `AP-TS-MAINT-004` (copy the shape).
- `plugins/slop-guard/rules/mapping/eslint.yaml` — `@typescript-eslint/no-explicit-any` → `AP-TS-MAINT-001`.
- `plugins/slop-guard/configs/baseline/eslint.config.mjs` — the `// --- TypeScript ---` block; the
  `tests and scripts: relaxed` block.
- `plugins/slop-guard/tools/node/{package.json,package-lock.json}`; `lib/tools.sh`
  `install_node_tools` (`npm ci --ignore-scripts`).
- `plugins/slop-guard/tests/integration/fast.sh` — the `eslint-stack` block; `medium.sh` header
  for `CONFIG_SOURCE=full`, needed for a `maintainability` finding to pass the overlay.
- `plugins/slop-guard/tests/catalog_test.sh`; `plugins/slop-guard/scripts/gen-skills`.
- `plugins/slop-guard/docs/decisions.md` — D6, D33, the last row D35.
- Upstream: https://github.com/dmmulroy/anti-slop at `c44ef22ca116d0ba62a3ff663a0bd13a3f3fa40b`;
  port: https://github.com/tonyedgal/anti-slop (`docs/UPSTREAM.md`, `docs/ESLINT.md`). Both MIT.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | maintainer | `bash tests/catalog_test.sh` | passes; it fails when the D36 table has other than 23 rows, or an `added as`/`covered by` id is missing from `catalog.yaml` | unit |
| UC-2 | maintainer | `slopguard doctor --install --all`, then `scripts/validate-configs` | eslint reports `PASS`; `tools/node/node_modules/@spacemansh/anti-slop/package.json` version is `0.3.0` | integration |
| UC-3 | agent | writes `const x = (y as unknown) as Foo;` | fast tier reports `AP-TS-MAINT-005` from `anti-slop/no-chained-type-assertions` | integration |
| UC-4 | agent | writes `const id = value as UserId;` with no comment above | fast tier reports `AP-TS-MAINT-005` from `anti-slop/require-safety-comment-for-type-assertion` | integration |
| UC-5 | agent | writes a known object, assigns it to `const w: unknown`, then `w as { id: string }` | fast tier reports `AP-TS-MAINT-006` | integration |
| UC-6 | agent | the good fixture: `as const` chains and `// SAFETY: <reason>` above each assertion *(inferred negative)* | no `AP-TS-MAINT-005` or `AP-TS-MAINT-006` finding | integration |
| UC-7 | maintainer | `scripts/gen-skills --check` | exit 0; `reference/AP-TS-MAINT-005.md` and `-006.md` exist with the catalogue's `bad` and `good` blocks | unit |

## Non-functional

- One new dependency, no new transitive surface: the package has no runtime dependencies and its peers
  are optional; the lockfile records its integrity hash; `--ignore-scripts` stays.
- Generated `SKILL.md` within 150 lines / 3000 tokens.
- `CI= make validate` and `make tool-integration` (after `doctor --install --all`) pass.

## Open questions

none
