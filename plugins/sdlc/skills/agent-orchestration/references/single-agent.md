# Single agent

**Shape:** one agent with tools; it plans, acts and verifies, and nothing else decides.

The default. Every other shape adds a context boundary, and a boundary is only worth paying for
when the task's structure forces it. Most tasks do not.

## Use it when

- One concern inside one test suite — a feature touching one module and its tests.
- A bug with a reproduction: one failing test, one root cause, one fix.
- A refactor confined to one package, where the whole call graph fits in context.
- A change a reviewer can read in one sitting — inside the repo's change budget.

## Do not use it when

- The work is several stages, each consuming the last one's output — use a **pipeline**.
- There are dozens of independent items and the context would fill before half are done — use
  **fan-out**, or **swarm** when the list is a backlog.
- The change is larger than one pull request — run `/sdlc:decompose` first, then one agent per
  slice.

## Required controls

| Control | Why | How to tell it is missing |
|---|---|---|
| Every claim grounded in a tool result from this session | a long context turns guesses into "facts" by repetition | the summary cites a behaviour no command in the transcript showed |
| A verification step that executes the changed path | reasoning about code is not running it | "should work" or "tests would pass" without a test run |
| A hard dollar cap | an agent that does not converge keeps spending | the run is stopped by a person, not by a limit |
| Fresh context per phase | one growing transcript drifts | implement, review and ship share one session |

## Failure mode

**Context drift.** Turn 40 cites turn 8's hypothesis as established; the fix addresses a cause
that was never confirmed. The first symptom an operator sees is a confident summary whose
evidence cannot be found in the transcript. Prevented by grounding every claim in a tool result
and by starting each phase with a fresh context that reads the artefacts, not the conversation.

## Budget

- Concurrency: 1.
- Stop condition: the task's dollar cap — `BUILTIN_BUDGET="5"` in `plugins/sdlc/bin/aisdlc`,
  overridden per task with `aisdlc add <TICKET> --budget <usd>`.
- Escalation: to a human on the second failed verification. A third attempt with the same
  context is the same attempt.

## In this harness

Each queue phase is a single agent: `bin/aisdlc` starts a headless run per phase with a fresh
context, and the phases hand over through files in `specs/<TICKET>/`, never through a shared
transcript. Interactive `/sdlc:implement` is a single agent bounded by the spec's UC table.
