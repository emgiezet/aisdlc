---
ticket: GH-95
title: Upgrade the ESLint stack to ESLint 10 when React peers permit
status: draft
stacks: [slop-guard catalogue]
---

# GH-95 — ESLint 10 compatibility gate

## Problem

Slop Guard operators cannot use ESLint 10 with the shipped ESLint stack while its React plugin excludes that major from its peer range. Bypassing npm's compatibility checks would hide an unsupported analyzer combination. Implementation is blocked on the ESLint 9.39.5 prerequisite (#78) and either a compatible upstream React plugin release or an explicit owner decision about the alternative.

## Scope

In:
- After #78 lands and the approval blocker below is resolved: exact mature ESLint 10 and `@eslint/js` 10 pins, the minimum compatible plugin updates, and the regenerated npm lock and `eslint-stack` version.
- Strict installation compatibility, preservation of enabled baseline/security-overlay rules, and real-tool regression coverage with `UC-<n>` in test names.
- Publication/compatibility evidence and the owner's React-plugin decision in the existing lock rationale; an operator-facing changelog entry.

Out:
- Implementing while the peer blocker remains, automatically accepting a prerelease, or treating a documented blocker alone as successful completion of the ESLint 10 upgrade.
- Replacing `eslint-plugin-react` without a revised, owner-approved spec defining equivalent rules and mappings; dropping or disabling React rules to obtain a green install.
- `--force`, `--legacy-peer-deps`, npm overrides, patched peer metadata, ignored engine constraints, or enabling lifecycle scripts.
- `eslint-plugin-regexp` 3, unrelated analyzers, TypeScript major upgrades, new rule policy, severity tuning, dispatcher/installer redesign, or broad dependency refreshes.
- CI/workflow edits, release/version fields, generated skills, eval fixtures, test retirement, or changes to the prerequisite PR.

Change budget: 180 added lines, 8 files, 1 modules

## Context

- [Issue #95](https://github.com/emgiezet/aisdlc/issues/95), no comments at collection; [PR #78](https://github.com/emgiezet/aisdlc/pull/78) was OPEN and unmerged on 2026-11-23. Its `origin/fix/tool-bumps-majors:specs/GH-78/spec.md` names the 9.39.5 baseline and supported Node range. Rebase implementation on the merged prerequisite rather than reverting its plugin pins.
- `plugins/slop-guard/tools/node/package.json` (`dependencies`, `engines`), `plugins/slop-guard/tools/node/package-lock.json` (`packages`), and `plugins/slop-guard/tools/tools.lock.json` (`tools.eslint-stack`) — current main pins are 9.35.0. These three files are the declared, resolved, and advertised version contract.
- `plugins/slop-guard/configs/baseline/eslint.config.mjs` (`defineConfig`, `TYPED`, React and Node blocks) and `plugins/slop-guard/configs/baseline/eslint.security-overlay.mjs` (`defineConfig`) — preserve explicit rule names, options and severities except documented upstream ESLint 10 rule renames; inherited recommended-preset changes must be recorded, not silently compensated by weakening policy.
- `plugins/slop-guard/lib/tools.sh` (`install_node_tools`, `managed_metadata_matches`, `resolve_tool`) — read-only installer/resolution constraints; `npm ci --ignore-scripts` and manifest matching remain intact. `plugins/slop-guard/tests/tool-integration` (`it_skip_unless_tool`, `SLOPGUARD_IT_REQUIRE`) and `plugins/slop-guard/tests/integration/fast.sh` (ESLint bad/good cases) — integration entry points; new coverage belongs in the existing fast integration file.
- `plugins/slop-guard/tools/tools.lock-rationale.md` (7-day publication rule), `plugins/slop-guard/CHANGELOG.md` (Unreleased), and `.claude/sdlc.md` (test tiers and change-budget exclusions) — maintenance constraints. Budget comparison: `1f67172` (#77) adds 21 non-lock lines across 4 non-lock paths; `fb8989e` (#91 pin-refresh implementation) adds 18 across 2; `bed756e` (#78 ESLint-nine/rationale update) adds 21 across 3. The proposed conservative 8-path maximum adds baseline/overlay compatibility and integration coverage; generated/lock output and specs do not count toward scope-check. All writable implementation paths share the `plugins/slop-guard` module.

### Live upstream evidence (2026-11-23)

Commands run against npm, not inferred from the ticket:

- `npm view eslint-plugin-react versions --json` lists 7.37.5 as the newest published version; `npm view eslint-plugin-react dist-tags version peerDependencies engines --json` reports latest 7.37.5 with ESLint peer `^3 || ^4 || ^5 || ^6 || ^7 || ^8 || ^9.7`. ESLint 10 is excluded.
- All 11 published prereleases were queried individually with `npm view eslint-plugin-react@<version> peerDependencies --json`: 4.0.0-rc.0 and -rc.1 declare no peer metadata; the remaining prereleases accept only older ESLint majors. `next` is the historical 7.8.0-rc.0 with `^3.0.0 || ^4.0.0`. None supplies declared ESLint 10 compatibility; a historical missing peer declaration is not evidence of support.
- `npm view eslint time --json` confirms 10.0.0 published `2026-02-06T22:30:47.920Z` and 10.15.0 published `2026-11-13T21:33:34.115Z`. `npm view eslint@10.15.0 version engines --json` confirms Node `^20.19.0 || ^22.13.0 || >=24`.
- `npm view @eslint/js dist-tags --json`, `npm view @eslint/js@10.0.1 version peerDependencies engines --json`, and its `time` metadata confirm latest 10.0.1, ESLint peer `^10.0.0`, the same Node range, and publication `2026-02-06T22:34:56.290Z`. These are mature candidates, not permission to install an incompatible stack. Re-query exact versions, all selected peers, engines and publication dates when unblocked.

## Acceptance criteria

The rows below define the upgrade outcome, not claims that the blocked combination works today. Do not queue this draft until the open question is resolved and #78 has landed.

| id | actor | action | expected observable result | test |
|---|---|---|---|---|
| UC-1 | operator | install the shipped npm lock from a clean directory on a supported Node version using strict peers, strict engines and disabled lifecycle scripts | Installation exits 0 with no ERESOLVE, EBADENGINE or unmet/invalid peers, and no force/legacy-peer/override bypass; installed ESLint and `@eslint/js` are 10.x and ESLint matches `eslint-stack.version`. | integration |
| UC-2 | maintainer | audit every newly introduced direct/transitive package version against npm metadata | Every version has a registry publication timestamp at least seven days before a single recorded selection timestamp; exact selected versions, cutoff and peer/engine compatibility evidence are recorded in the lock rationale. Inherited pins are distinguished from introduced versions. | integration |
| UC-3 | operator | load and lint representative JS, TS, JSX, TSX and Node files with the shipped baseline, including typed mode with a valid temporary TypeScript project | Every enabled rule resolves and executes without missing-rule, removed-API, config or parser failures; explicit enabled rule names/options/severities remain unchanged except documented one-for-one ESLint 10 renames. | integration |
| UC-4 | operator | load and lint representative JS/TS inputs with the shipped security overlay | Every enabled overlay rule resolves and executes without configuration or plugin failures, with the existing explicit policy retained. | integration |
| UC-5 | operator | analyze the existing bad TypeScript eval fixture through the shipped hook with the installed bundle | Output contains `AP-TS-SEC-002`; a tool failure or empty output does not satisfy the assertion. | integration |
| UC-6 | operator | analyze the existing clean React fixture through the shipped hook with the installed bundle | Output contains no finding and the analyzer completes without config, parser or runtime errors; missing/failed execution cannot count as clean output. | integration |
| UC-7 | maintainer | run `SLOPGUARD_IT_REQUIRE=1 make tool-integration` with the pinned toolchain installed | The command exits 0, ESLint tests actually execute using the advertised pinned version, and no skipped tool is accepted as success. | integration |

## Non-functional

- Retain #78's supported Node range `^20.19.0 || ^22.13.0 || >=24`; a dependency demanding a narrower range requires an owner decision before approval, not a silent engine floor increase.
- No npm lifecycle scripts during lock generation or installation. Peer and engine checks remain enforced; unsupported peers are blockers even if a local smoke run happens to pass.
- Integration checks may use the real installed bundle; unit tests remain network-free. Every UC has a test name containing its stable `UC-<n>` id; do not weaken or quarantine existing assertions.
- Record any changed upstream recommended-preset behavior and exact React-plugin compatibility decision in the lock rationale and changelog. The current blocked state must never be described as a completed ESLint 10 migration.

## Open questions

- [ ] Owner: wait for a mature `eslint-plugin-react` release explicitly supporting ESLint 10, or authorize a maintained alternative? **Recommendation: wait**, keep the #78 ESLint 9.39.5 stack, and do not approve/queue this upgrade yet. The live stable/prerelease checks above provide no compatible candidate. Recheck upstream before approval; once a supporting stable release has aged seven days, record the selected version and decision in the lock rationale and resolve this checkbox. If the owner instead chooses an alternative, revise this draft with the chosen package, explicit old-to-new React rule/mapping equivalence and fixtures, then re-estimate/decompose before approval; do not let the implementation agent invent that migration.
