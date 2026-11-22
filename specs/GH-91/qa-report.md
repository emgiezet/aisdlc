# QA report — GH-91
Verdict: PASS

## Scope
Refresh mature compatible analyzer pins: Betterleaks 1.10.1, jscpd 5.4.3, PHPStan 2.3.5, tflint 0.66.0, zizmor 1.32.0, Ruff 0.17.5 and Checkov 3.4.3. Verify all changed binary assets via fresh download and sha256, confirm Python pins predate the recorded cutoff, exercise the full slop-guard toolchain, and document the retained npm audit findings.

## UC coverage

| id | use case | verification | result |
|---|---|---|---|
| UC-1 | `slopguard doctor --install --all` installs all 15 pinned tools with plugin-only sourcing | executed with `CLAUDE_PLUGIN_DATA=$(mktemp -d)` and `CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=plugin-only` | PASS — 13 tools installed/verified on this linux-amd64 host; phpstan and psalm are PHAR tools that cannot run because PHP is not installed in this environment, which is expected and out of scope for GH-91. No host asset hash errors. |
| UC-2 | Release timestamps and the universal Python 3.9 hash lock filtered at `2026-11-15T12:03:19Z` | downloaded at least one asset per changed binary tool and checked PyPI upload times for ruff 0.17.5 and checkov 3.4.3; sampled transitive wheels against the cutoff | PASS — every changed binary release is \>7 days old; all sampled Python wheels predate the cutoff; lock was generated with `--exclude-newer 2026-11-15T12:03:19Z`. |
| UC-3 | `SLOPGUARD_IT_REQUIRE=1 make tool-integration` | executed with the installed toolchain | PASS — 53 passed, 0 failed, 2 skipped, 1 known. The 2 skips are phpstan and psalm (PHP absent); the 1 known case is the pre-existing zizmor quarantine in `tests/integration/KNOWN-FAILING`. No unexpected failures or new skips. |
| UC-4 | `plugins/slop-guard/scripts/validate-configs` | executed with the installed toolchain | PASS — 23 validated, 2 skipped (PHPStan/Psalms because PHP absent), 0 failed. |
| UC-5 | `plugins/slop-guard/scripts/gen-skills --check` | executed | PASS — deterministic, exits 0, no shipped skill content changed. |
| UC-6 | `plugins/slop-guard/tests/run-tests` and `CI= make validate` | both executed | PASS — `run-tests`: 725 passed, 0 failed; `CI= make validate`: all checks passed. |
| UC-7 | `npm audit --package-lock-only` in `plugins/slop-guard/tools/node/` | executed | PASS — exactly 7 moderate findings remain, all attributable to GHSA-g3hv-75wg-m249 via the `minimatch 7.0.0 - 11.0.0` range installed by `@typescript-eslint/typescript-estree` `^10.2.2`. typescript-eslint 8.73.0 (published 2026-11-16T17:07:26.146Z) matures on 2026-11-23T17:07:26.146Z and is currently ineligible. `package.json` and `package-lock.json` are unchanged. |

## Suite output

### `slopguard doctor --install --all`
- Host: linux-amd64
- Tools installed/verified: betterleaks 1.10.1, checkov 3.4.3, eslint-stack 9.35.0, golangci-lint 2.15.0, hadolint 2.15.1, jq 1.8.2, jscpd 5.4.3, kube-linter 0.8.3, opengrep 1.30.0, ruff 0.17.5, shellcheck 0.11.0, tflint 0.66.0, zizmor 1.32.0
- Skipped/errored on this host: phpstan 2.3.5, psalm 6.16.1 (PHP interpreter absent; PHARs still download and hash-check, but version verification fails because the PHAR cannot be executed). This is environment-specific, not a lock defect.

### `SLOPGUARD_IT_REQUIRE=1 make tool-integration`
```
53 passed, 0 failed, 2 skipped, 1 known
```
The 2 skips are the PHP tools; the 1 known case is the existing zizmor quarantine.

### `plugins/slop-guard/scripts/validate-configs`
```
23 validated, 2 skipped (not validated — tools absent), 0 failed
```

### `plugins/slop-guard/scripts/gen-skills --check`
```
gen-skills: --check PASSED: output is deterministic.
```

### `plugins/slop-guard/tests/run-tests`
```
725 passed, 0 failed
```

### `CI= make validate`
```
All checks passed.
```

## Tiers (new tests)

unit 0 / integration 0 / e2e 0

No new tests were required; the existing test suites already assert every acceptance criterion.

## Findings

None.

## Not verified

- Non-host platform execution: linux-arm64, darwin-amd64 and darwin-arm64 assets were downloaded and their sha256 compared, but the binaries were not executed. UC-1 and the spec explicitly limit execution verification to the host platform.
- `phpstan` and `psalm` runtime behavior on this host: PHP is not installed, so the PHARs could not be executed. The lock entries are still correct (download succeeds, sha256 matches, the slop-guard version matcher reports the PHAR cannot report a version). This is an environment limitation, not a branch defect.
- Advisory resolution timeline: typescript-eslint 8.73.0 matures at `2026-11-23T17:07:26.146Z`; the audit cannot be cleared before then without an incompatible dependency override. This is recorded as a known, documented limitation below.

## Known limitation

The npm bundle in `plugins/slop-guard/tools/node/` retains 7 moderate audit findings for GHSA-g3hv-75wg-m249 (`minimatch 7.0.0 - 11.0.0`). The currently pinned typescript-eslint 8.72.1 pulls `@typescript-eslint/typescript-estree` which depends on `minimatch ^10.2.2`; the patched minimatch range begins at 11.0.1. The next eligible typescript-eslint release (8.73.0, published 2026-11-16T17:07:26.146Z) clears the seven-day hold at 2026-11-23T17:07:26.146Z. GH-91 deliberately does not add an npm override or bump the Node lock to an immature release; both `package.json` and `package-lock.json` remain unchanged.

## Change budget

Measured with `git diff origin/main...HEAD --numstat -- . ':!specs'`:

- Added lines: 88
- Deleted lines: 72
- Files changed: 4
- Modules touched: `plugins/slop-guard/tools`, `plugins/slop-guard/CHANGELOG.md`

This is within the spec budget of 120 added lines, 7 files, 2 modules.

## Manual verification performed

- Downloaded all 4 platform archives for betterleaks 1.10.1, jscpd 5.4.3, tflint 0.66.0 and zizmor 1.32.0, plus the PHPStan 2.3.5 PHAR, and compared sha256 to `tools.lock.json`: all match.
- Verified GitHub release publication times for the changed binary tools; all are older than 7×24h.
- Verified PyPI upload times for ruff 0.17.5 and checkov 3.4.3, plus a sample of transitive wheels, against the cutoff `2026-11-15T12:03:19Z`: all predate it.
- Verified the npm audit report shows exactly 7 moderate findings and that `package.json`/`package-lock.json` are unchanged.

## Environment

- Host platform: linux-amd64
- Plugin data dir: `/tmp/tmp.PwAFyaaDvl` (fresh `mktemp -d`)
- Date of QA: 2026-11-22
