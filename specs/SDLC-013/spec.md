---
ticket: SDLC-013
title: The queue's verify gate is never configured — init and update do not write `verify`, and add queues tasks certain to fail
status: draft
stacks: [bash, instructions]
---

# SDLC-013 — The queue's verify gate is never configured

## Problem

Since v0.9.0 the queue runs a `verify` phase before ship, and `run_verify` treats an absent or
empty `"verify"` list in `.aisdlc/config.json` as FAIL. Neither `/sdlc:init` nor `/sdlc:update`
writes that key, and `aisdlc add` does not check for it. A maintainer who sets a repo up exactly
as documented and queues an approved spec pays for implement, qa and scope-check, then watches
every task fail at verify with "no verify commands configured".

## Scope

In:
- `aisdlc add` refuses, before queueing, a task whose phases include `verify` when the repo's
  config has no non-empty `verify` list — naming the key and how to set it.
- `/sdlc:init` writes `verify` into `.aisdlc/config.json`, derived from the profile it just wrote.
- `/sdlc:update` proposes `verify` when the key is absent, derived the same way; never rewrites a
  present value.
- `verify` documented wherever the config keys are listed: the `aisdlc help` config example,
  the `docs/ai-sdlc.md` Queue configuration table.

Out:
- `run_verify` itself — its checks, report format and fail-closed semantics stay as they are.
- A run-time pre-check in `cmd_run`; tasks already queued without the key fail at verify as today.
- `--force` semantics for the spec gate; it keeps overriding draft specs and open questions only.
- `.claude/sdlc.md` template fields — `verify` is derived from fields that already exist.
- Any change to phase order, `ALL_PHASES`, `ISSUE_PHASES` or `model_roles`.

Change budget: 90 added lines, 6 files, 4 modules

## Context

- `plugins/sdlc/bin/aisdlc` — `run_verify` (reads `.verify // []`, FAIL when empty); `cmd_add`
  (spec gate via `check_spec`, `--phase/--phases`, `--no-pr`, `--issue`, `--force`; dies via
  `die`); `cmd_help` config example after "Write the config with /…:init, or by hand".
- `plugins/sdlc/commands/init.md` — Phase 3 bullet `.aisdlc/config.json — runner defaults: …`.
  At 217 of its 220-line budget: the addition must be paid for by tightening the same phase.
- `plugins/sdlc/commands/update.md` — `## Phase 4: Runner config and directories`, the key list
  and the "Add absent keys / never rewrite a value" rules.
- `plugins/sdlc/templates/sdlc.md` — `## Stacks and verification`: the stacks table
  (Lint / format, Types / static, Tests) and `One command that runs everything`. The source
  `verify` is derived from.
- `docs/ai-sdlc.md` — `## Queue configuration` table (Setting | Config key | Env | Default | Notes).
- `evals/harness/selftest.sh` — fixtures already write `{"verify":[…]}` (`# verify fails closed
  without commands, so every fixture carries one that passes`); the existing `aisdlc help
  documents model_roles` case is the pattern for UC-6.
- Vocabulary: `pipeline-contracts` (the profile's glossary skill).

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | maintainer | `aisdlc add <TICKET>` with an approved spec, config has no `verify` key or `"verify": []` | exit non-zero; stderr names `.aisdlc/config.json` and `"verify"`; `queue.jsonl` unchanged — one test case per variant | selftest |
| UC-2 | maintainer | same, config has `"verify": ["true"]` | task queued, as today | selftest |
| UC-3 | maintainer | UC-1 with `--force` | still refused — `--force` overrides the spec gate, not a gate certain to fail *(inferred)* | selftest |
| UC-4 | maintainer | `aisdlc add <TICKET> --phases implement,qa` with no `verify` key | task queued — the refusal applies only when `verify` is a phase *(inferred)* | selftest |
| UC-5 | maintainer | `aisdlc help` | output shows `verify` in the config example | selftest |
| UC-6 | maintainer | `/sdlc:init` on a repo whose profile sets `One command that runs everything` | `.aisdlc/config.json` has `"verify": ["<that command>"]` | live run (sandbox) |
| UC-7 | maintainer | `/sdlc:init` when that field is `none` | `verify` lists the stacks table's Lint, Types and Tests commands, row by row in that order, skipping `—`/`none` cells; no commands at all → `"verify": []` and the Phase 4 report says the queue will refuse tasks until it is set | live run (sandbox) |
| UC-8 | maintainer | `/sdlc:update` on a config without `verify` | the proposal lists `verify` with the UC-6/UC-7 derivation; a config that already has `verify` is left byte-identical in that key | live run (sandbox) |

## Non-functional

- Fail closed and early: the UC-1 refusal happens before any claim, worktree or model call.
- `init.md` stays ≤ 220 lines and `update.md` ≤ 220 (`make validate`).

## Open questions

- [ ] Should UC-1's message suggest a concrete value? Recommendation: yes — when the profile's
  `One command that runs everything` is set, print it as the suggested `verify` entry; the runner
  already reads the profile path from the repo. Confirm or strike before approval.
