---
ticket: SDLC-016-c
title: Hosts install the packaged plugin tree instead of the authored sources
status: draft
stacks: [bash, instructions]
depends-on: SDLC-016-b
---

# SDLC-016-c — Install from the packaged tree

## Problem

Authored sources can only carry a placeholder once no host reads them directly. Today every
marketplace points at `./plugins/sdlc`, and `install.sh` links `plugins/sdlc/bin/aisdlc`, so an
unrendered placeholder would reach users verbatim. This slice moves every install path onto the
packaged tree while the sources are still literal, so nothing visible changes yet.

## Scope

In:
- Each generated marketplace's sdlc `source` resolves to the packaged tree from `SDLC-016-a`.
- `install.sh` and the `--plugin-dir` paths in `plugins/sdlc/bin/aisdlc` and
  `evals/harness/run.sh` load the packaged tree, so the queue and the eval test what users get.
- A clean checkout gets a packaged tree before install, as decided in `SDLC-016-a`.

Out:
- The packager and its `--check`, which are `SDLC-016-a`.
- The marketplace generator, which is `SDLC-016-b`.
- Any edit to authored command text, which is `SDLC-016-d`.
- The slop-guard plugin's install path.

Change budget: 150 added lines, 8 files, 6 modules

## Context

- `.claude-plugin/marketplace.json` (`"source": "./plugins/sdlc"`) and the other three host
  marketplaces — regenerated through `SDLC-016-b`, never edited by hand.
- `install.sh` — links `plugins/sdlc/bin/aisdlc` into `~/.local/bin`.
- `plugins/sdlc/bin/aisdlc` — `--plugin-dir` handling in `cmd_add` and `invoke_omp`
  (`args+=(--plugin-dir "$PLUGIN_ROOT" …)`).
- `evals/harness/run.sh` — `aisdlc add … --plugin-dir` in the scenario loop.
- Makefile `validate` — the cross-marketplace block that checks each `source.path` resolves.
- Source spec: `specs/SDLC-016/spec.md`; plan: `specs/SDLC-016/decomposition.md`.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-8a | maintainer | runs `make validate` after packaging | every host's sdlc source path resolves into the packaged tree and the existing cross-marketplace checks pass | integration |
| UC-8c | maintainer | runs `make selftest` | every queued phase loads the plugin from the packaged tree (the stub records the `--plugin-dir` it was given); the suite stays green | selftest |
| UC-8d | maintainer | installs from a clean checkout following `install.sh` | the packaged tree is produced first and `aisdlc` resolves to its `bin/`; no step reads `plugins/sdlc/` directly | integration |

## Open questions

- [ ] Whether local development keeps a direct `plugins/sdlc` path for speed, and how that is
  kept from shipping.
