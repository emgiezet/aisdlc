# Handoff

**Shape:** peer agents, each owning one domain; exactly one owns the task at a time and passes it
on by rule.

## Use it when

- Peer domain agents with one owner at a time: billing → technical → retention on a support line.
- Each domain needs its own tools and permissions — the billing agent can refund, the technical
  agent cannot.
- The routing can be written as a table: 3–8 domains, each with entry conditions.

## Do not use it when

- A coordinator should decide and merge — use **orchestrator/worker**.
- The order is fixed in advance — use a **pipeline**.
- The router cannot be written as a table because owners are decided case by case — a human is the
  router.

## Required controls

| Control | Why | How to tell it is missing |
|---|---|---|
| Deterministic routing rules | a model deciding "who owns this" will disagree with itself | the routing prompt says "use judgement" |
| Transfer budget of 3, then a human | every transfer costs the user time and the run tokens | no counter on the task |
| Visited-set travels with the task | A→B→A is only detectable if the task knows where it has been | each agent sees only the agent that sent it |
| Explicit handoff payload | the receiving agent assumes nothing it was not given | the receiver re-asks the user for what the sender knew |
| Human fallback with the gathered state | a dead end must not lose the work done so far | escalation starts from an empty case |

The payload: the task id, the user's request verbatim, what was established and by which tool
call, what is still unknown, the transfer count, the visited-set and the reason for the transfer.

## Failure mode

**Ping-pong.** Two agents each believe the other owns the case; the task bounces until the budget
is gone and the user never gets an answer. The first symptom is a transfer log with the same pair
repeating. Prevented by the visited-set — an agent may not send a task to one already in it
without a rule that says why — and by the 3-transfer cap that ends in a human.

## Budget

- Concurrency: 1 owner.
- Stop condition: the task is resolved, or 3 transfers have happened.
- Escalation: the fourth transfer goes to a human, with the payload.

## In this harness

No implementation here — this is a specification for systems built with the harness. The nearest
mechanism is the issue → PR hand-off in `pipeline-contracts` under `## Claim lock`: claim the PR,
then release the issue with outcome `handed off to PR #<n>`.
