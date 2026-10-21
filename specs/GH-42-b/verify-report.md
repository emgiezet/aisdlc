PASS

# Verify — GH-42-b

Base: `origin/main` (branch `emgiezet/next-issues-work`).

## Files changed (GH-42-b)

| File | Classification |
|------|----------------|
| `plugins/slop-guard/rules/catalog.yaml` | in scope |
| `plugins/slop-guard/rules/mapping/eslint.yaml` | in scope |
| `plugins/slop-guard/configs/baseline/eslint.config.mjs` | in scope |
| `plugins/slop-guard/tests/fixtures/ts/bad/AP-TS-MAINT-007.ts` | in scope |
| `plugins/slop-guard/tests/fixtures/ts/bad/AP-TS-MAINT-008.ts` | in scope |
| `plugins/slop-guard/tests/fixtures/ts/good/AP-TS-MAINT-007.ts` | in scope |
| `plugins/slop-guard/tests/fixtures/ts/good/AP-TS-MAINT-008.ts` | in scope |
| `plugins/slop-guard/tests/fixtures/ts/good/AP-TS-MAINT-005.ts` | in scope |
| `plugins/slop-guard/tests/fixtures/ts/good/AP-TS-MAINT-006.ts` | in scope |
| `plugins/slop-guard/tests/integration/fast.sh` | in scope |
| `plugins/slop-guard/skills/ts-react-antipatterns/SKILL.md` | in scope |
| `plugins/slop-guard/skills/ts-react-antipatterns/reference/AP-TS-MAINT-007.md` | in scope |
| `plugins/slop-guard/skills/ts-react-antipatterns/reference/AP-TS-MAINT-008.md` | in scope |
| `plugins/slop-guard/CHANGELOG.md` | in scope |

## Checks

| Check | Result | Evidence |
|---|---|---|
| bash plugins/sdlc/tests/run-tests | PASS | 83 passed, 0 failed |
| bash evals/harness/selftest.sh | PASS | all sections, 0 failed |
| CI= make validate | PASS | exit 0 |
| make tool-integration (pinned binaries) | PASS | 35 passed, 0 failed, 2 skips (missing tools), 1 known |
| CI shellcheck -S warning | PASS | clean after fixes |
| Real pinned eslint-stack | PASS | all MAINT-007/008 probes and good-fixture silence pass |
