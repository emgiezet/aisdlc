---
ticket: SDLC-005
title: Pipeline foundation — tracker and browser descriptors, chain markers, claim lock, review phase, issue queue
status: draft
stacks: [instructions, runner]
---

# SDLC-005 — Pipeline foundation

## Problem

The pipeline ends at a draft PR and starts at a spec. Everything that should happen after
`/sdlc:ship` (review, fix-forward, merge) and before `/sdlc:spec` (an issue arriving) has no place
to stand: `/sdlc:ship` and `aisdlc inbox` call `gh` directly, so a second tracker is a fork; there
is no shared vocabulary for a verdict, a chain hand-off, or a claim lock, so two agents on one repo
build the same branch; and the queue's phase list is fixed at `implement qa ship`. Slices
SDLC-006..010 each need these to exist once, identically, before they can be written.

## Scope

In:
- Tracker descriptor: operations named by commands, executed per `.claude/trackers/<kind>.md`.
  Shipped providers `github` and `local` (file-backed), plus `TEMPLATE.md`.
- Browser descriptor: `.claude/browsers/<provider>.md` naming `boot-check open goto click fill
  assert-text screenshot close`; shipped `playwright`, `agent-browser`, `TEMPLATE.md` as operation
  stubs — SDLC-009 fills their bodies.
- Profile keys in `templates/sdlc.md` and `/sdlc:init` questions writing them.
- Clean cutover of `/sdlc:ship` and `aisdlc inbox` to descriptor operations.
- Chain-marker, verdict-token and claim-lock contracts, stated once in
  `skills/pipeline-contracts/SKILL.md` and referenced by every later command.
- Queue: `review` phase after `ship`; `aisdlc add --issue <n>` with atomic claim.
- `/sdlc:ship --docs`: a docs-only branch ships without a spec.

Out:
- Any command from SDLC-006..010; this spec only lays the floor they stand on.
- Linear and Jira providers — `TEMPLATE.md` is the integration surface; nobody writes them here.
- Label taxonomy beyond four pipeline labels and one claim label (decision recorded in Context).
- Changing `guard`, `dense-testing`, `spec-authoring`, or the spec format.

## Context

- `plugins/sdlc/bin/aisdlc:28` `ALL_PHASES`; `:204` `cmd_add`; `:301` `invoke_claude`; `:324`
  `run_phase` (already fails on `num_turns == 0`); `:386` `execute_task` (`pr_url` extraction at
  `:456-459`); `:559` `cmd_inbox` (the `gh pr list` call to cut over).
- `plugins/sdlc/commands/ship.md` Phase 2 (`gh pr create/edit/comment`) and Phase 4 (offline
  handoff — becomes the `local` provider's normal path).
- `plugins/sdlc/templates/sdlc.md` § "Issue tracker" (`Kind: jira-mcp | github | none` — `Kind`
  becomes the descriptor selector; `jira-mcp` keeps working for `/sdlc:spec` reads only).
- `plugins/sdlc/commands/init.md` Phase 1 "Survey" and Phase 3 "Write".
- `evals/harness/selftest.sh` and `evals/harness/stub-claude` — the offline runner contract.
- `docs/overlay-contract.md` § "Generic work still to land" items 1, 4 — this spec closes them.
- Decisions taken in the design conversation (2026-09-22): tracker = descriptor (option 2); labels =
  minimal (`review`, `changes-requested`, `merge-ready`, `blocked`; claim `in-progress`); browser =
  descriptor with two shipped providers.
- Descriptor operation set (exact names, consumed by SDLC-006..010): `current-user`, `get-issue`,
  `search-issues`, `create-issue`, `comment-issue`, `close-issue`, `label-issue`, `unlabel-issue`,
  `assign-issue`, `get-pr`, `list-prs`, `search-prs`, `create-pr`, `update-pr`, `comment-pr`,
  `review-pr`, `merge-pr`, `get-pr-diff`, `get-pr-checks`, `get-run-failed-logs`, `checkout-pr`,
  `attach-image-evidence`, `claim`, `release`, `check-claim`.
- Chain markers: `PR: #<n> (<url>)`, `Issue: #<n> (<url>)` as the last lines of a report. Verdict
  tokens: `APPROVED|CHANGES_REQUESTED`, `NO_ACTION_NEEDED|BUG|FEATURE`, `LOW_CONFIDENCE`,
  `PASS|GAPS|BLOCKED` (existing).

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | developer | `/sdlc:init` on a repo with a GitHub remote | `.claude/sdlc.md` has `Tracker descriptor: .claude/trackers/github.md`, `Browser descriptor: none` (or the detected provider), `Pipeline labels: review, changes-requested, merge-ready, blocked`, `Claim label: in-progress`, `Briefs live in: specs/briefs/`; `.claude/trackers/github.md` exists and is byte-identical to the shipped template | e2e |
| UC-2 | developer | `/sdlc:init` on a repo with no remote or `gh` | descriptor is `.claude/trackers/local.md`; `.aisdlc/tracker/` is created; no `gh` call is attempted | e2e |
| UC-3 | ship phase | `/sdlc:ship <T>` under the `local` provider | PR body written to `specs/<T>/pr-body.md`, an entry appended to `.aisdlc/tracker/prs.jsonl` with `number`, `branch`, `label`, `verdict`; report ends with `PR: #<n> (<path>)` | e2e |
| UC-4 | ship phase | `/sdlc:ship <T>` under `github` | no literal `gh` in `ship.md` outside the descriptor reference; PR created draft, labelled, QA report commented, report ends with `PR: #<n> (<url>)` | unit |
| UC-5 | queue | `aisdlc add T && aisdlc run --once` with the stub claude | phases run `implement qa ship review` in order; `review.log` exists; `review` prompt is `/sdlc:review <pr#> --autofix` where `<pr#>` came from `task.json.pr_url`; `--no-pr` strips both `ship` and `review` | unit |
| UC-6 | queue | `aisdlc add --issue 42` under `local` | `claim` recorded on issue 42 (assignee, `in-progress`, `🤖 aisdlc claimed <ISO>` comment); task ticket is `GH-42`; phases are `triage root-cause implement qa ship review`; a second `add --issue 42` refuses with `already claimed` | unit |
| UC-7 | developer | `/sdlc:ship --docs` on a branch whose diff touches only `*.md`, `docs/**`, `CHANGELOG*` | PR opens without `specs/<T>/spec.md`; the same command on a branch touching any other path refuses with `--docs: non-doc files in diff: <list>` | e2e |
| UC-8 | maintainer | reading `skills/pipeline-contracts/SKILL.md` | one table each for descriptor operations, chain markers, verdict tokens, claim-lock signals and staleness (60 min), pipeline-label transitions; `make eval-dry` counts its trigger set | unit |

## Non-functional

- A descriptor is ≤ 120 lines and a command ≤ 220 lines, enforced by `make validate` from this
  spec onward (`harness-eval` § "Writing for the weakest model": the descriptor is read on every
  tracker call).
- `local` is not a mock: it is the provider a repo with no remote uses in production, and the one
  `make selftest` and `make harness-eval` run against. Its state lives under `.aisdlc/tracker/`
  and is gitignored by `/sdlc:init`.
- Every tracker mutation reads back what it wrote before the command proceeds (a failed label
  write must never be reported as success).
- `guard` still blocks `--force`/`--no-verify`; descriptors never grant them.

## Open questions

- [ ] none
