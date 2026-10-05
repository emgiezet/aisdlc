# Debate

**Shape:** roles with opposing objectives argue in rounds; a judge decides against criteria fixed
before the first round.

## Use it when

- One irreversible decision worth more than the tokens: splitting a monolith, changing the storage
  engine, migrating the auth provider.
- The options are known and the disagreement is about trade-offs, not facts.
- A wrong choice costs weeks; a debate costs 4 roles × 3 rounds.

## Do not use it when

- A benchmark, a load test or a prototype settles it — run that instead.
- The decision is reversible in a day — a **single** agent decides and the review catches it.
- The facts are unknown — gather them first; a debate over missing evidence is a guess with a
  transcript.

## Required controls

| Control | Why | How to tell it is missing |
|---|---|---|
| Roles with genuinely different objectives | the same objective under four names agrees with itself | every role's prompt starts from the same brief and the same goal |
| Different prompts per role | a role is defined by what it optimises, not by its name | the prompts differ only in the role label |
| Criteria written before round one | criteria chosen after the arguments fit the favourite | the judge's criteria appear first in the verdict |
| Round cap of 3 | rounds past three repeat positions | no cap; the debate ends when someone concedes |
| A decision record that keeps the losing argument | the next team must know what was rejected and why | the record states only the winner |

Roles: **proposer** (argues the change), **sceptic** (argues against it and for the status quo),
**operator** (the person who will carry the pager — argues failure modes, migration and
rollback), **judge** (scores each position against the criteria, decides).

The record names the decision, the criteria, each position's strongest argument, the losing
argument, and the condition that would reverse the decision.

## Failure mode

**Expensive consensus.** Four agents sharing one prior agree quickly and at length; the record
reads as consensus rather than as a choice, and the dissent that mattered was never voiced. The
first symptom is a debate with no position changing and no argument the judge had to weigh.
Prevented by role objectives that conflict by construction and by criteria fixed in advance.

## Budget

- Concurrency: 4 roles.
- Stop condition: 3 rounds.
- Escalation: the judge decides on the evidence present; a decision the criteria cannot separate
  goes to a human with the record.

## In this harness

No implementation here — this is a specification for systems built with the harness. The record
it produces belongs next to the architecture document the decision changes; review it with
`architecture-review`.
