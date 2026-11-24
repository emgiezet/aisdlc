# QA report — GH-78
Verdict: PASS

Checked approved `spec.md` and branch head `d49c148` (scratch worktree) against `origin/main` (`8622492`), passed as the UC-2 diff base. Verification map: none. No UI UCs.

## UC coverage

| UC | Test boundary | File:line | Observed |
|---|---|---|---|
| UC-1 | `specs/GH-78/qa/locked_bundle_test.py`, `test_uc_1_strict_locked_install` | `specs/GH-78/qa/locked_bundle_test.py:18` | Fresh `npm ci --ignore-scripts --strict-peer-deps --engine-strict` in a temp copy of `plugins/slop-guard/tools/node` installed all five exact target versions; ESLint reports `v9.39.5`, matching `tools/tools.lock.json` `eslint-stack.version`. |
| UC-2 | `specs/GH-78/qa/locked_bundle_test.py`, `test_uc_2_publication_cutoff` | `specs/GH-78/qa/locked_bundle_test.py:47` | 55 introduced package versions (new vs. `origin/main`) were checked against npm; newest `node-releases@2.0.62` published at `2026-10-30T09:53:46.228Z`, before the cutoff `2026-10-30T09:56:41Z`. |
| UC-3 | `plugins/slop-guard/tests/integration/fast.sh`, `it_expect_ap AP-TS-SEC-002` | `plugins/slop-guard/tests/integration/fast.sh:57` | Managed ESLint 9.39.5 via `slopguard doctor` reported `AP-TS-SEC-002` on `tests/fixtures/ts/bad/eval.ts`. |
| UC-4 | `plugins/slop-guard/tests/integration/fast.sh`, `it_expect_silent` | `plugins/slop-guard/tests/integration/fast.sh:67` | Managed ESLint 9.39.5 produced no finding on `tests/fixtures/ts/good/sample.tsx`. |

Coverage: 4/4 automated; no UC skipped.

## Suite output (observed)

```
$ python3 specs/GH-78/qa/locked_bundle_test.py origin/main
added 292 packages in 2s
GH-78 UC-1: installed all five exact versions; ESLint reports v9.39.5
GH-78 UC-2: 55 introduced versions within hold; newest node-releases@2.0.62 at 2026-10-30T09:53:46.228000+00:00

$ cd plugins/slop-guard && bash bin/slopguard doctor --install
  eslint-stack  managed bundle metadata changed; reinstalling...
  added 292 packages in 2s
    → refreshed eslint-stack 9.39.5
  ...
  All tools present and version-matched.

$ cd plugins/slop-guard && CLAUDE_PLUGIN_DATA=/home/mgz/.local/share/claude/plugins/slop-guard ./tests/tool-integration
--- fast.sh ---
  ok    ruff: SQL injection (bad fixture -> AP-PY-SEC-001)
  ok    ruff: clean Python (good fixture -> silence)
  ok    GH-78 UC-3: eslint eval with user input (bad fixture -> AP-TS-SEC-002)
  ok    GH-78 UC-4: eslint clean React component (good fixture -> silence)
  ok    hadolint: FROM ubuntu:latest (bad fixture -> AP-DOCKER-001)
  ok    hadolint: compliant Dockerfile (good fixture -> silence)
  ok    kube-linter: privileged container (bad fixture -> AP-K8S-001)
  ok    kube-linter: compliant deployment (good fixture -> silence)
  ok    zizmor: SHA-pinned workflow (good fixture -> silence)
  ...
--- medium.sh ---
  skip  phpstan: no binary (lockfile name: phpstan)
  ok    golangci-lint: gosec G201 (fmt.Sprintf SQL) → AP-GO-SEC-002
  ok    golangci-lint: parameterised query produces no finding
  ok    tflint: missing required_version → AP-TF-MAINT-003
  ok    tflint: versioned module produces no finding
  ok    checkov (M): S3 without event notifications → AP-TF-SEC-018
  ok    checkov (M): compliant TF produces no finding
  ok    opengrep: as unknown as T → AP-TS-MAINT-001
  ...
--- opengrep.sh ---
  ...
--- stop.sh ---
  skip  psalm: no binary (lockfile name: psalm)
  ok    checkov stop-gate: CKV_AWS_57 dir scan → AP-IaC-SEC-001
  ok    checkov stop-gate: compliant TF produces no finding

211 passed, 0 failed, 2 skipped, 1 known

$ cd plugins/slop-guard && ./tests/run-tests
725 passed, 0 failed

$ make validate
725 passed, 0 failed
=== Slop Guard: baseline config validation ===
PASS  golangci-lint
SKIP  PHPStan (tool not installed)
SKIP  Psalm (tool not installed)
PASS  ruff
PASS  ESLint
PASS  tflint
PASS  Checkov
PASS  kube-linter (checks list)
PASS  kube-linter (lint fixtures)
PASS  hadolint
PASS  zizmor
...
23 validated, 2 skipped (not validated — tools absent), 0 failed
```

Note: the two skips (`phpstan`, `psalm`) are unrelated to GH-78 (no PHP tools installed locally). ESLint validation passed.

## Tiers (new tests)

- unit: 0
- integration: 2 (the existing `fast.sh` assertions are re-tagged with GH-78 UC IDs; no new test files added)
- e2e: 0

## Findings

None. All four acceptance criteria pass.

## Not verified

- Installation on unsupported Node versions (Node 20, Node 22 < 22.18, Node 23) was not tested; the spec states EBADENGINE is expected there, not a regression.
- Exhaustive measurement of each upgraded plugin's upstream matching changes (the spec says "upstream matching semantics may tighten" and the baseline rule names are unchanged; only the existing fixture contracts were exercised).
- CI `SLOPGUARD_IT_REQUIRE=1` will treat the PHP-tool skips as failures if `make tool-integration` is run without installing PHP tooling; that is a pre-existing environment gap, not a GH-78 gap.
