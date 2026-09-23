---
ticket: SDLC-011
title: Model roles — cheap models for mechanical work, one table, every host
status: draft
stacks: [instructions, bash]
---

# SDLC-011 — Model roles

## Problem

Every phase of an `aisdlc` run costs the same. `aisdlc add --model sonnet` pins one model to a
task, and `run_phase` hands it to `claude -p` for `implement`, `qa`, `scope-check`, `ship` and
`review` alike — so pushing a branch and filling a PR template bills at the rate of writing the
code. The same holds interactively: `/sdlc:close-fixed` and `/sdlc:changelog` are `gh` calls and a
template, run on whatever model the session happens to hold.

The hosts do have the surface for this — Claude Code resolves a subagent's model from its
frontmatter, omp additionally resolves `@role` aliases through `modelRoles` — but the harness
names no roles, so nothing routes.

## Scope

In:
- A three-role vocabulary (`smol`, `default`, `slow`) with a fixed phase→role and command→role
  mapping, expressed once in `.aisdlc/config.json` as `model_roles`.
- `bin/aisdlc`: per-phase model resolution, snapshotted into `task.json` at `add` time.
- One new agent, `sdlc-scribe`, for the read-heavy collection steps, shipping a concrete cheap
  model.
- Delegation of the collection step in `close-fixed`, `merge-buddy` and `changelog`, conditional
  on `model_roles` being configured. The caller keeps every mutation and every gate.
- An opt-in omp example at `plugins/sdlc/templates/omp/config.yml`.

Out:
- Touching `agents/auto-qa.md` or `agents/code-reviewer.md` frontmatter — two downstream overlay
  plugins depend on today's behaviour, and a silent quality change in QA or review is a breaking
  change.
- Any default that changes behaviour without a human first writing `model_roles`. Absent key =
  today's behaviour, byte for byte.
- Generating per-repo copies of shipped agents into `.claude/agents/`: that is a fork by another
  name (`docs/overlay-contract.md` § "What an overlay owns").
- Per-role environment variables (`AISDLC_MODEL_SMOL` and friends).
- Making omp a prerequisite. `@role` aliases are an omp convenience over the concrete names, never
  the canonical form.
- Delegating template rendering rather than collection. The caller has to relay the rendered text
  anyway, so it moves no tokens out of the expensive context and adds a round trip — `followup`,
  whose only read is one comment, therefore delegates nothing.

## Context

- `plugins/sdlc/bin/aisdlc`: `ALL_PHASES="implement qa scope-check ship review"`,
  `ISSUE_PHASES="triage root-cause implement qa scope-check ship review"` (l. 28–29);
  `resolve_default` precedence flag > `.aisdlc/config.json` > env > built-in (l. 87);
  `cmd_add` builds `task.json` with `jq -n` (l. 602); `run_phase` reads `.model` from `task.json`
  (l. 686) and `invoke_claude` logs `(model %s, budget $%s)` (l. 671).
- `plugins/sdlc/agents/`: two agents, both `model: sonnet`, dispatched only by `/sdlc:qa` and
  `/sdlc:review`.
- omp resolves a subagent's model as `task.agentModelOverrides[name]` → frontmatter `model` →
  parent session model; an unresolvable selector falls through to the parent model
  (`omp://task-agent-discovery.md` § "Model and structured-output precedence").
- Claude Code resolves a subagent's model from frontmatter only; there is no per-dispatch override
  and no role indirection. Codex and Grok expose no subagent model surface at all.
- `docs/overlay-contract.md` — what an overlay may rely on.
- `evals/harness/selftest.sh` and `evals/harness/stub-claude` — the runner's test rig; the stub
  already receives `--model`.

## Role table

| Role | Queue phases | Commands delegating to `sdlc-scribe` |
|---|---|---|
| `smol` | `scope-check`, `ship` | `close-fixed`, `merge-buddy`, `changelog` |
| `default` | `implement`, `qa`, `triage` | — |
| `slow` | `review`, `root-cause` | — |

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | maintainer | `.aisdlc/config.json` without `model_roles`; `aisdlc add ABC-1 --model sonnet` | `task.json` carries `model: "sonnet"` and no `models` key; every phase invokes `claude --model sonnet`, and each `*.log` header reads `(model sonnet` | selftest |
| UC-2 | maintainer | config `{"model_roles":{"smol":"haiku","slow":"opus"}}`; `aisdlc add ABC-1 --model sonnet` | `task.json.models` maps every phase of that task: `scope-check`/`ship` → `haiku`, `review` → `opus`, `implement`/`qa` → `sonnet` | selftest |
| UC-3 | runner | `aisdlc run --once` on the UC-2 task | `ship.log` header reads `(model haiku`, `review.log` reads `(model opus`, `implement.log` reads `(model sonnet`; the stub records the same three values | selftest |
| UC-4 | maintainer | config `{"model_roles":{"smol":"haiku"}}` (partial) | roles with no entry resolve to the task's `model`; no warning, no failure; `models` still covers every phase | selftest |
| UC-5 | maintainer | edits `model_roles` after `add`, before `run` | the queued task runs on the snapshot in `task.json.models`; the edit affects only tasks added afterwards | selftest |
| UC-6 | maintainer | `aisdlc help` | the config section documents `model_roles`, its three role names, and the phase→role table | selftest |
| UC-7 | agent, repo with `model_roles` configured | `/sdlc:close-fixed`, `/sdlc:merge-buddy`, `/sdlc:changelog` | the collection step is dispatched to `sdlc-scribe`, which returns a compact record and mutates nothing; the artefacts the command writes and the tables it prints are unchanged from the non-delegating path | e2e |
| UC-8 | agent, repo without `model_roles` | the same three commands | no dispatch happens; the collection runs inline exactly as today | e2e |
| UC-9 | omp user | copies `plugins/sdlc/templates/omp/config.yml` to `<repo>/.omp/config.yml` | `sdlc-scribe`, `auto-qa` and `code-reviewer` resolve through `modelRoles`; without the file the shipped frontmatter decides and nothing breaks | manual |
| UC-10 | maintainer of an overlay plugin | updates the plugin, changes no configuration | `agents/auto-qa.md` and `agents/code-reviewer.md` are byte-identical to the previous release; no command delegates; no `task.json` gains a `models` key | selftest + diff |

## Non-functional

- `sdlc-scribe` ships `model: haiku` — a concrete name, not an alias, so Claude Code works with no
  configuration and omp degrades to the parent model when no Anthropic model is available.
- `model_roles` values are opaque strings passed to the host (`haiku`, `gpt-5-mini`,
  `openai/gpt-5.4`); the harness never interprets them.
- No new environment variable, no new config file: one optional key in an existing one.
- `docs/ai-sdlc.md` gains a `model_roles` row in the configuration table and a host-support row
  stating plainly that Codex and Grok have no subagent model surface, so roles reach only the
  queue there — which is Claude-only.
- `make validate`, `make eval-dry`, `make selftest` stay green.

## Open questions

None.
