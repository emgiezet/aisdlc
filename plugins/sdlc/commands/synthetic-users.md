---
description: Stress-test a brief by simulating two independent user panels — intersection-only findings, each tagged [SYNTHETIC] with a real-user check. Use after /sdlc:discover to find what the brief misses before filing a backlog.
allowed-tools: Read, Write, Agent
---

# /sdlc:synthetic-users

Synthetic input is cheaper than real interviews and worth less. Use it to find what the brief
is not saying, then schedule real-user time for the findings that survive both panels.

`$ARGUMENTS`: `<brief>` (path) `--flow "<name>"` `[--stance validate|simulate|adversary]`

Default stance: `validate`.

**First action:** check `<brief>` exists. If not, print
`no brief at <brief> — run /sdlc:discover first` and stop.

**Load the `discovery` skill** — it holds the evidence-tag rules and the no-numbers constraint.

---

## Phase 1: Personas from the brief

Read the brief. Extract personas **only** from sentences tagged `[EVIDENCE: …]` or
`[ASSUMPTION]`. Do not invent personas from untagged text or from general knowledge. If no
tagged person-like claim exists, print
`brief has no tagged user claims — add evidence before running panels` and stop.

---

## Phase 2: Two independent panel runs [REQUIRED]

Dispatch **two** `Agent` subagents independently, with no shared context between them.
Each receives the brief text, the flow name, the stance, and exactly this prompt:

> You are a panel of three users of this product. You have just tried the flow: "<flow>".
> Respond as each user in turn. Stance: <stance>. Rules: no numbers or percentages, one
> observation per user per turn, tag every sentence [SYNTHETIC].
>
> Stance meanings:
> - validate: find what works as the designers intended
> - simulate: find what is unclear, surprising, or ambiguous
> - adversary: find what fails or can be abused; discard any finding where all three users
>   agreed with the design — only disagreement survives

Collect both outputs before proceeding.

---

## Phase 3: Intersection [REQUIRED]

Compare the two panel outputs. Keep only findings present in **both** runs. Discard any
finding that appears in only one run.

If the stance is `adversary`, apply an additional filter: discard any finding where both
panels agreed with the design. Only adversarial disagreements survive.

---

## Phase 4: Report

Every line of output in the findings:

- Ends with `[SYNTHETIC]`
- Contains no numbers, percentages, or numeric ranges
- Is paired with a `Real-user check:` line

Format per finding:

```
Finding: <observation> [SYNTHETIC]
Real-user check: <one sentence — what to ask or observe with a real person>
```

Print the summary, then the findings:

```
## Synthetic panel — <flow>
Stance: <stance> · Brief: <brief>
Run-1 findings: <n> · Run-2 findings: <n> · Intersection: <n>

<findings>

Next: update the brief with surviving findings tagged [ASSUMPTION], then /sdlc:backlog
```

---

## Stances

| Stance | Keeps | Discards |
|--------|-------|----------|
| `validate` | Observations that confirm the design works | Failures and confusions |
| `simulate` | Surprises and ambiguities | Confirmations |
| `adversary` | Disagreements with the design | Agreement with the design |

---

## Not to be confused with

- **Real user research** — interviews, usability tests, surveys. This command produces
  `[SYNTHETIC]` output only; it never replaces a real session.
- **`/sdlc:discover`** — gathers and tags existing evidence. Run that first; this command
  reads the brief it produces.
- **`/sdlc:backlog`** — files the work. Run after incorporating findings into the brief.
