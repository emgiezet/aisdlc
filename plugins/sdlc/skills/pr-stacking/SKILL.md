---
name: pr-stacking
description: >
  How to ship a chain of small pull requests instead of one large one — slicing the work, the
  base chain, the size budget that keeps a PR reviewable, merging bottom-up, and the restack
  every squash-merge forces on the children. Use when a change is too large to review in one
  PR, when splitting a spec into slices, when deciding what may merge now, or when a stacked
  PR's diff suddenly shows its parent's changes.
---

# PR Stacking

A reviewer who cannot hold the diff in their head approves it anyway, so review becomes a
ritual and nobody can honestly own the merge. A stack trades one unreviewable PR for four
reviewable ones.

## Why a stack

One large PR fails review. The reviewer approximates and signs off. The bug that a smaller diff
would have made obvious ships. A stack of four 100-line PRs reviewed in sequence catches what a
400-line wall does not, because the reviewer can form a mental model of each one and hold it
while reading. Every PR passes its own gates independently and merges only in order. The cost is
real: N PRs means N merges, N deploys to staging, and a restack after each squash.

## When not to stack

- A single-concern change that fits the size budget is a PR, not a stack.
- A change whose slices cannot each keep the suite green — do not stack it. Every PR in a stack
  must pass its own gates. A chain where every PR is broken until the last is worse than a large
  PR because now the reviewer must simulate the future.
- A hotfix. The merge window is the constraint; the stack adds time, not value.

A stack of one is a PR.

## Anatomy

| Term | Meaning |
|---|---|
| *stack* | An ordered chain of PRs, each based on the one below |
| *bottom PR* | Based on the default base ref — the only one that can merge first |
| *base chain* | `main ← a ← b ← c` — the sequence of branches, each depending on the one to its left |
| *restack* | Rebasing the children after the parent's squash-merge rewrote its commits |
| *stack root spec* | The `<TICKET>` whose `-a`/`-b` slices are the stack members |

## Building a stack from a spec

`/sdlc:spec` writes `<TICKET>-a`, `<TICKET>-b` when a spec exceeds ~8 use cases or two
concerns — `spec-authoring` owns the split rules; name them, do not restate them here. Each
slice is queued with `--base` set to the previous slice's branch, so the PRs come out stacked:

```bash
aisdlc add ABC-123-a --repo .                               # base: origin/main
aisdlc add ABC-123-b --repo . --base ai/ABC-123-a-<slug>
```

The bottom slice is the walking skeleton. If the stack's slice ordering is wrong, the bottom PR
is the one nobody can review without the others — fix the ordering before the first commit.

## Size budget

| Signal | Budget | What to do when exceeded |
|---|---|---|
| Changed lines per PR | ~400 (excluding generated files and lock files) | Split at the seam the spec already names |
| Files touched | ~15 | Reconsider the slice boundary |
| Concerns per PR | exactly 1 — a PR that needs "and" in its title is two PRs | Split |
| PRs per stack | ~5 | Beyond that the stack is the thing nobody can hold; ship as separate stacks on separate days |
| Review time | ≤ 20 minutes | Whatever the line count, if a reviewer cannot judge it in 20 minutes it is not reviewable |

Generated files and lock files are excluded from the line count but named in the PR body. A
4,000-line lock diff is not a review burden; pretending it is corrupts the budget.

## Merging a stack

Bottom-up, one at a time, never in parallel. The full sequence:

1. The bottom PR passes its own gates and merges (squash).
2. Its branch is deleted; **its commits no longer exist** — the squash produced one new commit on
   main.
3. Only the direct child (next in line) is based on the deleted branch. Rebase it onto the
   default base ref:
   ```bash
   git rebase --onto origin/main <old-parent-branch> <direct-child-branch>
   ```
   Every deeper child rebases onto its freshly-restacked parent, keeping its own parent as base:
   ```bash
   git rebase --onto <new-parent-branch> <old-parent-branch> <child-branch>
   ```
   Only one PR at a time is ever based on the default base ref; grandchildren and deeper stay
   targeted at their immediate parent.
4. **retarget-pr** the direct child to the default base ref, then push with
   `git push --force-with-lease`. The guard hook explicitly permits `--force-with-lease`;
   `--force` and `-f` are blocked.
5. Re-run CI on the retargeted child before merging. A green check from before the rebase proves
   nothing about the code that exists now.

**The failure mode**: retargeting without rebasing first makes the child's diff include
everything the parent changed, the review becomes meaningless, and the merge reverts nothing but
looks enormous.

## Drift and conflicts

A stack is a claim that nothing else will touch these files. Rebase the whole stack onto the
base at least daily; a stack older than a few days is a merge conflict with a delivery date.
When two stacks touch the same file, one of them is wrong about its boundaries — fix the
slicing, do not resolve the same conflict five times.

## Non-negotiable

1. **Never merge a stack out of order.**
2. **Never retarget a child without rebasing it first.**
3. **Never force-push a branch that is not a stack member being restacked.**
4. **Never let a stack member ship a broken suite on the promise that the next PR fixes it.**
5. **Never grow a stack past the point where its own reviewer cannot say what it does in one
   sentence.**

## Review checklist

- [ ] Each slice maps to exactly one concern named in the spec — no "and" in the PR title
- [ ] The bottom PR is the walking skeleton and is reviewable without the others
- [ ] Each PR in the stack passes its own CI gates independently
- [ ] Stack depth is ≤ 5; if exceeded, the slicing decision is recorded
- [ ] The merge sequence is bottom-up with a rebase-before-retarget step for each child
- [ ] Generated files and lock files are excluded from the line count in the PR body
- [ ] The stack is rebased onto the base at least daily while open
