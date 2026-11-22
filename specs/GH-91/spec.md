---
ticket: GH-91
title: Refresh mature compatible analyzer pins
status: draft
stacks: [slop-guard catalogue]
---

# GH-91 — Refresh mature compatible analyzer pins

## Problem

Slop Guard's pinned analyzers trail mature compatible releases. Operators need verified release assets and a reproducible dependency lock without bypassing the seven-day publication hold, changing supported runtimes, or silently claiming the minimatch advisory is resolved.

## Scope

In:
- Betterleaks 1.10.1, jscpd 5.4.3, PHPStan 2.3.5, Ruff 0.17.5, Checkov 3.4.3, tflint 0.66.0 and zizmor 1.32.0 in the shipped tool lock.
- Locally downloaded and SHA-256-hashed assets for all supported platforms; the universal Python 3.9 hash lock filtered at `2026-11-15T12:03:19Z`, including transitive dependencies.
- Changelog and PR evidence explaining publication holds, Checkov compatibility, and the unchanged npm advisory.

Out:
- Opengrep upgrades: 1.30.0 remains the GH-65 stacked-PR QA baseline.
- ESLint, its plugins, TypeScript and Psalm upgrades owned by #78; golangci-lint, hadolint, kube-linter, jq and shellcheck upgrades.
- Python floor changes, npm overrides, immature releases, plugin version fields, new rules, fixture changes, or weakening/deleting/skipping tests.
- Clearing GHSA-g3hv-75wg-m249 before a compatible typescript-eslint release matures; the seven moderate findings are explicitly retained.

Change budget: 120 added lines, 7 files, 2 modules

## Context

- [PR #91](https://github.com/emgiezet/aisdlc/pull/91) — version/publication tables, compatibility decisions and actual verification counts.
- `plugins/slop-guard/tools/tools.lock-rationale.md` — seven-day hold and local asset hashing procedure.
- `plugins/slop-guard/tools/tools.lock.json`, `plugins/slop-guard/tools/python/requirements.in`, `plugins/slop-guard/tools/python/requirements.lock` — declared and installed analyzer versions.
- `plugins/slop-guard/tools/node/package.json`, `plugins/slop-guard/tools/node/package-lock.json` — unchanged bundle: typescript-eslint 8.72.1 requires minimatch ^10.2.2, but the advisory fix starts at 11.0.1. 8.73.0 matures at `2026-11-23T17:07:26.146Z`.
- `plugins/slop-guard/CHANGELOG.md`, `plugins/slop-guard/tests/tool-integration`, `plugins/slop-guard/scripts/validate-configs`, `plugins/slop-guard/scripts/gen-skills`, `plugins/slop-guard/tests/run-tests`, `Makefile` — operator notes and verification commands.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|---|---|---|---|---|
| UC-1 | operator | run `plugins/slop-guard/bin/slopguard doctor --install --all` with fresh plugin data and plugin-only sourcing | All 15 pinned tools install or resolve with matching versions and no host asset hash error. | integration |
| UC-2 | maintainer | inspect release timestamps and regenerate the universal Python hash lock with the recorded cutoff | All selected direct and transitive package versions predate `2026-11-15T12:03:19Z`; Python 3.9 resolution succeeds with Checkov 3.4.3 rather than incompatible 3.4.4/3.4.5. | integration |
| UC-3 | operator | run `SLOPGUARD_IT_REQUIRE=1 make tool-integration` using the installed toolchain | Zero unexpected failures and zero skipped cases; existing quarantined cases remain explicitly counted. | integration |
| UC-4 | maintainer | run `plugins/slop-guard/scripts/validate-configs` | All 25 validation rows pass with zero failed or skipped rows. | integration |
| UC-5 | maintainer | run `plugins/slop-guard/scripts/gen-skills --check` | Generation is deterministic and exits zero without changing shipped skill content. | integration |
| UC-6 | maintainer | run `plugins/slop-guard/tests/run-tests` and `CI= make validate` | Both commands exit zero; no test is deleted, weakened or skipped to accept the refresh. | integration |
| UC-7 | maintainer | run `npm audit --package-lock-only` in the Node tool directory | Seven moderate findings remain attributable to GHSA-g3hv-75wg-m249, explicitly documented with incompatible minimatch ranges and the 8.73.0 maturity timestamp; both npm files remain unchanged. | integration |

## Non-functional

No plugin version or supported Python floor changes. Every changed binary/PHAR platform entry is downloaded locally and hashed with `sha256sum`; non-host platform execution is explicitly not verified. Linux AMD64 integration uses a fresh plugin-only installation, not mismatched PATH analyzers.

## Open questions

None.
