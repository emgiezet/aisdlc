---
description: Resume a stalled implementation from a BLOCKED.md, a changes-requested review, or a human's unplanned branch — reconstruct remaining work, fix review findings, re-implement, and re-verify. Use after /sdlc:implement stops blocked, after /sdlc:review returns CHANGES_REQUESTED, or on any open PR that has no spec.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, SlashCommand, Agent
---

# /sdlc:continue

`$ARGUMENTS` is a ticket id (`SDLC-123`) or a PR number. Read `.claude/sdlc.md` for the specs
directory and the **Tracker descriptor**. All tracker operations below are bold — execute them
exactly as the descriptor defines; never substitute a CLI call of your own.

---

## Phase 1: Entry state [HARD STOP]

**First action, before anything else:** if `$ARGUMENTS` looks like a ticket id, check whether
`specs/<T>/BLOCKED.md` exists. If it does, this is UC-1 — skip **get-pr**. Otherwise call
**get-pr** with the number and read labels, body, and comments.

Classify the entry state from the table and follow the matching phase:

| State | Signal | Phase |
|---|---|---|
| UC-1: Blocked implementation | `specs/<T>/BLOCKED.md` present | 2 |
| UC-2: Changes requested | PR label is `changes-requested` | 3 |
| UC-3: Unplanned branch | No `specs/<T>/spec.md` and no `specs/<T>/continue-plan.md` | 4 |

If none match — the PR label is `review` or `merge-ready` — print
`PR #<n> is <label>; nothing to continue` and stop.

---

## Phase 2: Resume from BLOCKED.md (UC-1)

1. Read `specs/<T>/BLOCKED.md`. Parse the `**Stopped at:**` line (the UC or CI command
   where the run halted) and the `## What I need from a human` section.
2. Attempt to answer the question using only the spec and the codebase:
   - Search the spec's `Context` references, surrounding code, and any test output on the branch.
   - If answerable: resolve it, then proceed to Phase 5. The commit that deletes `BLOCKED.md`
     must be **the same commit** as the first new UC test — do not delete it earlier.
   - If unanswerable: append to `BLOCKED.md`:
     ```
     Still blocked because: <one-sentence reason>
     ```
     Commit that line, then stop. Do not proceed to Phase 5.

Never rewrite history. Never delete a failing test — if a test fails after resuming, record it
as the next blocker and write a new `BLOCKED.md` instead of removing the test.

---

## Phase 3: Resume from CHANGES_REQUESTED (UC-2)

1. **get-pr** `<n>` — collect body, comments, and all review threads.
2. Extract every actionable finding from threads with status `CHANGES_REQUESTED` or `COMMENTED`.
   Skip `APPROVED` threads and pure nits marked as resolved.
3. Write `specs/<T>/continue-plan.md` as a Markdown checklist:

   ```markdown
   # Continue plan — <T>

   PR: #<n> (<url>)

   ## Review findings

   - [ ] `file:line` — <finding summary> (reviewer: @<login>)
   - [ ] …
   ```

4. Address each unchecked row in order:
   - Fix the issue.
   - Commit: `fix(scope): <finding summary> — addresses review (<T>)`.
   - Check off the row in `continue-plan.md` and commit the update. Every commit must name the
     finding it resolves.
5. After all rows are checked: **unlabel-pr** `changes-requested` + **label-pr** `review`.
6. Proceed to Phase 5.

---

## Phase 4: Reconstruct a human's branch (UC-3)

1. **get-pr** `<n>` — read title, body, all commits, diff, and comments.
2. Write `specs/<T>/spec.md` with frontmatter:
   ```yaml
   status: draft
   kind: adopted
   ```
   - Title from the PR title.
   - UC rows inferred from the PR body, commits, and diff — observable results only, no
     implementation details in the `Expected result` column.
   - `Out:` covering modules the diff does not touch.
3. Print exactly:
   ```
   Wrote specs/<T>/spec.md (status: draft, kind: adopted).
   Review and approve the spec before continuing:
     /sdlc:spec <T>        — edit
   Then set status: approved and re-run /sdlc:continue <T>.
   ```
4. **Stop here.** Never implement against a draft spec.

---

## Phase 5: Implement and verify (UC-1 and UC-2)

1. Invoke `/sdlc:implement <T>` via the `SlashCommand` tool. If unavailable, read
   `${CLAUDE_PLUGIN_ROOT}/commands/implement.md` and follow it verbatim.

   `/sdlc:implement` resumes at the first UC that does not yet have a passing test; it does not
   re-run UCs already green. For UC-1, the commit deleting `specs/<T>/BLOCKED.md` must land in
   this phase as the same commit as the first new test.

2. If `/sdlc:implement` writes a new `BLOCKED.md`, stop here and report the new blocker.

3. Invoke `/sdlc:qa <T>` via the `SlashCommand` tool. If unavailable, read
   `${CLAUDE_PLUGIN_ROOT}/commands/qa.md` and follow it verbatim.

Pass outputs forward in the standard block:

```
— PREVIOUS STEP (/sdlc:implement) said —
<implement output>
— PREVIOUS STEP (/sdlc:qa) said —
<qa output>
```

---

## Phase 6: Report

```
## Continued — <T>
Entry: <UC-1 Unblocked | UC-2 Review addressed (<n> findings) | UC-3 Spec written>
Plan: specs/<T>/continue-plan.md        (UC-2 only)
QA: <PASS | GAPS | BLOCKED>

Verdict: <PASS | GAPS | BLOCKED>
PR: #<n> (<url>)
```

`Verdict: BLOCKED` when `/sdlc:implement` wrote a new `BLOCKED.md`.

---

## Not to be confused with

- **`/sdlc:fix-pr`** — loops `/sdlc:review --autofix` and CI stabilisation until `merge-ready`.
  Use that for automated fixup cycles; use this when a human stopped the run.
- **`/sdlc:implement`** — starts from an approved spec with a clean slate. This command
  re-enters an in-progress run and consumes review findings.
- **`/sdlc:review`** — produces the findings this command consumes. Run review first; then
  continue.
