# QA report — GH-78
Verdict: PASS

Checked draft `spec.md` and the upgraded bundle from `ca566027f0` against `9c912df`. Verification map: none. No UI UCs.

## UC coverage

| UC | Automated boundary | Observed |
|---|---|---|
| UC-1 | `qa/locked_bundle_test.py`, `GH-78 UC-1` | Fresh npm install under strict peer/engine rules and disabled lifecycle scripts installed all five target versions; ESLint reports `v9.39.5`, matching the tool lock |
| UC-2 | `qa/locked_bundle_test.py`, `GH-78 UC-2` | 55 introduced package versions checked against npm; newest `node-releases@2.0.62` at `2026-10-30T09:53:46.228Z`, before the cutoff |
| UC-3 | `plugins/slop-guard/tests/integration/fast.sh`, `GH-78 UC-3` | Shipped hook reported `AP-TS-SEC-002` on the bad TypeScript fixture with the managed bundle |
| UC-4 | `plugins/slop-guard/tests/integration/fast.sh`, `GH-78 UC-4` | Shipped hook reported no diagnostic on the clean React fixture with the managed bundle |

Coverage: 4/4 automated; no UC skipped. The baseline config is byte-for-byte unchanged from the base, and the lock retains the newer #77 pins for `typescript-eslint` and `eslint-plugin-no-unsanitized`.

## Test suites

Tiers (new tests): unit 0 / integration 2 / e2e 0. The install and publication audit require the real package manager and registry; the two hook checks are existing integration assertions tagged with UC IDs.

- `python3 specs/GH-78/qa/locked_bundle_test.py`: both checks passed under Node 24.0.2 / npm 11.19.0; npm emitted ESLint 9's upstream deprecation notice, not an engine or peer error.
- `plugins/slop-guard/bin/slopguard doctor --install --all`: managed ESLint 9.39.5 installed; all tools version-matched. This replaced an initial scratch lookup pointed at main's managed 9.35.0 wrapper, which correctly failed the branch version gate.
- `CI=true make validate`: passed; Slop Guard 725/0, SDLC 102/0, 25 config checks, zero skips/failures.
- `SLOPGUARD_IT_REQUIRE=1 SLOPGUARD_IT_DEBUG=1 make tool-integration`: 56 passed, 0 failed, 0 skipped, 2 known.
- `bash -n` and ShellCheck 0.11.0 `-S warning` passed on `plugins/slop-guard/tests/integration/fast.sh`.

## Findings

None blocking. ESLint 9 is deprecated upstream; ESLint 10 remains incompatible with the pinned React plugin. The PR keeps the shipped config and explicitly documents the hold decisions.

## Not verified

- Local installation was on Node 24.0.2, not each supported minor release. The npm package declares `^20.19.0 || ^22.13.0 || >=24`; remote CI is the separate Node 22 check.
- The existing zizmor bad checkout and Psalm taint quarantines remain known, not passing; neither covers this ticket. The fixture checks do not exhaustively measure upstream matching changes in each upgraded plugin.
