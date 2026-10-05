# Fan-out

**Shape:** the caller starts N independent workers; each returns its own result; no agent merges
them.

## Use it when

- N independent tasks with no merged answer: translate 500 product descriptions.
- The same check against many targets: collect metrics from 12 services, run the same migration
  check in each of 40 packages.
- Each item's input and output are self-contained — a worker needs nothing another produced.
- The caller consumes results as they arrive, and a missing result is a gap, not a contradiction.

## Do not use it when

- The results must become one answer — a ranking, a report, a decision — use
  **orchestrator/worker**.
- The items are a backlog that grows while work runs and workers pull from it — use **swarm**.
- There are fewer than ~5 items; the overhead of N contexts exceeds one **single** agent's run.

## Required controls

| Control | Why | How to tell it is missing |
|---|---|---|
| A concurrency cap | unbounded parallelism exhausts rate limits and money at once | the worker count equals the item count |
| One output path per worker | two writers on one file leave an artefact nobody can attribute | workers append to a shared results file |
| Isolated failure | one worker's failure neither aborts nor retries the whole set | a single timeout fails the batch |
| No coordinator | a merge step nobody asked for becomes an unvalidated synthesis | a final agent "summarises" the results |
| Per-item identity in the result | a result that does not name its item cannot be checked | results arrive in completion order, unlabelled |

## Failure mode

**Stampede and orphaned writes.** All workers start at once, half hit the rate limit, and the
retries collide on a shared output file; the operator sees a partial result set with no way to
tell which items succeeded. Prevented by the concurrency cap, one output path per worker keyed by
item, and a per-item status the caller reads.

## Budget

- Concurrency: the `workers` default, 3 (`BUILTIN_WORKERS` in `plugins/sdlc/bin/aisdlc`,
  `aisdlc run --workers <n>`). Raise it against the rate limit, not against impatience.
- Stop condition: every item returned a result or a failure.
- Escalation: a worker that cannot claim any item, or a failure rate above what the caller can
  re-queue, goes to a human.

## In this harness

`/sdlc:decompose` turns one oversized change into independently shippable slices, each its own
spec; once approved, the queue runs them as independent tasks with no coordinator, one worktree
and one branch each, so no two write the same path.
