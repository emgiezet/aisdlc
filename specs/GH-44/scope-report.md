# Scope report — GH-44

> **GAPS** — Some changed files were not declared in the spec scope.

Base: `origin/main`  
Checked: 2026-10-20T10:36:45Z

## File classification

| File | Classification |
|------|----------------|
| `README.md` | in scope |
| `docs/ai-sdlc.md` | in scope |
| `evals/harness/selftest.sh` | in scope |
| `evals/harness/stub-claude` | in scope |
| `plugins/sdlc/bin/aisdlc` | in scope |
| `plugins/sdlc/commands/review.md` | in scope |
| `plugins/sdlc/skills/code-review/SKILL.md` | in scope |
| `plugins/sdlc/templates/sdlc.md` | in scope |
| `plugins/sdlc/tests/run-tests` | in scope |
| `plugins/sdlc/tests/structure_test.sh` | in scope |

## Verdict

Verdict: GAPS

10 in scope · 0 undeclared · 0 out of bounds

## Size

| Measure | This branch | Budget |
|---|---|---|
| Added lines | 839 | 760 (hard ceiling 3000) |
| Files touched | 10 | 11 |
| Modules touched | 4 | 4 |

Modules: README.md,docs/ai-sdlc.md,evals/harness,plugins/sdlc

Generated output, vendored trees, lock files and the specs directory are
excluded; deleted lines never count against the budget.

### Findings

- over budget: 839 added lines > 760. One spec is one PR: split it (spec-authoring, Sizing)
