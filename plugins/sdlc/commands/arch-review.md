---
description: Verify a planned architecture against its numbers — elicit or read the Non-functional targets block (traffic profile, availability tier, RPO/RTO, hard and soft dependencies), check the topology and dependency chain against what the tier forces, and write specs/<EPIC>/arch-review.md with severity-ranked findings and a SOUND/GAPS verdict. Use on an arch.md or any architecture document before it is sliced into specs, or whenever an availability target is stated.
allowed-tools: Bash(git:*), Read, Write, Edit, Grep, Glob
---

# /sdlc:arch-review

An architecture that says "highly available" cannot be reviewed; one that says 99.95 % with a
single database in one AZ can, and fails. This command turns the first kind into the second, then
grades it. It is interactive: the numbers come from a person, never from inference.

`$ARGUMENTS` is an epic id or a path to any Markdown architecture document. Read
`.claude/sdlc.md` first and take **Specs live in** as `<specs>` (default `specs/`); an epic id
resolves to `<specs>/<EPIC>/arch.md`, and every path below uses that same `<specs>`.

**Load the `architecture-review` skill** — it holds the tier table, the dependency arithmetic, the
traffic rules, the targets block format, and the findings table this command applies. Load
`code-review` for the severity definitions and the waiver format.

---

## Phase 1: Locate the document [HARD STOP]

**First action:** check that the file exists — `<specs>/<EPIC>/arch.md` for an id, the path as
given otherwise. Missing → print `no architecture document at <path> — nothing to review` and
stop. Do not search the repo for something that looks like one.

Read it whole. Note every component, every arrow between components, every data store, every
external service, and every deployment fact (regions, AZs, replicas, replication mode). These are
the inputs to Phase 3; the document's own claims about availability are inputs to Phase 2 only.

---

## Phase 2: Targets [GATE]

Look for a `## Non-functional targets` section in the format the skill defines.

**Present and complete** → continue.

**Absent or incomplete** → ask for each missing value, **one question per message**, in this
order. Each question names the shape it accepts; anything else is asked again once, then
recorded as `unknown`:

1. Availability tier — offer the five tiers with their 30-day downtime budget from the skill's
   table. Accepts one tier. Then: who is paged when it is breached? Accepts a team or role name.
2. Traffic — average rps, peak rps, concurrency, p95 payload. Accepts numbers. If only an
   average is known, record `peak: unknown` — that is a finding, not a blank to fill.
3. Growth per month and retention. Accepts a size and a duration.
4. RPO and RTO. Accepts two durations.
5. For every external service or store found in Phase 1: `hard` or `soft`; its availability as a
   percentage; and its source — a vendor SLA page **and the tier bought**, or `measured` with the
   period. Accepts exactly those three parts.
6. Load test — date, rate, duration, `pass | fail`; or `not run`.
7. Failover rehearsal and backup-restore rehearsal — a date each (failover also its measured
   RTO); or `not rehearsed`.

Assemble the block in the skill's format and **show it before writing anything**. Ask: correct?
Revise and show again until the person confirms. Only then write it: an existing
`## Non-functional targets` section is replaced in place; otherwise the block is inserted before
`## Risks` when that section exists, else appended. Never continue to Phase 3 on an unconfirmed
block, and never leave two targets sections in one document.

The person may decline a value. Record it as `unknown`; the review then grades the unknown.

---

## Phase 3: Verify

Apply the skill's rules to the document's facts. Work through the table in order and record every
violated row as a finding with its severity, quoting the document (`section`, or `file:line`) and
the arithmetic:

| Check | Source of the fact |
|---|---|
| A tier is stated and the traffic profile has peak rps — without both, one `blocker` and the review ends at Phase 4 | Phase 2 block |
| Product of hard-dependency availabilities ≥ stated tier | Phase 2 dependency list; show the multiplication |
| Failure domains match the tier row's "Topology it forces" | deployment facts from Phase 1 |
| Every stateful component has the replication and failover the tier requires | data stores from Phase 1 |
| RPO achievable by the replication mode; RTO achievable by the runbook steps named | Phase 1 replication facts, Phase 2 RPO/RTO |
| Peak/average stated; headroom ≥ 2× peak or autoscaling demonstrated | Phase 2 traffic, Phase 1 sizing |
| Load test at ≥ 1.5× peak when tier ≥ 99.9; failover rehearsed when tier ≥ 99.99 | Phase 2 dates |
| Backup restore rehearsed | Phase 2 date |
| Growth has an archive or retention path in the architecture | Phase 1 components |
| Every dependency classified hard or soft, with an availability and its source | Phase 2 list |
| Every vendor availability cites the SLA page and the tier bought | Phase 2 list |
| Any value recorded `unknown` | the finding is the skill's row for that missing fact |

For each finding, add one sentence stating the smallest change that clears it — drop a tier,
add a replica, make a dependency soft, run the test. The review's job is to make the next
decision cheap, not to list everything that could be better.

Do not invent facts the document lacks. A missing fact is a finding at the severity the skill's
table gives it, and the finding says what to add.

---

## Phase 4: Write the review [REQUIRED]

Write `<specs>/<EPIC>/arch-review.md` (beside the document; for a bare path, `<name>-review.md`
next to it), ≤ 60 lines:

```markdown
# Architecture review — <title>

Reviewed: <path> @ <git short sha or date>
Verdict: <SOUND | GAPS>

## Targets
<the Non-functional targets block, verbatim>

## Dependency chain
<component> = <a1> × <a2> × … = <product> vs stated <tier> → <meets | short by n minutes/month>

## Findings
| # | Severity | Finding | Evidence | Smallest fix |
|---|----------|---------|----------|--------------|
| 1 | blocker | … | arch.md § Data | … |

## Waived
<`Waived: <finding> — <why> — @<who>` lines carried from the document, or "none">

## Not assessed
<anything the document did not let you check, and what would let you>
```

Verdict rule is the skill's: any `blocker` or unwaived `major` → `GAPS`; otherwise `SOUND`.
Commit both files: `docs(arch): review <EPIC> — <verdict>`.

---

## Phase 5: Report

```
## Architecture review — <EPIC>
Targets: <tier> · peak <n> rps · RPO/RTO <a>/<b>
Chain: <product> vs <tier>
Findings: <n> blocker · <n> major · <n> minor · <n> nit
Review: <specs>/<EPIC>/arch-review.md

## Next
GAPS  → resolve the blockers in arch.md and re-run; do not slice into specs yet
SOUND → /sdlc:spec <first slice>; copy the tier and RPO/RTO into each spec's Non-functional section

Verdict: <SOUND | GAPS>
```

The last line is the verdict token; print it exactly, once, last.

---

## Not to be confused with

- **`/sdlc:review`** — grades a pull request's code against its spec. This grades a design
  against its numbers, before any code exists.
- **A capacity plan or cost model** — this checks that the stated tier, traffic and topology
  agree with each other. What the topology costs, and the p99 latency budget per hop, are
  separate questions for a separate review.
- **Approval.** `SOUND` is a recommendation. The spec that follows is still the only gate.
