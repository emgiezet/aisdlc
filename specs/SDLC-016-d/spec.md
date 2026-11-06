---
ticket: SDLC-016-d
title: Replace literal /sdlc: invocations with the namespace placeholder
status: draft
stacks: [bash, instructions]
mechanical: true
depends-on: SDLC-016-c
---

# SDLC-016-d — Namespace placeholder migration (mechanical)

## Problem

With hosts reading the packaged tree, the 584 lines that hardcode `/sdlc:` across 89 authored
files are the last thing standing between this plugin and a second organisation installing it
under its own namespace (`docs/overlay-contract.md:31`). The change is one pattern applied
everywhere, so it ships alone and is reviewed by pattern, not line by line.

## Scope

In:
- Replace each literal `/sdlc:` invocation in authored sources — `plugins/sdlc/**`, the root
  `README.md`, `CLAUDE.md`, `Makefile`, `install.sh`, `docs/ai-sdlc.md`, `docs/overlay-contract.md`,
  `.claude/**` and the harness stubs — with the placeholder from `SDLC-016-a`.
- A check in `make validate` that fails when a literal default-namespace invocation reappears in
  the authored surface.

Out:
- Historical records: `specs/**`, `docs/plans/**`, `docs/research/**` keep their literals.
- The packager, generator and install path, which are `SDLC-016-a`, `-b` and `-c`.
- Any wording change beyond the substitution itself.
- Renaming the default namespace.

Change budget: 650 added lines, 95 files, 14 modules

The wide budget is for the mechanical substitution only (measured: 584 lines in 89 files across
14 modules, excluding the historical records above); replaced lines count as added.

## Context

- `plugins/sdlc/commands/*.md`, `plugins/sdlc/skills/*/SKILL.md`, `plugins/sdlc/templates/**` —
  most of the measured lines.
- `evals/harness/stub-claude` — strips the namespace from the prompt (`prompt="${prompt/sdlc:/}"`);
  it receives rendered prompts, so it must keep working unchanged.
- `plugins/sdlc/bin/aisdlc` — builds `/$PLUGIN_NAME:<phase>` prompts from the manifest already;
  no change expected, confirm it.
- `docs/overlay-contract.md` — mark the namespace row closed.
- Source spec: `specs/SDLC-016/spec.md`; plan: `specs/SDLC-016/decomposition.md`.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-2 | maintainer | packages the migrated sources with a different `name` in the manifest | every rendered invocation uses the new namespace, command suffixes and arguments unchanged, with no authored file edited | integration |
| UC-8b | maintainer | scans the authored surface after migration | no literal default-namespace invocation remains outside the historical records; `make validate` fails when one is added back | unit |
| UC-8e | maintainer | runs `make selftest` and `make eval-dry` on the packaged default tree | both pass unchanged: the stub and the queue see today's `/sdlc:<phase>` prompts | selftest |

## Open questions

- [ ] How examples that must show a literal command to a human (README quick start, install
  output) are written so the packaged text reads naturally.
