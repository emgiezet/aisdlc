---
ticket: GH-93
title: Upgrade the pinned Opengrep engine to 2.0.0 without fixture regressions
status: draft
depends-on: GH-65-b GH-65-c GH-65-d GH-65-e
stacks: [slop-guard catalogue, bash]
---

# GH-93 — Opengrep 2.0.0 cutover

Source: https://github.com/emgiezet/aisdlc/issues/93 (no comments at authoring).

## Problem

Slop Guard's Opengrep pin is 1.30.0 while an eligible newer major is available. Operators need the upgraded engine to retain every existing rule's bad-fixture detection and good-fixture silence, rather than silently lose findings when CLI or parser behavior changes. The upgrade must build on the completed GH-65 fixture repairs, not absorb that stack's existing defects.

## Scope

In:
- Change only the Opengrep entry of `plugins/slop-guard/tools/tools.lock.json` to **2.0.0**, including all four existing platform URLs and locally recomputed SHA-256 values. Preserve the lock schema, platform keys and executable name.
- Record the release's publication/eligibility evidence, asset-name migration and invocation audit in `plugins/slop-guard/tools/tools.lock-rationale.md`; add an Unreleased entry to `plugins/slop-guard/CHANGELOG.md`.
- Preserve the complete post-GH-65 per-rule fixture contract and production-path bad/good checks. Permit only rule, fixture or invocation compatibility repairs demonstrated to be caused by the engine upgrade, with the pre-upgrade behavior retained.
- Retain the existing negative runner checks and attach `GH-93 UC-<n>` names to coverage for this upgrade without removing the stable GH-65 UC labels.
- Land **after GH-65-b/#80, GH-65-c/#81, GH-65-d/#82 and GH-65-e/#83**. Rebase implementation onto their merged result; every dependency must have its required PASS verify-report in the base tree before queue/run.

Out:
- Repairing or replacing the GH-65 stack itself; implementing this ticket on the current C#-only fixture gate.
- An intermediate release pinned to 1.33.1: it is mature, but 2.0.0 is already the newest eligible release verified for this spec. No automatic fallback to 1.33.1 or a floating future release if 2.0.0 fails.
- New detectors, new rule/AP IDs, changes to existing IDs or AP bindings, catalogue/mapping changes, generated skills, or weakening detection semantics to obtain green fixtures.
- Enabling interfile analysis, changing scan scope/ignore policy, adding `--enable-interfile`, restoring `--metrics`, using `install-ci`, or introducing Python packaging for Opengrep. Other tools' Python dependencies remain untouched.
- Other analyzer pins, dependency locks, tool resolution/installation redesign, timeouts, production fail-open policy, retry/fallback infrastructure, hook-contract changes, CI or Makefile changes, manifests and version fields.
- Deleting, skipping, quarantining, relabelling as known-failing, or reducing any rule/fixture assertion; editing the eval sandbox; broad rule or fixture cleanup unrelated to an observed 2.0.0 regression.

Estimate: 30 metadata/changelog lines, 100 compatibility/negative-test lines, and 130 lines reserved for narrowly evidenced parser fallout; 6 metadata/test paths plus at most 8 affected rule/fixture paths, all within `plugins/slop-guard`. Read-only verification references below are not planned edits. Compared with `1f67172` (#77: 14 changelog + 3 integration-wrapper additions, 65 lock-entry additions), `fb8989e` (#91: 16 changelog + 2 requirements additions, 47 tool-lock additions), and `e9b14ca` (#78: 2 manifest + 2 rationale additions, 159 npm-lock additions), the allowance is deliberately larger than a mechanical pin refresh. Locks and specs are excluded from counted additions under the profile. The C# repair precedent `9c912df` illustrates why existing GH-65 repairs are prerequisites rather than part of this budget. No fixture suite was run while authoring; unknown fallout is not evidence that every rule pack needs rewriting. Keep the engine pin and its green fixture gate atomic: shipping a broken pin before a separate fixture-fallout slice is not an independently shippable decomposition. If measured post-stack fallout exceeds this estimate, use `/sdlc:decompose GH-93` and obtain approval for revised draft slices before implementation expands; never narrow coverage to fit.

Change budget: 260 added lines, 14 files, 1 modules

## Context

- `plugins/slop-guard/tools/tools.lock.json` — `.tools.opengrep`, currently `version: 1.30.0`, `bin: opengrep`; platform keys `linux-amd64`, `linux-arm64`, `darwin-arm64`, `darwin-amd64`.
- `plugins/slop-guard/tools/tools.lock-rationale.md` — “Version bump procedure”, “7-day publication rule”; `plugins/slop-guard/CHANGELOG.md` — Unreleased.
- `plugins/slop-guard/lib/dispatch.sh::_dispatch_run_opengrep` — `scan --config <bundled-rules> [--config <project-rules>] --json --quiet`, JSON fields `.results[].check_id`, `.extra.message`, `.start.line`, `.extra.metadata.ap_id`, prefix stripping and mapping emission. Read-only unless an actual incompatibility is demonstrated.
- `plugins/slop-guard/lib/tools.sh::tool_version_output`, `tool_version_matches`, `resolve_tool`, and `tests/tool-integration::it_skip_unless_tool` — version inspection and real-tool selection. `it_skip_unless_tool` can fall back to PATH, so green output alone does not prove which version ran. Read-only references, not permission to refactor these helpers.
- `plugins/slop-guard/tests/integration/opengrep.sh` — copied-fixture scan with `scan --json --no-rewrite-rule-ids --config <whole-rule-directory>` and error-free JSON gate. Read both the merged file and its whole-ruleset/variant assertions introduced by GH-65-e; the author inspected the stack-tail version on `origin/fix/gh65-5-react-laravel`, not just main's C# subset.
- `plugins/slop-guard/tests/integration/medium.sh` — `_og_ts_setup`, the `opengrep-bad`/`opengrep-good` hook cases and bare-ID mapping assertion; `plugins/slop-guard/tests/tool-integration` — `it_ok`, `it_bad`, required-tool gate; `Makefile` — `tool-integration` target. Preserve these contracts.
- `plugins/slop-guard/rules/opengrep/csharp.yaml` — `slopguard.cs.*` syntax/regex rules; `plugins/slop-guard/rules/opengrep/python.yaml` — `slopguard.py.django-raw-sql-format`, `slopguard.py.sqlalchemy-text-fstring`; stack-tail `rules/opengrep/react.yaml` — `slopguard.react.href-js-scheme` and `slopguard.ts.double-cast`. The merged GH-65-e integration discovery determines the full rule/AP/fixture set; these examples do not limit coverage.
- `.claude/sdlc.md` — catalogue/bash commands and change budget; `plugins/sdlc/bin/aisdlc::check_depends_on` — whitespace-separated dependency tokens, each requiring a `verify-report.md` whose first line is `PASS`.

### Verified upstream decisions (2026-11-23)

- GitHub `releases/latest` and `releases/tags/v2.0.0` both identify **v2.0.0**, published **2026-11-13T13:14:27Z**; the seven-day hold elapsed **2026-11-20T13:14:27Z**. [Release notes](https://github.com/opengrep/opengrep/releases/tag/v2.0.0) document Python removal, interfile opt-in, removed `install-ci`, hidden unsupported flags, parser changes and changed scan-error exit ordering.
- GitHub `releases/tags/v1.33.1` reports **2026-10-29T10:22:46Z**, eligible since November 5; [release notes](https://github.com/opengrep/opengrep/releases/tag/v1.33.1) cover Python-CLI ASP.NET extension handling. It was considered, but is not a necessary intermediate because v2.0.0 is mature and all flags actually passed remain supported.
- The v2 release assets replace `opengrep_manylinux_x86` / `opengrep_manylinux_aarch64` with **`opengrep_linux_x86` / `opengrep_linux_aarch64`**. Darwin assets remain **`opengrep_osx_x86` / `opengrep_osx_arm64`**. Map these to the existing four platform keys; do not add Windows support or pin signature/certificate assets as executables.
- Downloaded the v2.0.0 Linux x86 asset and executed `--version` → `2.0.0` and `scan --help`. Supported flags found: **`--config`** (explicitly repeatable), **`--json`**, **`--quiet`**, **`--no-rewrite-rule-ids`**. These cover every active Opengrep invocation found under `lib`, `hooks`, `bin` and the integration scan. The generic resolver's **`--version`** was exercised successfully. No flag migration is currently indicated; hidden-flag warning suppression is not a compatibility fix. `--enable-interfile` exists but remains deliberately unused.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | pin maintainer | verifies the updated Opengrep lock entry against release metadata and locally downloaded assets | version is exactly `2.0.0`; all four immutable URLs select the platform binaries named above; each stored SHA-256 equals the locally computed download digest; publication is at least seven days old; unrelated lock entries are unchanged | integration |
| UC-2 | operator | installs and resolves Opengrep in a fresh plugin-only tool-data directory | installation succeeds, and the resolved executable's `--version` is `2.0.0`, without a Python package/install step for Opengrep | integration |
| UC-3 | integration runner | scans the copied bad-fixture tree with pinned 2.0.0 and the entire merged rule directory | every dynamically discovered rule ID matches its own AP-bound bad fixture and every previously required adversarial variant; missing own-rule hits identify the rule and fail | integration |
| UC-4 | integration runner | scans the copied good-fixture tree with the same complete ruleset | every discovered rule ID has zero results anywhere under `good/`; each false positive identifies the rule and fails | integration |
| UC-5 | hook operator | runs the medium-tier production hook on the existing bad TypeScript double-cast fixture using pinned 2.0.0 | output includes `AP-TS-MAINT-001` and `[opengrep:slopguard.ts.double-cast]`, proving a real scan and bare-ID mapping rather than a swallowed CLI error | integration |
| UC-6 | hook operator | runs the same hook on the existing good TypeScript schema-boundary fixture | no Opengrep finding is emitted | integration |
| UC-7 | integration runner | receives an unsuccessful or unusable scan outcome (nonzero exit, malformed JSON, absent results, or nonempty errors) | the OpenGrep fixture gate reports a failure rather than counting it as a successful empty scan; each corrupt outcome has a named test case **(added negative regression case)** | unit |
| UC-8 | required-tool runner | runs without a resolvable Opengrep binary and without a PATH substitute under `SLOPGUARD_IT_REQUIRE=1` | the required-tool run exits nonzero and reports the missing/skipped tool, never a successful zero-coverage run **(added negative regression case)** | unit |

## Non-functional

- Preserve GH-65's copied-tree strategy, dynamic rule enumeration, exact rule/AP binding, cross-good-fixture silence, adversarial variants and scan/JSON/error checks. Keep existing UC IDs and label coverage for this ticket `GH-93 UC-<n>`; no reduced counts or manual allowlist substitutes.
- Recompute **all four** asset hashes from local downloads, not upstream digest strings. Hash verification is required for every platform; execution on platforms unavailable to QA must be explicitly marked not verified, never inferred from the Linux result.
- For implementation/QA, use fresh tool data and `CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=plugin-only`; record the resolved Opengrep executable and version before running the real suite so stale 1.30.0 PATH binaries cannot supply evidence. Provision the other pinned analyzers with `plugins/slop-guard/bin/slopguard doctor --install --all` before `SLOPGUARD_IT_REQUIRE=1 make tool-integration`; require exit 0, zero failed, zero skipped and no new known failures. Retain existing unrelated quarantine policy unchanged; none may cover an Opengrep regression. Run the profile's affected catalogue/bash gates, including `plugins/slop-guard/tests/run-tests`, `plugins/slop-guard/scripts/gen-skills --check`, `plugins/slop-guard/scripts/validate-configs`, and `bash plugins/slop-guard/tests/catalog_test.sh`.
- No fixture suite or repository validation was run to author this spec; the upstream version/help inspection establishes CLI flag availability only, not parser, JSON-output or fixture compatibility. The implementing agent must establish those results against the merged dependency stack.
- The real engine, downloaded asset digests and production hook behavior cannot be proved with fake scan results. If new unit tests do not outnumber new integration tests, the QA report must record that engine-upgrade-specific density exception; negative runner cases can use controlled local stubs without replacing real-engine coverage.

## Open questions

none
