---
ticket: GH-78
title: Upgrade the compatible ESLint analyzer bundle
status: approved
stacks: [slop-guard catalogue]
---

# GH-78 — Upgrade the compatible ESLint analyzer bundle

## Problem

Slop Guard's ESLint bundle trails available compatible versions of ESLint and three plugins. Operators need the newer analyzers without broken strict installs, a baseline migration, or bypassing the repository's seven-day release hold.

## Scope

In:
- ESLint and `@eslint/js` 9.39.5, `eslint-plugin-react-hooks` 7.1.1, `eslint-plugin-security` 4.2.1, and `eslint-plugin-n` 18.5.0 in the shipped Node bundle and tool lock.
- The compatible Node engine range, exact npm lock, preserved pins inherited from #77, and compatibility rationale for held versions.

Out:
- Upgrading to ESLint 10, TypeScript 7, Psalm 7, or regexp 3; updating unrelated analyzers; changing baseline enabled rules or weakening fixture assertions.
- Peer/engine overrides, lifecycle scripts at install, or bypassing the publication cutoff.

Change budget: 120 added lines, 9 files, 2 modules

## Context

- [PR #78](https://github.com/emgiezet/aisdlc/pull/78) — compatibility decisions and registry cutoff `2026-10-30T09:56:41Z` for newly introduced versions.
- `plugins/slop-guard/tools/node/package.json`, `plugins/slop-guard/tools/node/package-lock.json`, `plugins/slop-guard/tools/tools.lock.json`, `plugins/slop-guard/tools/tools.lock-rationale.md` — declared, installed and advertised versions.
- `plugins/slop-guard/CHANGELOG.md` — operator-visible engine and rule-semantics changes.
- `plugins/slop-guard/configs/baseline/eslint.config.mjs`, `plugins/slop-guard/tests/integration/fast.sh` — unchanged baseline and real-analyzer smoke coverage.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|---|---|---|---|---|
| UC-1 | operator | install the shipped lock with strict peers and engines on supported Node and lifecycle scripts disabled | npm installs the five target versions without ignoring peer or engine constraints; the installed ESLint version matches the advertised tool lock. | integration |
| UC-2 | maintainer | audit all lockfile versions introduced by the upgrade against the registry | Each new direct or transitive package version was published no later than `2026-10-30T09:56:41Z`; inherited base pins are not attributed to this upgrade. | integration |
| UC-3 | operator | analyze the existing bad TypeScript fixture with the installed bundle | Slop Guard reports `AP-TS-SEC-002` under the shipped baseline. | integration |
| UC-4 | operator | analyze the existing clean React fixture with the installed bundle | Slop Guard produces no diagnostic under the shipped baseline. | integration |

## Non-functional

Supported Node range: `^22.18.0 || >=24` — the intersection of every engine in the lock (`eslint-plugin-n` 18.5.0: `^20.19.0 || ^22.13.0 || >=24`; unchanged `@spacemansh/anti-slop` 0.3.0: `>=22.18.0`). Strict installs on Node 20, Node 22 before 22.18 and Node 23 fail with EBADENGINE, which is expected, not a regression. The shipped baseline's explicit enabled rule names stay unchanged; upstream matching semantics may tighten.

## Open questions

None.
