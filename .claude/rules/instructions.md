---
paths:
  - "plugins/sdlc/commands/**"
  - "plugins/sdlc/skills/**"
  - "plugins/sdlc/agents/**"
  - "plugins/sdlc/templates/**"
---

# Instruction files — commands, skills, agents, templates

These are read by a cheap model running unattended in a repository nobody here has seen.

## Conventions observed here

- Frontmatter on line 1. Command: `description:` (with "Use when/after") and `allowed-tools:`.
  Skill: `name:` and `description: >` with a literal "Use when" sentence. Agent: `name`,
  `description`, `tools`, `model`.
- Imperative, exact: a command with its flags, a named operation (**get-pr**), a named verdict
  token — never "check the PR" or "make sure tests pass".
- Tables over prose. `##` sections in skills (no `###`); depth goes in `references/*.md`.
- Tracker and browser access only through descriptor operations from `pipeline-contracts`; no
  direct `gh` or browser calls in a command.
- Link the owning skill instead of restating its rule (severity → `code-review`, UC format →
  `spec-authoring`, density → `dense-testing`, vocabulary → `pipeline-contracts`).
- Paths and numbers from the code are quoted by symbol (`BUILTIN_WORKERS`, `run_verify`), not by
  line number — lines move on every release.
- Templates are project-agnostic: `<NAME>`-style placeholders, no example company or product;
  CI greps the whole tree for leaked project names.
- Tracker/browser descriptors are copied verbatim into user repos; a new operation lands in
  `TEMPLATE.md` and every concrete descriptor in the same change.

## Budgets (enforced by `make validate`)

| File | Limit |
|---|---|
| `commands/*.md` | 220 lines |
| `templates/playbooks/*.md` | 70 lines |
| `templates/{trackers,browsers,verify}/*.md` | 120 lines |
| `templates/CLAUDE.md` | 90 lines |
| `skills/*/SKILL.md` | no hard gate; house range 85–141 lines |

## Verification

```bash
CI= make validate        # frontmatter, required files, registration, budgets, descriptor TODOs
make eval-dry            # every skill's trigger set
```
