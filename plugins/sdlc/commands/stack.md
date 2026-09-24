---
description: Interactive-only — walks the base chain of a stacked PR set, gates every member, then merges bottom-up with a full restack between each merge. Use after all members reach merge-ready, from a terminal session only; never invoked by the queue.
allowed-tools: Bash, Read, Grep, Glob, SlashCommand
---

# /sdlc:stack

`$ARGUMENTS` is `<TICKET|pr#> [--merge] [--restack]`.

This command is **interactive-only**. It is not in `ALL_PHASES` and is never invoked
automatically — merging reaches staging and is always a human decision. There is no `--force`
flag. A failed gate is a human's problem by design.

**Load the `pr-stacking` skill.** The rules for building, sizing, and restacking a PR chain live
there; this file is the sequence only. Also load the `pipeline-contracts` skill for operations
and verdict vocabulary.

Read `.claude/sdlc.md` for the **Tracker descriptor**. All operations below are bold — execute
them exactly as the descriptor defines; never substitute a CLI call of your own.

---

## Phase 1: Discover the stack [HARD STOP]

**First action:** Resolve the full chain from the argument.

- **Ticket id** (`ABC-123` or `ABC-123-a`): **search-prs** for open PRs whose head branch matches
  `ai/<TICKET>*`. Collect every match.
- **PR number**: **get-pr** `<n>`. Walk its base chain downward (each PR whose base branch is
  another open stack member) and upward (open PRs whose base is this branch's name), until both
  ends are reached.

Order members **bottom-first by base chain** — the PR whose base is the default base ref is
first; each subsequent member's base is the previous member's branch. PR numbers are creation
order and say nothing about dependency.

**Hard stop** (print one line naming the conflicting PRs and exit) when:

- A cycle exists in the base chain.
- A base branch resolves to neither the default base ref nor another open PR in the set.
- Two PRs in the set share the same base.

Print the ordered chain:

```
Stack (bottom → top):
  #<n1>  <title>  (base: main)
  #<n2>  <title>  (base: ai/<branch1>)
  #<n3>  <title>  (base: ai/<branch2>)
```

Stop here unless `--merge` or `--restack` was passed.

---

## Phase 2: Gate every member [GATE]

Apply `/sdlc:merge`'s four gates to **every** member before merging **any**. Rationale: merging a
prefix of the stack and discovering a later member is not ready leaves the deploy target in a
state nobody planned.

| # | Gate | Pass condition | Failure line |
|---|---|---|---|
| 1 | Pipeline label | label is exactly `merge-ready` | `gate 1 #<n>: label is <label>` |
| 2 | CI checks | **get-pr-checks** all required checks pass | `gate 2 #<n>: check <name> is <state>` |
| 3 | Conflicts | `mergeable` field is not `CONFLICTING` | `gate 3 #<n>: head has conflicts` |
| 4 | QA verdict | most recent `Verdict:` in comments is `PASS` with no blocking finding | `gate 4 #<n>: verdict is GAPS` |

Print a per-PR gate table after checking all members. Any failure: stop and print which member
blocks the stack.

---

## Phase 3: Merge bottom-up [REQUIRED]

Proceed only when `--merge` is passed and all Phase 2 gates have passed.

**Step A — Record every member's current tip sha before any merge.** Branch names move after a
rebase; only a saved sha is safe as a replay boundary. For each member branch, bottom to top:

```bash
<member>_old=$(git rev-parse <branch>)
```

**Step B — For each member, starting from the bottom.** Let P be the member to merge this round,
C be its direct child (next member up), and deeper be any members above C.

1. **review-pr** P approve with body:
   ```
   🤖 Stack merge — all gates passed (label: merge-ready · CI: green · no conflicts · QA: PASS).
   Approving for squash-merge.
   ```
2. **merge-pr** P (squash). P's branch is deleted; its commits no longer exist as such.
3. `git fetch` — the local default base ref must include P's squash commit before restacking C.
4. Rebase C onto the default base ref, using P's saved sha as the replay boundary:
   ```bash
   git rebase --onto origin/main "$P_old" <C-branch>
   ```
5. Capture C's new tip immediately after the rebase: `C_rebased=$(git rev-parse <C-branch>)`.
   This becomes C's saved sha for the next round (when C is the bottom being merged).
6. For each deeper member D in order from nearest to farthest, rebase D onto its freshly-restacked
   parent using that parent's saved sha as the replay boundary:
   ```bash
   git rebase --onto <D-parent-branch> "$D_parent_old" <D-branch>
   ```
   After each rebase, update `D_parent_old` to `git rev-parse <D-parent-branch>` before proceeding
   to the next deeper member. D's parent's saved sha is its tip after its own rebase, not its
   original sha from step A.
7. **retarget-pr** C to the default base ref.
8. `git push --force-with-lease <C-branch>` — the guard hook permits `--force-with-lease`;
   `--force` and `-f` are blocked.
9. **rerun-check** C. Wait for all required checks to pass before merging C in the next round.

**Conflict during any rebase:** report which member conflicted, set its pipeline label to
`blocked`, leave everything already merged as merged, and say plainly that the remainder of the
stack now needs a human.

**Advancing to the next round:** C becomes the new P. Its saved sha is `C_rebased` from step 5,
not its original sha from step A — the rebase moved the branch tip.

---

## Phase 4: Report

When the full chain lands:

```
## Merged — Stack <TICKET>

Members (merged in order):
  #<n1>  <title>  squash-merged
  #<n2>  <title>  squash-merged

Verdict: MERGED
PR: #<n_last> (<url>)
```

When a conflict or gate failure stops the chain:

```
## Partial stack — <TICKET>

Merged:
  #<n1>  <title>  squash-merged

Blocked at #<n2> <title>:
  <one-line reason>

⚠ NEEDS HUMAN
PR: #<n2> (<url>)
```

---

## Not to be confused with

- **`/sdlc:merge`** — merges one PR after four gates. A PR that is part of a stack should be
  merged with `/sdlc:stack` instead — merging it alone with `/sdlc:merge` strands its children
  on a deleted branch.
- **`/sdlc:release-check`** — decides what goes to production. This command only merges, which
  reaches staging.
- **`/sdlc:merge-buddy`** — read-only; shows which PRs pass all four gates right now. Use it
  to triage before deciding what to merge; it never calls `merge-pr`.
