---
description: Bring a broken PR to merge-ready — merges base, runs /sdlc:review --autofix, then classifies and repairs each CI failure until all checks are green. Use when a PR has red required checks, merge conflicts, or review blockers.
allowed-tools: Bash, Read, Grep, Glob, SlashCommand
---

# /sdlc:fix-pr

`$ARGUMENTS`: `<pr#> [--ci-only]`. Read `.claude/sdlc.md` for the Tracker descriptor.

`--ci-only` skips Phase 2 (review) and goes straight to CI stabilisation.

Every tracker action is a bold operation (**get-pr**). Execute it exactly as the descriptor defines.

---

## Phase 1: Merge base [HARD STOPS]

**First action:** **get-pr** `{n}`. If not found or state is `merged` or `closed`: print one line and stop.

In the PR's worktree (**checkout-pr** `{n}` if not already on the branch):

```bash
git fetch origin {base}
git merge origin/{base} --no-edit
```

List any conflicts; do not resolve them blindly. On conflict: push the merge commit as-is so
Phase 2 autofix can handle them with full context.

---

## Phase 2: Review + autofix

Skip entirely when `--ci-only` is passed.

Invoke `/sdlc:review {n} --autofix` via the `SlashCommand` tool. If unavailable, read
`${CLAUDE_PLUGIN_ROOT}/commands/review.md` and follow it verbatim.

Pass output forward:

```
— PREVIOUS STEP (/sdlc:review) said —
<output>
```

If the review returns `Verdict: APPROVED` and **get-pr-checks** `{n}` shows all green:
go directly to Phase 4 (Report).

---

## Phase 3: CI stabilisation loop

Run **get-pr-checks** `{n}`. For each failing required check, classify and act:

| Class | Evidence | Action |
|-------|----------|--------|
| `real-bug` | failure names production code | fix with a new test; commit |
| `test-bug` | assertion error inside test code | fix the test assertion; commit |
| `flake` | non-deterministic or network failure | **get-run-failed-logs** `{run-id}`; re-run the check once via the descriptor; if it fails again → treat as `real-bug` |
| `infra` | runner setup, toolchain, dependency cache | **comment-pr** `⚠ NEEDS HUMAN: infra failure in <check>`; **label-pr** `blocked`; stop |

Rules:
- A flake gets exactly one re-run. Record the **get-run-failed-logs** evidence before any code change.
- Never skip, comment-out, lower a threshold, or `--force` a push to clear a check.
- Repeat classification and fix until **get-pr-checks** returns all green, or `infra` stops the loop.
- Each fix is a separate commit; never amend or force-push.

---

## Phase 4: Report

```
## fix-pr — PR #{n}
Base merged: {sha}
CI fixes: <n> (<class: n>, …)
Final state: merge-ready | blocked

Verdict: <from /sdlc:review or CHANGES_REQUESTED if skipped with --ci-only>
PR: #<n> (<url>)
```

---

## Not to be confused with

- **`/sdlc:review`** — a single review pass. `fix-pr` wraps it and adds CI stabilisation.
- **`/sdlc:merge`** — merges the PR after this command sets `merge-ready`.
- **`/sdlc:autopilot`** — calls `fix-pr` as one step in a multi-command loop.
