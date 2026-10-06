# Swarm

**Shape:** N identical workers pull tasks from a shared board; no coordinator assigns work; a
claim lock decides who owns what.

## Use it when

- The backlog exceeds any single context: fix every ticket on a board, run a long queue of
  approved specs.
- Tasks are independent and of similar shape, so any worker can take any task.
- The backlog changes while the swarm runs — tasks are added, others close.

## Do not use it when

- The list is fixed and nobody adds to it while work runs — **fan-out** is simpler.
- Tasks depend on each other — order them in a **pipeline** or slice them with
  `/sdlc:decompose` first.
- Tasks touch the same files — no lock prevents the merge conflict at the end.

## Required controls

| Control | Why | How to tell it is missing |
|---|---|---|
| Claim lock with a TTL | two workers delivering one task wastes both; a dead worker must not hold a task forever | two branches for one ticket; a task "in progress" for a day |
| One branch or worktree per task | shared working trees mix changes from different tasks | workers commit into one checkout |
| Slicing that keeps tasks off each other's files | merge conflict is the swarm's dominant cost | the board has two tickets touching the same module |
| A worker that cannot claim moves on | waiting on a lock is idle spend | a worker polls one task's lock |
| Atomic take from the board | "read then mark" races between workers | two workers log the same task id as started |

## Failure mode

**Double delivery and merge pile-up.** Two workers deliver the same task, or ten branches finish
cleanly and then conflict in the same file at merge time. The first symptom is two pull requests
for one ticket, or a merge queue that stalls after the first PR lands. Prevented by an atomic take
plus a claim lock with a TTL, and by slicing the backlog so tasks do not share files.

## Budget

- Concurrency: the `workers` default, 3 (`BUILTIN_WORKERS` in `plugins/sdlc/bin/aisdlc`,
  `aisdlc run --workers <n>`).
- Stop condition: the board is empty.
- Escalation: a worker that cannot claim any task, or a stale claim taken over twice, goes to a
  human.

## In this harness

`aisdlc run --workers <n>` (`cmd_run` in `plugins/sdlc/bin/aisdlc`) is a swarm: each worker pops
from a queue serialised by `flock` (`pop_task`), so a take is atomic, and runs its task in its own
git worktree with a fresh context per phase. Across runs and people, the tracker claim lock in
`pipeline-contracts` under `## Claim lock` — assignee, `in-progress` label, `🤖 … claimed
<ISO-8601>` comment — marks ownership, and a claim older than 60 minutes is stale and may be taken
over with a note.
