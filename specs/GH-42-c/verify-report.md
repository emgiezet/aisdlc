PASS

# Verify — GH-42-c

Base: `origin/main` (branch `emgiezet/next-issues-work`).

## Files changed (GH-42-c)

| File | Classification |
|------|----------------|
| `plugins/slop-guard/rules/catalog.yaml` | in scope |
| `plugins/slop-guard/rules/mapping/eslint.yaml` | in scope |
| `plugins/slop-guard/configs/baseline/eslint.config.mjs` | in scope |
| `plugins/slop-guard/tests/fixtures/ts/bad/AP-TS-PERF-005.ts` | in scope |
| `plugins/slop-guard/tests/fixtures/ts/bad/AP-TS-MAINT-009.ts` | in scope |
| `plugins/slop-guard/tests/fixtures/ts/good/AP-TS-PERF-005.ts` | in scope |
| `plugins/slop-guard/tests/fixtures/ts/good/AP-TS-MAINT-009.ts` | in scope |
| `plugins/slop-guard/tests/integration/fast.sh` | in scope |
| `plugins/slop-guard/skills/ts-react-antipatterns/SKILL.md` | in scope |
| `plugins/slop-guard/skills/ts-react-antipatterns/reference/AP-TS-PERF-005.md` | in scope |
| `plugins/slop-guard/skills/ts-react-antipatterns/reference/AP-TS-MAINT-009.md` | in scope |
| `plugins/slop-guard/tests/catalog_test.sh` | in scope |
| `plugins/slop-guard/CHANGELOG.md` | in scope |

## Checks

| Check | Result | Evidence |
|---|---|---|
| bash plugins/sdlc/tests/run-tests | PASS | 83 passed, 0 failed |
| bash evals/harness/selftest.sh | PASS | all sections, 0 failed |
| CI= make validate | PASS | exit 0 |
| make tool-integration (pinned binaries) | PASS | 35 passed, 0 failed, 2 skips (missing tools), 1 known |
| CI shellcheck -S warning | PASS | clean after fixes |
| Real pinned eslint-stack | PASS | PERF-005 bad/good and MAINT-009 bad/good pass |
