# Scope report — GH-42-a

> **GAPS** — Some changed files were not declared in the spec scope.

Base: `origin/main`  
Checked: 2026-10-20T09:16:14Z

## File classification

| File | Classification |
|------|----------------|
| `plugins/slop-guard/configs/baseline/eslint.config.mjs` | in scope |
| `plugins/slop-guard/docs/decisions.md` | in scope |
| `plugins/slop-guard/rules/catalog.yaml` | in scope |
| `plugins/slop-guard/rules/mapping/eslint.yaml` | in scope |
| `plugins/slop-guard/tests/catalog_test.sh` | in scope |
| `plugins/slop-guard/tests/integration/fast.sh` | in scope |
| `.gitignore` | **undeclared** |
| `plugins/slop-guard/CHANGELOG.md` | **undeclared** |
| `plugins/slop-guard/skills/ts-react-antipatterns/SKILL.md` | **undeclared** |
| `plugins/slop-guard/skills/ts-react-antipatterns/reference/AP-TS-MAINT-005.md` | **undeclared** |
| `plugins/slop-guard/skills/ts-react-antipatterns/reference/AP-TS-MAINT-006.md` | **undeclared** |
| `plugins/slop-guard/tests/fixtures/ts/bad/AP-TS-MAINT-005.ts` | **undeclared** |
| `plugins/slop-guard/tests/fixtures/ts/bad/AP-TS-MAINT-006.ts` | **undeclared** |
| `plugins/slop-guard/tests/fixtures/ts/good/AP-TS-MAINT-005.ts` | **undeclared** |
| `plugins/slop-guard/tests/fixtures/ts/good/AP-TS-MAINT-006.ts` | **undeclared** |
| `plugins/slop-guard/tools/node/package-lock.json` | **undeclared** |
| `plugins/slop-guard/tools/node/package.json` | **undeclared** |
| `specs/GH-42-a/qa-report.md` | **undeclared** |
| `specs/GH-42-a/spec.md` | **undeclared** |

## Verdict

Verdict: GAPS

6 in scope · 13 undeclared · 0 out of bounds

## Size

| Measure | This branch | Budget |
|---|---|---|
| Added lines | 396 | 260 (hard ceiling 3000) |
| Files touched | 16 | 15 |
| Modules touched | 2 | 1 |

Modules: .gitignore,plugins/slop-guard

Generated output, vendored trees, lock files and the specs directory are
excluded; deleted lines never count against the budget.

### Findings

- over budget: 396 added lines > 260. One spec is one PR: split it (spec-authoring, Sizing)
- over budget: 16 files touched > 15
- over budget: 2 modules touched > 1 (.gitignore,plugins/slop-guard)
