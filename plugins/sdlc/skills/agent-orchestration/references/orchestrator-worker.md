# Orchestrator/worker

**Shape:** the orchestrator writes the split, dispatches N workers, re-checks what they return and
synthesises one answer. Workers never talk to each other.

## Use it when

- The same N independent tasks as fan-out, but the result is one merged answer: a review over
  6 lenses, a migration plan over 12 services, a test-gap matrix over 20 UC rows.
- Each slice needs a fresh context the orchestrator cannot afford to hold.
- The split can be written down before any worker starts, with an acceptance criterion per slice.

## Do not use it when

- Nobody needs the merged answer — use **fan-out** and skip the synthesis.
- The split cannot be stated in advance because each step depends on the last — use a
  **pipeline**.
- The orchestrator would do the reading itself anyway — that is a **single** agent with extra cost.

## Required controls

| Control | Why | How to tell it is missing |
|---|---|---|
| The split is written before dispatch | a split decided while workers run cannot be checked | the orchestrator's plan changes after the first return |
| Each slice names its acceptance criterion | a worker cannot know when it is done otherwise | workers return "done" with no evidence |
| Worker-return contract | the orchestrator's context is the bottleneck | a worker returns its raw reading, file dumps, full logs |
| Re-check before synthesis | this is the feedback loop that stops one bad split poisoning every result | the synthesis quotes worker text it never verified |
| The orchestrator holds only the split and the returns | if it reads what workers read, the split bought nothing | the orchestrator opens the same files as its workers |

The return record: a verdict, the evidence paths (files, commands, test names) and at most one
page of text. Anything larger is written to a file and returned as a path.

## Failure mode

**Single point of failure that is also the only context holder.** The orchestrator's one wrong
assumption in the split is invisible in every worker's output, because each worker did exactly
what its slice asked. The first symptom is a synthesis in which every part is correct and the
whole answers the wrong question. Prevented by writing the split and its acceptance criteria down,
re-checking each return against its criterion, and escalating when two returns contradict.

## Budget

- Concurrency: the `workers` default, 3.
- Stop condition: one synthesis pass after every slice returned or failed.
- Escalation: when two workers' returns contradict each other, a human resolves it — a second
  synthesis pass would only pick one.

## In this harness

`/sdlc:qa` dispatches the `auto-qa` agent and `/sdlc:review` dispatches `code-reviewer`; each
command acts only on the verdict the agent returns (`PASS`/`GAPS`, `APPROVED`/`CHANGES_REQUESTED`),
never on its transcript.
