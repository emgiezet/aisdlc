---
ticket: GH-68
title: Ship portable Slop Guard skill frontmatter
status: draft
stacks: [bash, slop-guard catalogue]
---

# GH-68 — Ship portable Slop Guard skill frontmatter

## Problem

Strict skill hosts reject Slop Guard's shared skill metadata. The generated `agent-discipline` description contains a YAML-significant colon, and both generated and hand-written skills carry host-specific fields that prevent discovery in omp.

## Scope

In:
- Metadata for the catalogue-generated and hand-written Slop Guard skills, including the host-specific metadata tradeoffs.
- Offline validation of generated and shipped skills, the PyYAML prerequisite for local validation and CI, and documentation of description-based discovery and explicit agent delegation.

Out:
- Changes to AP definitions, analyzer behavior, hook routing, or the security review agent's tool permissions.
- A second host-specific copy of the skills, or live model calls in the regression suite.

Change budget: 250 added lines, 15 files, 6 modules

## Context

- [PR #68](https://github.com/emgiezet/aisdlc/pull/68) — portability decision and original parsing failure.
- `plugins/slop-guard/scripts/gen-skills` — catalogue generation; `plugins/slop-guard/skills/` — shipped skills.
- `plugins/slop-guard/evals/skill-frontmatter.py`, `plugins/slop-guard/tests/catalog_test.sh` — offline compatibility checks.
- `.github/workflows/validate.yml` — pinned PyYAML installation; `plugins/slop-guard/agents/security-reviewer.md` — read-only review agent.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|---|---|---|---|---|
| UC-1 | maintainer | generate catalogue skills in a clean output directory | Every skill has valid portable metadata, including a string-valued `agent-discipline` description despite its YAML-significant punctuation. | integration |
| UC-2 | maintainer | run the offline evaluator against shipped skills | Every shipped skill, including `deslop` and `secure-review`, has valid portable metadata and a name matching its directory. | integration |
| UC-3 | maintainer | evaluate a skill with a field reserved to one host | The evaluator exits nonzero and identifies the invalid skill and unexpected field. | integration |
| UC-4 | maintainer | regenerate from an unchanged catalogue | Generated skill files are byte-for-byte unchanged. | integration |

## Open questions

None.
