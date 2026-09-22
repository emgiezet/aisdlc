---
ticket: SDLC-006-b
title: Post-PR loop II — continue, merge, merge-buddy, followup, close-fixed, changelog
status: draft
stacks: [instructions]
---

# SDLC-006-b — Post-PR loop II: resume, merge, housekeeping

## Problem

A `BLOCKED.md`, a `changes-requested` review, or a crashed run leaves a worktree nobody re-enters.
Merging is a human decision, but the checks that precede it (label, verdict, CI, conflicts) are
mechanical and today done by eye. Post-merge, issues the PR fixed stay open, nits raised in review
evaporate, and the changelog is written from memory.

## Scope

In:
- `/sdlc:continue <ticket|pr#>`: resume from `BLOCKED.md`, a changes-requested review, or a PR with
  no plan; reconstruct remaining work; implement → qa.
- `/sdlc:merge <pr#> [--followup "<text>"]`: interactive-only gate check + approve + squash-merge.
- `/sdlc:merge-buddy`: read-only report of what can merge now and what is close.
- `/sdlc:followup <pr#> [<comment-url>|"<text>"]`: PR/comment → tracked issue.
- `/sdlc:close-fixed`: post-merge sweep.
- `/sdlc:changelog [--since <tag>]`: CHANGELOG entry from merged labelled PRs, shipped via
  `/sdlc:ship --docs`.

Out:
- Adding `merge` to `ALL_PHASES` or invoking it from any other command without `--allow-merge`.
- Release tagging, version bumps, publishing — the changelog PR is a docs PR, nothing more.
- Re-implementing review: `continue` and `merge` consume `/sdlc:review`'s verdict, never re-derive it.

## Context

- `specs/SDLC-005/spec.md` — operations `get-pr list-prs search-prs merge-pr review-pr
  create-issue close-issue comment-issue comment-pr get-pr-checks claim release`.
- `specs/SDLC-006-a/spec.md` — verdict tokens and labels `continue`/`merge` read.
- `plugins/sdlc/commands/implement.md` Phase 4 "Blocked" (`BLOCKED.md` shape `continue` parses)
  and Phase 2 (the UC loop `continue` re-enters from the first UC without a passing test).
- `plugins/sdlc/commands/ship.md` — `--docs` (SDLC-005 UC-7) used by `changelog`.
- `docs/ai-sdlc.md` § "What stays human" — merging is a recommendation until a person runs
  `/sdlc:merge`.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | developer | `/sdlc:continue <T>` in a worktree with `specs/<T>/BLOCKED.md` | the blocker's question is answered from the spec/codebase or the run stops with the same `BLOCKED.md` plus a `Still blocked because:` line; on success `BLOCKED.md` is deleted in the same commit as the first new UC test, and `/sdlc:qa` runs | e2e |
| UC-2 | developer | `/sdlc:continue <pr#>` on a PR labelled `changes-requested` | every actionable review finding becomes a checklist row in `specs/<T>/continue-plan.md`; each row is fixed and referenced from a commit; `qa` re-runs; report ends `PR: #<n> (<url>)` | e2e |
| UC-3 | developer | `/sdlc:continue <pr#>` on a PR with no spec and no plan (a human's branch) | goal reconstructed from title, body, comments, diff into `specs/<T>/spec.md` with `status: draft`, `kind: adopted`; the run stops there and asks for approval — never implements against a draft | e2e |
| UC-4 | release manager | `/sdlc:merge <pr#>` when the PR is `merge-ready`, checks green, no conflicts | approve + squash-merge via `merge-pr`; `--followup` files an issue through `create-issue` and links it in the merge comment; report ends `PR: #<n> (<url>)` and, with a follow-up, `Issue: #<m> (<url>)` | e2e |
| UC-5 | release manager | `/sdlc:merge <pr#>` when label is `changes-requested` or `blocked`, a required check is red, the head is conflicted, or the QA verdict has a blocking `GAPS` | refuses with exactly one line naming the first failing gate; nothing is mutated | e2e |
| UC-6 | release manager | `/sdlc:merge-buddy` | two tables — `Can merge now` and `Close but blocked (<reason>)` — from labels, verdict comment, `get-pr-checks`, mergeability; no mutation | e2e |
| UC-7 | developer | `/sdlc:followup <pr#> <comment-url>` | one issue created with the comment quoted, a link back to the PR, label from the profile, assignee = comment author when resolvable; the PR gets a comment `Filed as Issue: #<m>`; dedupe: an existing open issue linking the same comment is returned instead | e2e |
| UC-8 | developer | `/sdlc:close-fixed` | every issue referenced by `Fixes|Closes #n` in a merged labelled PR since the last run is closed with a comment naming the PR; issues referenced only by closed-unmerged PRs get a `PR closed without merge` comment; run watermark stored in `.aisdlc/close-fixed.json` | e2e |
| UC-9 | developer | `/sdlc:changelog --since v1.2.0` | `CHANGELOG.md` gains one entry grouping merged labelled PRs by conventional-commit type, crediting `git log` authors (never the merger); the entry is shipped with `/sdlc:ship --docs`; a second run with no new PRs says `nothing to release` | e2e |

## Non-functional

- `/sdlc:merge` has no `--force`; a failed gate is a human's problem by design.
- `continue` never rewrites history and never deletes a failing test — it reports it as the next
  blocker.
- `close-fixed` and `changelog` are idempotent: re-running with no new merges changes nothing.
- `make validate`, `make eval-dry` stay green.

## Open questions

- [ ] none
