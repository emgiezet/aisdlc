# Scope report — GH-43-b

> **GAPS** — Some changed files were not declared in the spec scope.

Base: `origin/main`  
Checked: 2026-10-20T11:19:13Z

## File classification

| File | Classification |
|------|----------------|
| `README.md` | in scope |
| `docs/ai-sdlc.md` | in scope |
| `evals/harness/selftest.sh` | in scope |
| `evals/harness/stub-claude` | in scope |
| `plugins/sdlc/bin/aisdlc` | in scope |

## Verdict

Verdict: GAPS

5 in scope · 0 undeclared · 0 out of bounds

## Size

| Measure | This branch | Budget |
|---|---|---|
| Added lines | 452 | 360 (hard ceiling 3000) |
| Files touched | 5 | 4 |
| Modules touched | 4 | 4 |

Modules: README.md,docs/ai-sdlc.md,evals/harness,plugins/sdlc

Generated output, vendored trees, lock files and the specs directory are
excluded; deleted lines never count against the budget.

### Findings

- over budget: 452 added lines > 360. One spec is one PR: split it (spec-authoring, Sizing)
- over budget: 5 files touched > 4
