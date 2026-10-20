# Scope report — GH-43-a

> **GAPS** — Some changed files were not declared in the spec scope.

Base: `origin/main`  
Checked: 2026-10-20T09:04:16Z

## File classification

| File | Classification |
|------|----------------|
| `docs/ai-sdlc.md` | in scope |
| `evals/harness/selftest.sh` | in scope |
| `evals/harness/stub-claude` | in scope |
| `evals/harness/stub-omp` | in scope |
| `plugins/sdlc/bin/aisdlc` | in scope |
| `specs/GH-43-a/qa-report.md` | **undeclared** |
| `specs/GH-43-a/qa/selftest.txt` | **undeclared** |
| `specs/GH-43-a/qa/validate.txt` | **undeclared** |
| `specs/GH-43-a/spec.md` | **undeclared** |

## Verdict

Verdict: GAPS

5 in scope · 4 undeclared · 0 out of bounds

## Size

| Measure | This branch | Budget |
|---|---|---|
| Added lines | 120 | 110 (hard ceiling 3000) |
| Files touched | 5 | 4 |
| Modules touched | 3 | 3 |

Modules: docs/ai-sdlc.md,evals/harness,plugins/sdlc

Generated output, vendored trees, lock files and the specs directory are
excluded; deleted lines never count against the budget.

### Findings

- over budget: 120 added lines > 110. One spec is one PR: split it (spec-authoring, Sizing)
- over budget: 5 files touched > 4
