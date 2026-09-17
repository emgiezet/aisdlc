# aisdlc — an AI SDLC harness

A plugin for Claude Code, Codex, and Grok that delivers software where **agents write the code and
people own the specification**. It is spec-driven development with the emphasis moved: the spec is
not a document that aligns humans before they type, it is the input an agent executes without
supervision.

Concretely, it gives you five things a bare agent invocation does not have:

1. A **task router** so an agent loads the instructions for its task and nothing else.
2. A **spec format** whose acceptance criteria are observable, so they can be tested and traced.
3. A **gate-free pipeline** — approve once, then implement → verify → open a draft pull request.
4. **Guardrails that are enforced**, not requested: a session cannot finish having deleted or
   skipped a test.
5. An **eval harness** that measures whether all of this works on a cheap model, because if it only
   works on the expensive one, the harness is carrying none of the weight.

The unattended queue (`aisdlc run`) requires the `claude` CLI. The interactive workflow skills
work on all three hosts.

Status: **0.1.0.** The pipeline runs end to end on Haiku against the bundled sandbox: 10/10
assertions, $0.59, 5.4 minutes — a test per use case carrying its id, the API contract updated in
the same commit, zero skipped tests, and a QA verdict that was reached by starting the service and
checking it with `curl` rather than by trusting the tests. The full numbers, including which part
costs too much, are in [`docs/ai-sdlc.md`](docs/ai-sdlc.md).

## Install

Clone the repository:

```bash
git clone git@github.com:emgiezet/aisdlc.git ~/.local/share/aisdlc
```

**Claude Code**

```
/plugin marketplace add ~/.local/share/aisdlc
/plugin install sdlc@aisdlc
```

**Codex**

```bash
codex plugin marketplace add ~/.local/share/aisdlc
```

Then open the Plugins Directory in the Codex UI, choose the aisdlc marketplace, and install sdlc.

**Grok**

Add the marketplace source to `~/.grok/config.toml`:

```toml
[[marketplace.sources]]
type = "local"
path = "/home/you/.local/share/aisdlc"
```

Then open the Marketplace tab (`/plugins`), browse aisdlc, and select sdlc.

Grok also reads the Claude Code marketplace automatically, so the plugin is available once the
`.claude-plugin/marketplace.json` path is reachable.

**Queue runner** (requires the `claude` CLI):

```bash
ln -s ~/.local/share/aisdlc/plugins/sdlc/bin/aisdlc ~/.local/bin/aisdlc
```

`aisdlc run` starts headless `claude -p` sessions. It does not work with Codex or Grok.

Runtime requirements: `git` ≥ 2.31, `jq`, `flock`, and the `claude` CLI for the queue. `gh` is
optional — without it the ship step writes the pull request body to a file instead of opening a
draft.

## Set up a repository

Start an interactive session in the repository you want to use.

| Host | Command |
|------|---------|
| Claude Code | `/sdlc:init` |
| Codex | `$init` |
| Grok | `/init` |

The init skill surveys the repo — stacks, directories, the exact commands CI runs, test
conventions, what kinds of change the git history actually contains — proposes a router table for
your approval, and then writes `CLAUDE.md`, `AGENTS.md` (Codex adapter), `.claude/playbooks/`,
`.claude/rules/`, `.claude/sdlc.md` and `.aisdlc/config.json` calibrated to *this* repository.

At the setup gate it also lists any optional capability plugins it detects in the current
environment, proposes integrations, and records the selections in the project profile. Installation
of those plugins is left to you.

Run it in an interactive session. Claude Code will ask before writing under `.claude/` and will
not grant that to an unattended run — deliberately, since agent configuration is the last thing
you want rewritten silently.

This framework ships **no** ready-made conventions for your stack. Copying someone else's playbooks
is what makes generic harnesses useless. `make templates TARGET=…` will drop the raw templates in
if you would rather fill them in by hand.

## The loop

```
/sdlc:spec ABC-123      → specs/ABC-123/spec.md — a use-case table, status: draft
/sdlc:mockup ABC-123    → clickable single-file mockup, validated with whoever asked for it
   ↓ a human reads it, flips status: approved, commits it       ← the only approval point
aisdlc add ABC-123      → queued
aisdlc run --workers 3  → worktree per task; implement → qa → ship
aisdlc inbox            → draft pull requests, each with its QA verdict on the first line
```

Commands above use Claude Code syntax (`/sdlc:<skill>`). On Codex, use `$<skill>` (e.g. `$spec`,
`$implement`). On Grok, use `/<skill>` (e.g. `/spec`, `/implement`).

Or without the queue, one ticket at a time while you watch:

| Claude Code | `/sdlc:spec` → `/sdlc:implement` → `/sdlc:qa` → `/sdlc:ship` |
|-------------|--------------------------------------------------------------|
| Codex       | `$spec` → `$implement` → `$qa` → `$ship` |
| Grok        | `/spec` → `/implement` → `/qa` → `/ship` |

### Why it holds together

- **The spec replaces the plan gate.** `/sdlc:implement` never asks a question: it resolves
  ambiguity from the spec and the codebase, or it stops and writes `BLOCKED.md`. Nothing runs until
  a human sets `status: approved` — checked when queueing, and again inside the worktree before the
  model is invoked.
- **Tests are the safety net, so they are dense.** Every `UC-<n>` gets a test carrying its id,
  which makes spec coverage a `grep` rather than a judgement call. On Claude and Codex, a `Stop`
  hook blocks any session that deleted or skipped a test; on Grok, where Stop hooks are passive,
  the same check runs as an advisory warning (findings printed to stderr, exit 0 — Grok can only
  block from PreToolUse). A `PreToolUse` hook blocks force pushes and `--no-verify` on all hosts.
- **QA runs before a human does.** The `auto-qa` agent re-derives the use cases from the spec
  *before* reading the implementation — read the code first and you agree with it. `PASS` or `GAPS`
  is the first line of the pull request.
- **Cost is bounded and recorded.** A per-phase spend cap, and the actual cost written to each
  task's record, so `$/PR` is a number you look up rather than estimate.

## What's included

### Skills

**Workflow skills** (invokable as `/sdlc:<name>` on Claude Code, `$<name>` on Codex, `/<name>` on Grok):

| Skill | Purpose |
|-------|---------|
| `init` | Survey the repo and generate its router, playbooks, rules and profile. Run once. |
| `spec` | Turn a ticket, URL, file or description into `specs/<TICKET>/spec.md` with a use-case table. Adds the negative cases the ticket forgot; leaves `status: draft`. |
| `mockup` | Build a clickable single-file mockup from the spec's UI use cases — no build step, opens by double-clicking — including the empty, loading, error and denied states. |
| `implement` | The unattended build: refuses anything not `approved`, one playbook, a test carrying each `UC-<n>` id before its implementation, full CI matrix, `BLOCKED.md` rather than a broken finish. |
| `qa` | Independent verification: use cases re-derived from the spec, gaps closed, `qa-report.md` with a `PASS`/`GAPS` verdict. A new test that fails is a finding, never a silent fix. |
| `ship` | Non-interactive delivery: refuses on a blocking verdict, opens a **draft** pull request with the verdict and the riskiest changes up front, QA report as a comment. |

**Knowledge skills** (loaded on demand by the model):

| Skill | What it provides |
|-------|------------------|
| `spec-authoring` | The spec format: fixed sections plus a table of atomic, observably-testable criteria with stable ids. Sizing limits, anti-patterns, readiness checklist. |
| `task-router` | The three-tier instruction hierarchy — root router, task-scoped playbooks, path-scoped rules — with line budgets and how to diagnose a router that loads the wrong file. |
| `dense-testing` | Density floors per changed symbol, `UC-<n>` ids in test names, assert-on-observable-behaviour, and the non-negotiables the guard hook enforces. |
| `harness-eval` | How to measure the harness on a cheap model, and a table mapping each failure symptom to the instruction file that caused it. |

Plus the `auto-qa` agent, the `guard` hook, and `bin/aisdlc`.

### The queue

```
aisdlc add <TICKET> [--model haiku] [--budget 3] [--no-pr]
aisdlc run [--workers 3] [--once]
aisdlc status | inbox | logs <id> | retry <id> | cancel <id> | clean
```

One git worktree per task, branched off the base ref, then three headless `claude -p` calls with a
fresh context each. Success removes the worktree and leaves a draft pull request; failure keeps the
worktree and the logs, because that is the evidence. Defaults resolve as CLI flag >
`.aisdlc/config.json` > environment > built-in.

**The queue is Claude-only.** `aisdlc run` spawns `claude -p` and has no Codex or Grok equivalent.
The interactive workflow skills are the multi-host path.

## Suggested companions

All four are optional and independently installed. The `init` skill detects which are present,
proposes integrations at its setup gate, and records the result in the project profile. Absent
companions fall back to AISDLC's own instructions; nothing breaks.

| Companion | Role in the flow | Install |
|-----------|-----------------|---------|
| **Slop Guard** | Deterministic policy enforcement via PreToolUse/Stop hooks: supply-chain blocks, credential guards, linter-suppression gates, hard-coded secret detection. AISDLC never calls it directly; hooks fire at the tool boundary. | bundled in `plugins/slop-guard/` — Claude Code: `/plugin install slop-guard@aisdlc`; Codex: install from the aisdlc marketplace; Grok: select slop-guard in `/plugins` |
| **Superpowers** | Planning, TDD, debug, and review disciplines contributed by matching skill triggers. AISDLC falls back to its own instructions when absent. | [obra/superpowers](https://github.com/obra/superpowers) — Claude Code: `/plugin install superpowers@claude-plugins-official`; Codex: browse the official Codex plugin marketplace for Superpowers; Grok: `grok plugin install superpowers@xai-official --trust` |
| **Ponytail** | Implementation minimalism checks and over-engineering review during `implement` and `qa` phases. AISDLC falls back to its own instructions when absent. | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) — Claude Code: `/plugin marketplace add DietrichGebert/ponytail` then `/plugin install ponytail@ponytail`; Codex: `codex plugin marketplace add DietrichGebert/ponytail && codex plugin add ponytail@ponytail`; Grok: `grok plugin install DietrichGebert/ponytail --trust` |
| **Headroom** | Context compression and cross-agent memory at the transport layer. AISDLC never invokes Headroom; it wraps whichever agent you run. Not a plugin — install separately and wrap: `headroom wrap claude` / `headroom wrap codex` / `headroom wrap grok`. | [headroomlabs-ai/headroom](https://github.com/headroomlabs-ai/headroom) — `uv tool install "headroom-ai[all]"` or `pip install "headroom-ai[all]"` |

## Try it without risking a real repo

```bash
make sandbox                                     # hermetic Go + JavaScript repo in the temp dir
cd /tmp/aisdlc-sandbox && make verify            # baseline must be green
aisdlc add SBX-1 --repo /tmp/aisdlc-sandbox --model haiku --no-pr --plugin-dir
aisdlc run --repo /tmp/aisdlc-sandbox --once
aisdlc logs <id>                                 # read what it actually did
```

## Development

```bash
make validate       # manifests, required files, instruction budgets, shellcheck
make selftest       # 17 assertions over the queue runner, using a stub claude — no API calls
make eval-dry       # skill trigger sets, structural check only
make harness-eval MODEL=haiku [SCENARIO=go-endpoint]   # the real thing; costs money
```

`make selftest` is the one to run after touching `bin/aisdlc`. It exists because a real run once
found that `claude` consumes stdin, which silently ate the queue's phase list — the kind of defect
no amount of reading catches.

## Licence

Proprietary — copyright © 2026 Maksymilian Małecki, all rights reserved. Using, copying,
modifying or redistributing any part of this requires written consent. See [`LICENSE`](LICENSE).
