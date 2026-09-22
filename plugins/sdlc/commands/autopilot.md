---
description: Diagnose a PR's current state, dispatch the right command, and re-diagnose until the PR reaches merge-ready or a human is needed. Use to unstick a stalled PR without knowing what is wrong.
allowed-tools: Bash, Read, Grep, Glob, SlashCommand
---

# /sdlc:autopilot

`$ARGUMENTS`: `<pr#> [--allow-merge] [--dry-run]`. Read `.claude/sdlc.md` for the Tracker descriptor.

`--dry-run`: print the diagnosed state and the ordered command chain; mutate nothing.
`--allow-merge`: append `/sdlc:merge` as a final step when the PR reaches `merge-ready`.

Maximum 6 dispatch steps per run. Re-diagnose after each step.

---

## Phase 1: Diagnose [HARD STOPS]

**First action:** **get-pr** `{n}` and **get-pr-checks** `{n}`. If the PR does not exist, print
`no PR #<n> found` and stop.

Determine state using the first matching row:

| State | Evidence | Next command |
|-------|----------|-------------|
| `unfinished-plan` | `specs/<T>/BLOCKED.md` or `specs/<T>/continue-plan.md` exists | `/sdlc:continue` |
| `unreviewed` | pipeline label is `review`; `reviews` list is empty | `/sdlc:review {n} --autofix` |
| `changes-requested` | pipeline label is `changes-requested` | `/sdlc:fix-pr {n}` |
| `red-ci` | pipeline label is `review` or `merge-ready`; any required check is failing | `/sdlc:fix-pr {n} --ci-only` |
| `conflicted` | `mergeable == CONFLICTING` | `/sdlc:fix-pr {n}` |
| `merge-ready` | pipeline label is `merge-ready`; all required checks green | `/sdlc:merge {n}` (only with `--allow-merge`; otherwise stop) |

`<T>` is the ticket id from the PR title or body; if absent, skip the `unfinished-plan` check.

If `--dry-run`: print the diagnosed state and the full ordered command chain the run would
execute; stop here; mutate nothing.

Without `--allow-merge`, the chain never includes `/sdlc:merge`.

---

## Phase 2: Dispatch and re-diagnose

For each step (max 6 total):

1. Invoke the next command via the `SlashCommand` tool. If unavailable, read
   `${CLAUDE_PLUGIN_ROOT}/commands/<name>.md` and follow it verbatim. Pass prior output:
   ```
   — PREVIOUS STEP (/sdlc:<name>) said —
   <output>
   ```
2. Re-run Phase 1 to get the new state.
3. Stop if state is `merge-ready` and `--allow-merge` is absent.
4. Stop if output contains `⚠ NEEDS HUMAN`; **label-pr** `blocked`.
5. Stop if state is unchanged after a step; print
   `autopilot: no progress after /sdlc:<name>`.

---

## Phase 3: Report

```
## autopilot — PR #{n}
Steps taken: <n>/6

Step 1: <state-before> → /sdlc:<command> → <state-after>
Step 2: …

Final state: <state>
<⚠ NEEDS HUMAN: <reason> | merge-ready — run /sdlc:merge {n} to complete>

Verdict: <from last /sdlc:review if any>
PR: #<n> (<url>)
```

---

## Not to be confused with

- **`/sdlc:fix-pr`** — one targeted fix cycle. `autopilot` calls it and re-diagnoses.
- **`/sdlc:review`** — a single review pass. `autopilot` wraps it as the first step for
  unreviewed PRs.
- **`/sdlc:merge`** — only dispatched when `--allow-merge` is passed.
