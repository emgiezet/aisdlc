# Scope report — GH-44

> **GAPS** — Some changed files were not declared in the spec scope.

Base: `origin/main`  
Checked: 2026-10-20T09:31:38Z

## File classification

| File | Classification |
|------|----------------|
| `README.md` | in scope |
| `docs/ai-sdlc.md` | in scope |
| `evals/harness/selftest.sh` | in scope |
| `plugins/sdlc/bin/aisdlc` | in scope |
| `plugins/sdlc/commands/review.md` | in scope |
| `plugins/sdlc/skills/code-review/SKILL.md` | in scope |
| `plugins/sdlc/templates/sdlc.md` | in scope |
| `plugins/sdlc/tests/run-tests` | in scope |
| `plugins/sdlc/tests/structure_test.sh` | in scope |
| `evals/harness/stub-claude` | **undeclared** |
| `evals/harness/stub-lizard` | **undeclared** |
| `specs/GH-44/qa-report.md` | **undeclared** |
| `specs/GH-44/spec.md` | **undeclared** |

## Verdict

Verdict: GAPS

9 in scope · 4 undeclared · 0 out of bounds

## Size

| Measure | This branch | Budget |
|---|---|---|
| Added lines | 710 | 540 (hard ceiling 3000) |
| Files touched | 11 | 9 |
| Modules touched | 4 | 4 |

Modules: README.md,docs/ai-sdlc.md,evals/harness,plugins/sdlc

Generated output, vendored trees, lock files and the specs directory are
excluded; deleted lines never count against the budget.

### Findings

- over budget: 710 added lines > 540. One spec is one PR: split it (spec-authoring, Sizing)
- over budget: 11 files touched > 9
