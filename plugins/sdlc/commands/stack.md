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

**Setup — fetch and confirm all branches.** Run from the **default base branch** — `git rev-parse --abbrev-ref HEAD` must equal `<default-base-branch>`; not a detached HEAD — and with no worktree of this clone holding a member branch.
For every member branch:

```bash
git fetch origin <branch>:<branch>   # one per member, bottom to top
```

A refspec fetch updates the local ref directly and refuses when the update is not a
fast-forward. Absent branches are created. Any failure — ahead-of-remote, divergent, or
currently checked out — stops the command: name the branch and exit. After every member
succeeds, each local ref is identical to its remote head at this moment; the assertion fetch
in step B.2 is scoped to the base branch only and does not advance member remote-tracking refs.

**Repeating loop** — for each member from bottom to top. Call the current bottom P and its
direct child C.

**Step A — Print and record the current tip sha of P and every remaining member.** Each Bash
call is a fresh process: shell variables do not persist between tool invocations, so the sha
must live in the round's written output, not a `$VARIABLE`. Run:
```bash
git rev-parse <P-branch>                    # → note as <P-old-sha> for this round
git rev-parse <each-remaining-member-branch># → note as <member-old-sha>
```
Write each literal 40-character sha into the round's progress notes. B.3 and B.4 use only
these literal shas as boundaries — never a `$VARIABLE` that may be empty.

**Step B:**

1. **review-pr** P approve with body:
   ```
   🤖 Stack merge — all gates passed (label: merge-ready · CI: green · no conflicts · QA: PASS).
   Approving for squash-merge.
   ```
2. **merge-pr** P (squash). P's branch is deleted; its commits no longer exist as such.
   **Assert the squash landed before continuing.** For the GitHub tracker (squash lands on the
   remote), first run `git fetch origin <default-base-branch>` — this updates the tracking ref
   and is scoped to the base branch, leaving member remote-tracking refs unchanged. For the
   local tracker, `merge-pr` already advanced `main`; no fetch needed. Then run:
   ```bash
   git log --oneline -1 <default-base-ref>
   git rev-parse <default-base-ref>
   ```
   Confirm the output sha equals the `mergeCommit` the tracker just recorded for P. If they
   differ, the squash did not land on `<default-base-ref>`: stop, print the discrepancy,
   and do not continue to the rebase step.
3. Rebase C onto **Default base ref** using the literal sha Step A printed for P:
   ```bash
   git rebase --onto <default-base-ref> <P-old-sha> <C-branch>
   ```
   `<P-old-sha>` is the 40-character sha recorded in Step A for P this round. If the rebase
   reports a conflict: run `git rebase --abort`, set C's pipeline label to `blocked`, and go
   to the conflict block below without executing steps 4–8.
4. **Restack every queued member** — all members that follow C in the stack (nearest to C first).
   Even when only one queued member exists, this step is mandatory; skipping it leaves the
   queue out of sync and the next round's rebase will replay the merged parent's diff and conflict.
   For each such member D in order (nearest C first):
   ```bash
   git rebase --onto <D-parent-branch> <D-parent-old-sha> <D-branch>
   ```
   `<D-parent-old-sha>` is the literal sha Step A printed for D's parent this round — the
   pre-rebase sha, not the post-rebase tip (which is a new commit unreachable from D's history).
   If the rebase reports a conflict: run `git rebase --abort`, set D's pipeline label to
   `blocked`, and go to the conflict block below.
5. Return to the default base branch before any tracker operations: `git checkout <default-base-branch>`.
   The three-argument form of `git rebase` checks out the target branch, leaving HEAD there;
   every subsequent step in this round and the next round's **merge-pr** require HEAD to be on
   the default base branch. If this checkout fails (branch absent locally or checked out in a
   sibling worktree): confirm the working tree is clean, then stop and report the current state —
   P was squash-merged, all rebases for this round completed, and the operator must run
   `git checkout <default-base-branch>` manually before continuing with steps 6–8 and the next round.
6. **retarget-pr** C to `<default-base-branch>` (the branch name, e.g. `main`).
7. `git push --force-with-lease origin <C-branch>` — the guard hook permits `--force-with-lease`;
   `--force` and `-f` are blocked.
8. **rerun-check** C. Wait for all required checks to pass before merging C.

**Conflict block** (reached from B.3 or B.4 inline): report which member conflicted, set its
pipeline label to `blocked`, leave already-merged PRs as merged, and state plainly that the
remainder needs a human. **Failed checkout (step 5):** report the state — P was squash-merged,
all rebases completed — and the operator must run `git checkout <default-base-branch>` manually.

In the next round, C is the new P. Step A prints C's current sha (now the post-rebase tip) fresh.

---

## Phase 4: Report

When the full chain lands, verify every member's landing before printing MERGED. For the
GitHub tracker, first run `git fetch origin <default-base-branch>` — the last member's squash
landed after B.2's fetch; without this, `<default-base-ref>` is stale for that commit.
For the local tracker, no fetch needed. Then for each member:
```bash
git merge-base --is-ancestor <mergeCommit> <default-base-ref>
```
If any mergeCommit fails this check: print `DEFECT: #<n> mergeCommit <sha> absent from <default-base-ref>`
and report `Verdict: ⚠ NEEDS HUMAN` then `PR: #<n_last> (<url>)` instead of MERGED. Only when every check passes:
```
## Merged — Stack <TICKET>

Members (merged in order):
  #<n1>  <title>  squash-merged  <mergeCommit-sha>
  #<n2>  <title>  squash-merged  <mergeCommit-sha>

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
