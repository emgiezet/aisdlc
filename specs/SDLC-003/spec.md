---
ticket: SDLC-003
title: Host a second plugin in this marketplace, without duplicating its guards
status: draft
stacks: [runner, instructions]
---

# SDLC-003 — Host a second plugin in this marketplace, without duplicating its guards

## Problem

`docs/slop-guard-spec.md` specifies a second plugin — Slop Guard — that installs
beside `sdlc` from this marketplace. Three things in this repository assume exactly one plugin
and break on the second: `make validate` hardcodes `plugins/sdlc/…` paths and three literal file
lists, `make bump-*` rewrites a single `.version` plus a marketplace-wide `.metadata.version`, and
CI checks version consistency for `sdlc` only. Worse, the two plugins' hooks overlap: both bind
`PreToolUse(Bash)` and `Stop`, and both block force pushes, `--no-verify` and test removal
(`plugins/sdlc/hooks/guard`, spec §7.1, §7.2D). Two plugins emitting `exit 2` for the same act
gives the agent two contradicting reasons for one block. And the queue runs headless with
`--permission-mode bypassPermissions`, where a hook's `ask` decision has no human to answer it.

## Scope

In:
- Marketplace and validation support for a second plugin in `plugins/`, with independent
  versioning.
- A stated hook-ownership boundary between `sdlc`'s `guard` and Slop Guard, with the
  duplicate checks removed from exactly one side.
- The rule for what the second plugin's policies do inside the aisdlc queue, where nobody can
  answer `ask`.

Out:
- Implementing Slop Guard itself — `docs/slop-guard-spec.md` is its spec and
  `docs/plans/2026-09-16-slop-guard.md` is its plan.
- Restructuring `make validate`'s existing `sdlc` checks.
- Any policy or organisation vocabulary in this repository (`docs/overlay-contract.md`).

## Context

- `Makefile:4-12` — `PLUGIN_JSON`, `MARKETPLACE_JSON`, `SCRIPTS`, `COMMANDS`, `SKILLS`,
  `PLAYBOOKS`; `:18-69` — the `validate` target; `:124-140` — `bump-*` and `_bump`, which selects
  `.plugins[] | select(.name == "sdlc")` and also writes `.metadata.version`.
- `.claude-plugin/marketplace.json:10-18` — `plugins[]`, today a single entry.
- `.github/workflows/validate.yml` — "Version consistency" (sdlc only) and "Framework stays
  project-agnostic" (greps the whole repo, `docs/` included).
- `plugins/sdlc/hooks/hooks.json` — `SessionStart`, `PreToolUse(Bash)`, `Stop` bindings.
- `plugins/sdlc/hooks/guard:33-46` — force push and `--no-verify`; `:84-148` — the `Stop` check
  for deleted and skipped tests.
- `plugins/sdlc/bin/aisdlc:124-150` — the headless permission set; `bypassPermissions` is passed
  at `:302-319`.
- `docs/overlay-contract.md:78-79` — "Portable mechanical guards, each driven by a project
  configuration file rather than by hardcoded paths."
- `docs/slop-guard-spec.md` §7.1, §7.2, §4.3, §12 (D9).

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | maintainer | `make validate` with a second directory under `plugins/` | the second plugin's `.claude-plugin/plugin.json` is parsed, its name matches its `marketplace.json` entry, and its version matches — failing any of the three fails the target | integration |
| UC-2 | maintainer | `make validate` with `plugins/sdlc` unchanged | every existing `sdlc` check still runs and passes; no existing check is relaxed to accommodate the second plugin | integration |
| UC-3 | maintainer | `make bump-minor` | only the `sdlc` plugin's version changes; the second plugin's version is untouched | integration |
| UC-4 | maintainer | `make bump-slopguard VERSION=0.2.0` | only the second plugin's `plugin.json` and its `marketplace.json` entry change | integration |
| UC-5 | agent session | `git push --force` with both plugins installed | exactly one block message is produced, naming one plugin | e2e |
| UC-6 | agent session | adding `t.Skip(` to a test file, then ending the turn | exactly one `Stop` block, from `sdlc`'s `guard`, quoting the dense-testing non-negotiables | e2e |
| UC-7 | queue phase | a policy whose decision is `ask`, running under `bypassPermissions` with no human | the decision is resolved without stalling — recorded and downgraded, never left pending — and the phase's outcome is still decided by its own exit status | integration |
| UC-8 | reader | `.github/workflows/validate.yml` | the project-agnostic grep passes on the whole repository, `docs/` included | unit |

## Non-functional

- `make validate`, `make selftest` and `make eval-dry` stay green with only `plugins/sdlc`
  present: the second plugin's absence is not an error, because this repository must remain
  installable on its own (`docs/overlay-contract.md`).
- No check may be duplicated across the two plugins' hooks. One owner per act, stated in both
  plugins' documentation.

## Open questions

- [ ] none
