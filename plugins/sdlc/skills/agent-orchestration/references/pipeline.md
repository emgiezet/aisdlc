# Pipeline

**Shape:** stage N → validator → stage N+1; each stage owns one transformation, the validator
decides whether the run continues.

## Use it when

- Stage N's input is stage N−1's output: spec → implementation → verification → pull request.
- Each stage needs a different context or model — a cheap model for a mechanical stage, a strong
  one for the stage that reasons.
- Stages can be rerun on their own: 3–8 stages, each with an artefact on disk.
- An error must be caught at the stage that made it, not at the end.

## Do not use it when

- The stages do not depend on each other — that is **fan-out**.
- The "stages" are one agent's plan steps inside one context — that is a **single** agent.
- The next stage depends on who is best placed to answer — that is **handoff**.

## Required controls

| Control | Why | How to tell it is missing |
|---|---|---|
| A validator between every pair of stages | a stage that passes malformed output on makes every later stage wrong | stage 3 parses stage 2's prose to find out whether it succeeded |
| Fail closed | an unconfigured or unreachable check that passes is a check that lies | a missing validator logs a warning and the run continues |
| The contract is a named token | a verdict is matched by code, not interpreted | the next stage greps for "looks good" |
| Each stage re-entrant | a rerun of stage 3 must not require rerunning 1 and 2 | a stage reads state only the previous process held in memory |
| The stop says which fact is missing | a stop without a reason is rerun blindly | the log ends with "failed" and nothing else |

## Failure mode

**Laundered error.** A wrong assumption introduced at stage 1 arrives at stage 4 wearing the
authority of three successful stages; the final report says PASS because each stage checked only
its own output. The first symptom is a reviewer finding a defect that every stage's report
claims to have ruled out. Prevented by validators that re-read the artefact against the spec,
not against the previous stage's summary, and by at least one deterministic validator that no
model writes.

## Budget

- Concurrency: 1 stage at a time per task.
- Stop condition: a verdict token per stage; a failure token stops the run.
- Escalation: when a stage returns its failure token twice, a human reads the artefact.

## In this harness

The queue runs `implement → qa → scope-check → verify → ship → review` (`ALL_PHASES` in
`plugins/sdlc/bin/aisdlc`). Stages pass through files in `specs/<TICKET>/` and verdict tokens
defined in `pipeline-contracts` under `## Verdict tokens`. `run_verify` is the deterministic
validator: the repository's own `verify` commands, UC traceability in changed tests, no deleted
or skipped tests — and "no commands configured" is a FAIL, not a skip.
