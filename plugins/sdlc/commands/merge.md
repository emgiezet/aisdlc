---
description: Interactive-only merge gate — checks pipeline label, CI status, conflicts, and QA verdict before approving and squash-merging; refuses with one line on the first failing gate and never forces a merge. Use after /sdlc:review returns APPROVED, from a terminal session only.
allowed-tools: Bash, Read, Grep, Glob, SlashCommand
---

# /sdlc:merge

`$ARGUMENTS` is `<pr#> [--followup "<text>"]`.

This command is **interactive-only**. It is not in `ALL_PHASES` and is never invoked
automatically by any other command — the only exception is `/sdlc:autopilot` when the user
explicitly passes `--allow-merge`. Merging is a human decision; this command makes the
mechanical pre-checks instantaneous.

There is no `--force` flag. A failed gate is a human's problem by design.

Read `.claude/sdlc.md` for the **Tracker descriptor**. All operations below are bold — execute
them exactly as the descriptor defines; never substitute a CLI call of your own.

---

## Phase 1: Preflight [HARD STOP]

**First action, before anything else:** **get-pr** `<n>`. Print `PR #<n> not found` and stop if
the PR does not exist. Print `PR #<n> is already merged` and stop if it is already merged.

---

## Phase 2: Gate check [GATE]

Run the gates in this exact order. Stop at the **first failure**: print that one line and exit.
Mutate nothing until all four pass.

| # | Gate | Pass condition | Failure line |
|---|---|---|---|
| 1 | Pipeline label | label is exactly `merge-ready` | `gate 1: label is <label> — not merge-ready` |
| 2 | CI checks | **get-pr-checks** all required checks pass | `gate 2: check <name> is <state>` |
| 3 | Conflicts | `mergeable` field is not `CONFLICTING` | `gate 3: head has conflicts — resolve before merging` |
| 4 | QA verdict | PR comments contain `Verdict: PASS` with no blocking `GAPS` finding | `gate 4: QA verdict is GAPS — fix blocking findings first` |

All four pass → Phase 3.

For gate 4: scan PR comments newest-first for a line starting `Verdict:`. If the most recent
verdict is `GAPS` and any finding below it is labelled `blocker` or `major`, gate 4 fails.
`Verdict: PASS` with no such findings passes.

---

## Phase 3: Approve and merge [REQUIRED]

1. **review-pr** `<n>` `approve` with body:
   ```
   🤖 All gates passed (label: merge-ready · CI: green · no conflicts · QA: PASS).
   Approving for squash-merge.
   ```
2. **merge-pr** `<n>` (squash strategy). Capture the merged URL.
3. If `--followup "<text>"` was passed: invoke `/sdlc:followup <n> "<text>"` via `SlashCommand`.
   If unavailable, read `${CLAUDE_PLUGIN_ROOT}/commands/followup.md` and follow it verbatim.
   Pass `<n>` and the quoted text; capture the returned issue number and URL for the report.

---

## Phase 4: Report

```
## Merged — PR #<n>
Title: <title>
Strategy: squash

Verdict: APPROVED
PR: #<n> (<url>)
Issue: #<m> (<issue-url>)
```

Omit the `Issue:` line when `--followup` was not used.

---

## Not to be confused with

- **`/sdlc:fix-pr`** — fixes CI failures and review findings until the PR is merge-ready.
  Run that first; run this after the label reaches `merge-ready`.
- **`/sdlc:merge-buddy`** — read-only; shows which PRs pass all four gates right now. Use it
  to triage before deciding what to merge; it never calls `merge-pr`.
- **`/sdlc:autopilot`** — orchestrates the post-PR pipeline. It appends `/sdlc:merge` only
  when `--allow-merge` is explicit; without that flag it stops at `merge-ready`.
