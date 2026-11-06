---
ticket: SDLC-016-b
title: Generate the four host marketplaces from one metadata source
status: draft
stacks: [bash, instructions]
depends-on: SDLC-016-a
---

# SDLC-016-b — Generated host marketplaces

## Problem

Four `marketplace.json` files repeat the same plugin names, descriptions, versions and skill
lists in four host schemas, kept in step by hand and by `make validate` noticing drift after
the fact. Every release edits three or four of them. One source and a generator remove the
drift instead of detecting it.

## Scope

In:
- One authoritative metadata source for what the marketplaces share; each host's projection
  keeps its own schema: `source` string, `source.path`, `source.type`, policy, category,
  interface and keywords fields where that host has them today.
- The packager from `SDLC-016-a` generates `.claude-plugin/marketplace.json`,
  `.agents/plugins/marketplace.json`, `.grok-plugin/marketplace.json` and
  `.omp-plugin/marketplace.json`; its `--check` also fails when a committed marketplace differs
  from what the source generates.
- `make bump-*` updates the source and regenerates; the version-consistency checks in
  `make validate` keep passing on the generated files.

Out:
- The namespace placeholder and the packaged command tree, which are `SDLC-016-a`.
- Changing any host's install source to the packaged tree, which is `SDLC-016-c`.
- The literal `/sdlc:` migration, which is `SDLC-016-d`.
- Adding a host, or changing a host schema beyond reproducing today's fields.

Change budget: 350 added lines, 10 files, 6 modules

## Context

- `.claude-plugin/marketplace.json`, `.omp-plugin/marketplace.json` — string `source`,
  versions, the sdlc `skills` array (the two arrays must stay identical).
- `.agents/plugins/marketplace.json` — `source.path`, policy, category, interface fields.
- `.grok-plugin/marketplace.json` — `source.type`/`source.path`, category, keywords.
- `Makefile` — `MARKETPLACE_JSON`, `CODEX_MARKETPLACE`, `GROK_MARKETPLACE`, `OMP_MARKETPLACE`,
  the cross-marketplace consistency block in `validate`, and `bump-patch|minor|major|slopguard`.
- `.claude/playbooks/release-ci.md` — the release procedure that today edits the manifests.
- Source spec: `specs/SDLC-016/spec.md`; plan: `specs/SDLC-016/decomposition.md`.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-3 | maintainer | generates all host marketplaces from the source | all four files parse, each keeps its host-specific source shape and required fields, the plugin inventory is unchanged, and the generated files match today's committed ones byte for byte | unit |
| UC-4 | maintainer | changes one shared value (a description) in the source and regenerates | every host projection carrying that field shows the new value; no generated file was edited by hand | unit |
| UC-4a | maintainer | edits one committed marketplace by hand and runs `--check` | non-zero exit naming that file as stale | selftest |
| UC-4b | maintainer | runs `make bump-patch` | the source version moves and all four marketplaces regenerate with it; `make validate` stays green | integration |

## Open questions

- [ ] Where the shared source lives (a new file, or the existing plugin manifests).
- [ ] Whether host-only fields live in the source per host, or in per-host templates.
