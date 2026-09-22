# aisdlc — an AI SDLC harness

A Claude Code plugin for delivering software where **agents write the code and people own the
specification**. It is spec-driven development with the emphasis moved: the spec is not a document
that aligns humans before they type, it is the input an agent executes without supervision.

Concretely, it gives you five things a bare `claude -p` does not have:

1. A **task router** so an agent loads the instructions for its task and nothing else.
2. A **spec format** whose acceptance criteria are observable, so they can be tested and traced.
3. A **gate-free pipeline** — approve once, then implement → verify → open a draft pull request.
4. **Guardrails that are enforced**, not requested: a session cannot finish having deleted or
   skipped a test.
5. An **eval harness** that measures whether all of this works on a cheap model, because if it only
   works on the expensive one, the harness is carrying none of the weight.

Status: **0.1.0.** The pipeline runs end to end on Haiku against the bundled sandbox: 10/10
assertions, $0.59, 5.4 minutes — a test per use case carrying its id, the API contract updated in
the same commit, zero skipped tests, and a QA verdict that was reached by starting the service and
checking it with `curl` rather than by trusting the tests. The full numbers, including which part
costs too much, are in [`docs/ai-sdlc.md`](docs/ai-sdlc.md).

## Install

```bash
git clone git@github.com:emgiezet/aisdlc.git ~/.local/share/aisdlc
```

In Claude Code:

```
/plugin marketplace add ~/.local/share/aisdlc
/plugin install sdlc@aisdlc
```

Put the queue runner on your `PATH`:

```bash
ln -s ~/.local/share/aisdlc/plugins/sdlc/bin/aisdlc ~/.local/bin/aisdlc
```

Requires `git` ≥ 2.31, `jq`, `flock`, and the `claude` CLI. `gh` is needed only for the `github`
tracker; without a remote tracker `/sdlc:init` selects the file-backed `local` provider and every
command still runs.

## Set up a repository

```
/sdlc:init
```

It surveys the repo — stacks, directories, the exact commands CI runs, test conventions, what kinds
of change the git history actually contains — proposes a router table for your approval, and then
writes `CLAUDE.md`, `.claude/playbooks/`, `.claude/rules/`, `.claude/sdlc.md` and
`.aisdlc/config.json` calibrated to *this* repository.

Run it in an interactive session. Claude Code will ask before writing under `.claude/` and will not
grant that to an unattended run — deliberately, since agent configuration is the last thing you want
rewritten silently. `--yes` skips this command's own review gate; it does not skip that approval.

That last point is the whole design: this framework deliberately ships **no** ready-made
conventions for your stack. Copying someone else's playbooks is what makes generic harnesses
useless. `make templates TARGET=…` will drop the raw templates in if you would rather fill them in
by hand.

## The loop

```
/sdlc:spec ABC-123      → specs/ABC-123/spec.md — a use-case table, status: draft
/sdlc:mockup ABC-123    → clickable single-file mockup, validated with whoever asked for it
   ↓ a human reads it, flips status: approved, commits it       ← the only approval point
aisdlc add ABC-123      → queued
aisdlc run --workers 3  → worktree per task; implement → qa → ship → review
aisdlc inbox            → draft pull requests, each with its QA verdict and review label
/sdlc:merge <pr#>       → a human's decision, gated on label, checks, conflicts, verdict
```

Or without the queue, one ticket at a time while you watch:

```
/sdlc:spec ABC-123 → /sdlc:implement ABC-123 → /sdlc:qa ABC-123 → /sdlc:ship ABC-123 → /sdlc:review <pr#>
```

From a bug report, the issue is the approval — a human labelled it `bug`:

```
/sdlc:fix-issue 42      → triage → root-cause → implement → qa → ship → review, one claim lock throughout
aisdlc add --issue 42   → the same chain, queued, with an atomic claim so two machines never build it twice
```

Before there is a ticket at all: `/sdlc:brainstorm`, `/sdlc:discover`, `/sdlc:synthetic-users`,
`/sdlc:backlog`, `/sdlc:ux-shape` — interactive, evidence-tagged, never queued.

### Why it holds together

- **The spec replaces the plan gate.** `/sdlc:implement` never asks a question: it resolves
  ambiguity from the spec and the codebase, or it stops and writes `BLOCKED.md`. Nothing runs until
  a human sets `status: approved` — checked when queueing, and again inside the worktree before the
  model is invoked.
- **Tests are the safety net, so they are dense.** Every `UC-<n>` gets a test carrying its id,
  which makes spec coverage a `grep` rather than a judgement call. A `Stop` hook blocks any session
  that deleted or skipped a test; a `PreToolUse` hook blocks force pushes and `--no-verify`.
- **QA runs before a human does.** The `auto-qa` agent re-derives the use cases from the spec
  *before* reading the implementation — read the code first and you agree with it. `PASS` or `GAPS`
  is the first line of the pull request.
- **Cost is bounded and recorded.** A per-phase spend cap, and the actual cost written to each
  task's record, so `$/PR` is a number you look up rather than estimate.

## What's included

### Commands

| Command | Purpose |
|---------|---------|
| `/sdlc:init` | Survey the repo and generate its router, playbooks, rules, profile, and the tracker/browser descriptors. Run once. `--discovery` adds a Definition of Ready. |
| `/sdlc:spec` | Turn a ticket, URL, file or description into `specs/<TICKET>/spec.md` with a use-case table. Adds the negative cases the ticket forgot; leaves `status: draft`. |
| `/sdlc:mockup` | Build a clickable single-file mockup from the spec's UI use cases — no build step, opens by double-clicking — including the empty, loading, error and denied states. |
| `/sdlc:implement` | The unattended build: refuses anything not `approved`, one playbook, a test carrying each `UC-<n>` id before its implementation, full CI matrix, `BLOCKED.md` rather than a broken finish. |
| `/sdlc:qa` | Independent verification: use cases re-derived from the spec, gaps closed, a browser pass with screenshots for UI use cases when a browser descriptor is configured, `qa-report.md` with a `PASS`/`GAPS` verdict. |
| `/sdlc:ship` | Non-interactive delivery: refuses on a blocking verdict, opens a **draft** pull request with the verdict and the riskiest changes up front, QA report as a comment, label `review`. `--docs` ships a documentation-only branch without a spec. |
| `/sdlc:review` | Reviews a PR spec-first in an isolated worktree: blocker/major/minor/nit findings, `APPROVED` or `CHANGES_REQUESTED`, pipeline label; on its own PRs an autofix loop — conflicts, then findings, then CI — with new commits only. |
| `/sdlc:continue` · `/sdlc:fix-pr` · `/sdlc:autopilot` · `/sdlc:review-prs` | Resume a blocked or changes-requested branch; drive one PR to `merge-ready` through review and CI stabilisation (never weakening a check); diagnose a PR's state and run the right chain; sweep every unreviewed PR. |
| `/sdlc:merge` · `/sdlc:merge-buddy` · `/sdlc:followup` · `/sdlc:close-fixed` · `/sdlc:changelog` | The human's merge, gated and interactive-only; a read-only mergeability report; a review nit turned into a tracked issue; the post-merge issue sweep; a changelog entry shipped as a docs PR. |
| `/sdlc:issue` · `/sdlc:triage` · `/sdlc:root-cause` · `/sdlc:fix-issue` | File or normalise an issue; decide `NO_ACTION_NEEDED`/`BUG`/`FEATURE` and write the bugfix spec from Expected/Actual; locate the minimal change surface; run the whole bug chain under one claim lock. |
| `/sdlc:brainstorm` · `/sdlc:discover` · `/sdlc:synthetic-users` · `/sdlc:backlog` · `/sdlc:ux-shape` · `/sdlc:ux-setup` | Discovery, before a spec exists: one question at a time, evidence-tagged product briefs, synthetic panels that never count as evidence, epics and stories filed through `/sdlc:issue`, a UX direction, the repo's design contract as a path-scoped rule. |
| `/sdlc:test-env` · `/sdlc:integration-tests` · `/sdlc:ux-review` | Boot the app portably and reuse it warm; write E2E tests against the running app with real locators; review a PR's UI against the design contract in a real browser. |
| `/sdlc:retro` | Classify finished runs, rank their causes by cost and wall-clock, and map each to the harness file that owns it. |

### Skills

| Skill | What it provides |
|-------|------------------|
| `spec-authoring` | The spec format: fixed sections plus a table of atomic, observably-testable criteria with stable ids. Sizing limits, anti-patterns, readiness checklist. |
| `task-router` | The three-tier instruction hierarchy — root router, task-scoped playbooks, path-scoped rules — with line budgets and how to diagnose a router that loads the wrong file. |
| `dense-testing` | Density floors per changed symbol, `UC-<n>` ids in test names, assert-on-observable-behaviour, and the non-negotiables the guard hook enforces. |
| `harness-eval` | How to measure the harness on a cheap model, and a table mapping each failure symptom to the instruction file that caused it. |
| `pipeline-contracts` | The vocabulary every command shares: tracker and browser descriptors and their operations, chain markers, verdict tokens, the claim lock, pipeline labels, the bugfix approval rule. |
| `code-review` | Severity scale, the verdict rule, the review checklist, and the five lenses of a specification review. |
| `discovery` | Brief and product-brief formats, evidence tags that never upgrade, the Definition of Ready. |

Plus the `auto-qa` and `code-reviewer` agents, the `guard` hook, `bin/aisdlc`, and the shipped
descriptors: trackers `github` and `local` (file-backed, works offline), browsers `playwright` and
`agent-browser`. A command never calls `gh` or a browser directly — it names an operation and the
descriptor your repo committed says how it runs, so a new tracker is one file, not a fork.

### The queue

```
aisdlc add <TICKET> [--model haiku] [--budget 3] [--no-pr]
aisdlc add --issue <n>                          # claims the issue, queues triage → … → review
aisdlc run [--workers 3] [--once]
aisdlc status | inbox | logs <id> | retry <id> | cancel <id> | clean
```

One git worktree per task, branched off the base ref, then one headless `claude -p` call per phase
with a fresh context each: `implement qa ship review`, or `triage root-cause implement qa ship
review` for an issue. Success removes the worktree and leaves a draft pull request with its review;
failure — including a review whose blockers autofix could not clear — keeps the worktree and the
logs, because that is the evidence. Defaults resolve as CLI flag > `.aisdlc/config.json` >
environment > built-in.

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
