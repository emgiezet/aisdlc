---
description: Decide the UX direction for a flow before writing code — one question at a time, five required states, the riskiest assumption. Use before /sdlc:mockup to give it a decided direction and a states list.
allowed-tools: Read, Write
---

# /sdlc:ux-shape

A decided direction before pixels. This command asks the right questions to fill
`specs/briefs/ux-<slug>.md`; `/sdlc:mockup` reads that file in Phase 1 to know which
states to build and what direction to take.

`$ARGUMENTS` is the flow name as text (e.g. `"quick-add for the people list"`).

Read `.claude/sdlc.md` for `Briefs live in:` (default `specs/briefs/`). Derive `<slug>`
from the flow name: lowercase, spaces to hyphens, drop punctuation.

---

## Phase 1: Direction questions [REQUIRED]

Ask exactly **one** question per message. Do not combine questions.

Work through these in order:

1. What triggers this flow? (the entry point — button, page load, external event)
2. What does success look like in a single sentence from the user's point of view?
3. Which existing patterns in this product should it match? (navigation, confirmation, feedback style)
4. What does the user risk if the flow fails or they make a mistake?
5. Is there a performance or timing constraint visible to the user?

Stop when you can write Direction and Scope with enough specificity for a mockup.

---

## Phase 2: States

For each of the five required states, ask the user what should appear. Ask them one at a time
if the user has not described them already.

| State | What the user should see |
|-------|--------------------------|
| empty | no data yet, or first use |
| loading | operation in progress |
| error | something went wrong + recovery action |
| denied | access refused + what to do instead |
| success | confirmation + next action |

Record `TBD — needs design decision` for any state the user cannot describe.

---

## Phase 3: Write the UX brief [REQUIRED]

Write `<briefs dir>/ux-<slug>.md` (≤ 60 lines):

```markdown
---
slug: <slug>
flow: <flow name>
---

# UX shape: <flow name>

## Direction

<one paragraph: what this flow does, how it fits the product's existing patterns>

## Scope

In: <what the mockup must show>
Out: <what to leave for a later iteration>

## States

| State | Content |
|-------|---------|
| empty | <what appears when there is nothing> |
| loading | <spinner / skeleton / message> |
| error | <message + recovery action> |
| denied | <why + what to do instead> |
| success | <confirmation + next action> |

## Riskiest assumption

<one sentence: the thing most likely to be wrong about this direction>

Test: <how to validate it — user test, A/B, or data query>
```

---

## Phase 4: Hand off

```
## UX shape decided — <flow>
Brief: <briefs dir>/ux-<slug>.md

Next: /sdlc:mockup <TICKET> — reads this file for direction and states
```

---

## Not to be confused with

- **`/sdlc:mockup`** — builds the clickable file. Run after this command supplies the brief.
- **`/sdlc:ux-review`** — reviews a PR's UI against the design system. Different stage.
- **`/sdlc:ux-setup`** — writes the design-system rule. Run once per repo, not per flow.
