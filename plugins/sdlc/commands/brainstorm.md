---
description: Think through an idea before writing a spec — one question at a time, alternatives including doing nothing, a challenger's objection, and a routed next step. Use to turn a vague idea into a brief or decide not to build it.
allowed-tools: Read, Write, Agent
---

# /sdlc:brainstorm

Cheap thinking before expensive building. The goal is to arrive at the `Next:` line knowing
which step is right, or to decide nothing should be built at all.

`$ARGUMENTS` is the idea, as text. No spec, no ticket — that is what this command produces.

**Load the `discovery` skill** — it holds the brief format, evidence tags, and the
Definition of Ready this command must satisfy.

Read `.claude/sdlc.md` for `Briefs live in:` (default `specs/briefs/`).

---

## Phase 1: Understand the idea [REQUIRED]

Ask exactly **one** question per message. Do not ask more than one at a time — a weak model
asked five things answers the last one. Each reply answers one question; ask the next.

Work through these in order, stopping once the answer is clear:

1. Who has the problem? Name a specific role or situation, not "users in general".
2. What happens now without this feature? (the current workaround or pain)
3. What would success look like in observable terms?
4. Who else is affected or would push back on this change?

Stop asking when you can write Problem and Expected outcome with `[EVIDENCE: …]` tags
sourced from the session replies.

---

## Phase 2: Alternatives table

Present a table of options before recommending anything:

| Option | What it does | Effort | Value |
|--------|-------------|--------|-------|
| Build nothing | Keeps the current state | — | — |
| `<option>` | … | low/medium/high | low/medium/high |

"Build nothing" is always the first row. Omitting it is a refusal to engage with the real
choice. Estimate effort and value only from what the session established — never guess.

---

## Phase 3: Challenger [REQUIRED]

Dispatch an `Agent` with exactly this prompt:

> You are a skeptic. You have heard this proposal: "<idea>". Give three objections — the
> sharpest objection, the most practical one, and the one the proposer probably agrees with
> but hopes everyone will ignore. One sentence each. No qualifiers.

Quote the challenger's three objections verbatim in the report below.

---

## Phase 4: Brief and routing

Write `<briefs dir>/<slug>.md` (≤ 80 lines) using the discovery skill's brief format:
Problem, Expected outcome, Alternatives considered, Non-goals, Decisions, Open questions.
Every factual sentence takes a tag. `[EVIDENCE: session reply]` is acceptable for claims the
human typed in this session. Unverified claims take `[ASSUMPTION]`.

Print the brief path and the routing line as the final output:

```
## Brainstorm complete
Challenger objections:
1. <verbatim>
2. <verbatim>
3. <verbatim>

Brief: <briefs dir>/<slug>.md

Next: /sdlc:spec <T> | /sdlc:issue | /sdlc:discover | none
```

Choose the next step:

| Next | When |
|------|------|
| `/sdlc:spec <T>` | Idea is well-understood; Definition of Ready is met |
| `/sdlc:issue` | Something is broken; file the bug without a brief |
| `/sdlc:discover` | More research needed before scoping |
| `none` | "Build nothing" won the alternatives table |

---

## Not to be confused with

- **`/sdlc:spec`** — writes a machine-executable spec. Run after this command, not instead.
- **`/sdlc:discover`** — mines existing material for evidence. Run when you have research;
  `brainstorm` is for when you have none yet.
- **`/sdlc:issue`** — files a bug or feature request. Run `brainstorm` first if you want to
  think it through; file the issue immediately if the problem is already clear.
