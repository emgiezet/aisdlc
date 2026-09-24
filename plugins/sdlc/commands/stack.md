---
description: Interactive-only — walks the base chain of a stacked PR set, gates every member, then merges bottom-up with a full restack between each merge. Use after all members reach merge-ready, from a terminal session only; never invoked by the queue.
allowed-tools: Bash, Read, Grep, Glob, SlashCommand
---

# /sdlc:stack

`$ARGUMENTS` is `<TICKET|pr#> [--merge]`.

This command is **interactive-only**. It is not in `ALL_PHASES` and is never invoked
automatically — merging reaches staging and is always a human decision. There is no `--force`
flag. A failed gate is a human's problem by design.

**Load the `pr-stacking` skill.** The rules for building, sizing, and restacking a PR chain live
there; this file is the sequence only. Also load the `pipeline-contracts` skill for operations
and verdict vocabulary.

Read `.claude/sdlc.md` for the **Tracker descriptor**. All operations below are bold — execute
them exactly as the descriptor defines; never substitute a CLI call of your own.

---

## Phase 1: Discover the stack [INSPECT]

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

**No-merge halt** — if `--merge` is absent from `$ARGUMENTS`: evaluate the four gates for
every member using the definitions in Phase 2's table, print the per-PR gate table (one row
per PR, one column per gate, pass/fail), then stop without entering Phase 3. The chain and
gate table are the inspect deliverable; proceeding to Phase 3 without an explicit `--merge`
is a defect.

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

**Setup — fetch and confirm all branches.** Run from the default branch or a detached HEAD, and
with no worktree of this clone holding a member branch — `git fetch origin <branch>:<branch>`
refuses if that branch is checked out anywhere, naming the worktree path. That refusal is
correct: remove the worktree, never work around it with a checkout.
For every member branch:

```bash
git fetch origin <branch>:<branch>   # one per member, bottom to top
```

A refspec fetch updates the local ref directly and refuses when the update is not a
fast-forward. Absent branches are created. Any failure — ahead-of-remote, divergent, or
currently checked out — stops the command: name the branch and exit. After every member
succeeds, each local ref is identical to its remote head at this moment; no fetch in
step B.3 will advance those member remote-tracking refs.

**Repeating loop** — for each member from bottom to top. Call the current bottom P and its
direct child C.

**Step A — At the start of each round, before merging P, record the current tip sha of P and
every remaining member.** Branch names move after a rebase; only a saved sha is a safe replay
boundary:

```bash
P_old=$(git rev-parse <P-branch>)
<each-remaining-member>_old=$(git rev-parse <branch>)
```

**Step B:**

1. **review-pr** P approve with body:
   ```
   🤖 Stack merge — all gates passed (label: merge-ready · CI: green · no conflicts · QA: PASS).
   Approving for squash-merge.
   ```
2. **merge-pr** P (squash). P's branch is deleted; its commits no longer exist as such.
3. Advance the **Default base ref** so it points to P's squash commit:
   - **`origin/main`** (GitHub tracker, merge happened on the remote): `git fetch origin <default-base-branch>` — the squash is already on origin; a bare fetch updates the tracking ref.
   - **`main`** (local tracker, merge-pr commits locally): no fetch needed — local `main` was updated by merge-pr and **is** `<default-base-ref>` already.
4. Rebase C onto **Default base ref** using P's sha from step A as the replay boundary:
   ```bash
   git rebase --onto <default-base-ref> "$P_old" <C-branch>
   ```
   `<default-base-ref>` is the value from `.claude/sdlc.md` (`origin/main` for GitHub, `main` for
   local tracker). Using the wrong base here contaminates C's diff with P's changes; verify
   `git rev-parse <default-base-ref>` equals the squash commit before proceeding.
5. **Restack every queued member** — all members that follow C in the stack (nearest to C first).
   Even when only one queued member exists, this step is mandatory; skipping it leaves the
   queue out of sync and the next round's rebase will replay the merged parent's diff and conflict.
   For each such member D:
   ```bash
   git rebase --onto <D-parent-branch> "$D_parent_old" <D-branch>
   ```
   `<D-parent-branch>` is the branch name of D's parent after it was restacked in this round;
   `$D_parent_old` is that parent's sha recorded in step A (never a post-rebase sha).
   **Example (three-PR stack, round 1, P=#1, C=#2, queued=[#3]):** rebase #3 onto ai/SBX-9-b
   (the freshly restacked C-branch) using the pre-round-1 sha of ai/SBX-9-b as the boundary —
   the boundary excludes #2's commits so only #3's own commit is replayed.
   The boundary is the sha recorded in step A — never a tip produced by a rebase within this
   same round. `$D_parent_old` is step-A sha of D's parent, not the post-rebase tip (which is a
   new commit). Do not re-read branch tips between B.4 and B.5.
6. Return to the default base branch before any tracker operations: `git checkout <default-base-branch>`.
   The three-argument form of `git rebase` checks out the target branch, leaving HEAD there;
   every subsequent step in this round and the next round's **merge-pr** require HEAD to be on
   the default base branch. If this checkout fails (branch absent locally or checked out in a
   sibling worktree): confirm the working tree is clean, then stop and report the current state —
   P was squash-merged, all rebases for this round completed, and the operator must run
   `git checkout <default-base-branch>` manually before continuing with steps 7–9 and the next round.
7. **retarget-pr** C to the default base ref.
8. `git push --force-with-lease origin <C-branch>` — the guard hook permits `--force-with-lease`;
   `--force` and `-f` are blocked.
9. **rerun-check** C. Wait for all required checks to pass before merging C.

**Conflict during any rebase:** run `git rebase --abort` first, then report which member
conflicted, set its pipeline label to `blocked`, leave everything already merged as merged,
and say plainly that the remainder of the stack now needs a human. **Failed checkout (step 6):**
report which round's checkout failed, name the branch, and leave the tracker records for already-merged
members as merged; steps 7–9 and subsequent rounds require the operator to resolve the worktree conflict first.

In the next round, C is the new P. Step A re-reads C's current sha — now the post-rebase tip —
giving the correct replay boundary for C's children without carrying any variable forward.

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

Verdict: ⚠ NEEDS HUMAN
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
