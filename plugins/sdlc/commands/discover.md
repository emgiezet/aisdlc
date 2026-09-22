---
description: Build an evidence-tagged product brief from existing material, client conversations, or owned-product research. Use before /sdlc:spec when you have research to synthesize — modes existing, client, or own.
allowed-tools: Read, Write, Agent
---

# /sdlc:discover

Evidence before opinions. This command reads what exists, surfaces what is missing, and writes
a product brief where every claim is tagged at the confidence it deserves.

`$ARGUMENTS`: `--mode existing|client|own "<product>"` plus optionally `--research <dir>`
(default `specs/briefs/research/`).

**Load the `discovery` skill** — it holds the product-brief section list, evidence tags,
sizing limits, and the quality gate this command enforces.

Read `.claude/sdlc.md` for `Briefs live in:` (default `specs/briefs/`).

---

## Phase 1: Mode and context gate

| Mode | Source material | Interview subject |
|------|----------------|-------------------|
| `existing` | Code, docs, and issues in this repo | None — read artefacts only |
| `client` | Transcripts and notes in `--research` dir | Product owner or stakeholder |
| `own` | Any combination | Internal team |

**Context gate:** Read every file in `--research <dir>`. State how many files you found and
their total line count. If the dir is empty or absent, note it — do not fabricate source
material. For mode `existing`, also read the repo's open issues and recent commits.

---

## Phase 2: Interview rounds (client and own modes) [REQUIRED]

Ask exactly **one** question per message. Do not combine questions.

Work through: who has the problem, observable success, current workaround, biggest risk,
what the team already decided. Stop when every required section has at least one data point.

---

## Phase 3: Draft each section with quality gate

Write one section at a time. For each section:

- Every factual sentence ends with `[EVIDENCE: <file or interview round>]`, `[ASSUMPTION]`,
  or `[SYNTHETIC]`.
- **Quality gate:** before writing any section, scan every sentence. Any untagged factual
  sentence → tag it or remove it. Do not write the section until every sentence carries a tag.
- A section with no material gets a `Collection plan:` block instead of prose:

  ```
  Collection plan:
  - What to gather: <specific question or artefact>
  - From whom: <role or source>
  - Template: <format for the answer>
  ```

Required sections (discovery skill `product-brief` format): Problem · Who · Stakeholders ·
Rules · Flows · Benchmark · Success criteria · Scope (now / later / not) · Non-goals ·
Decisions (owner each) · Riskiest assumptions (test each) · Open questions

---

## Phase 4: Skeptic review [REQUIRED]

Dispatch an `Agent` with exactly this prompt:

> You are a skeptic reviewing a product brief. Read it and give three findings: the weakest
> evidence claim, the assumption most likely to be wrong, and the section most likely to
> change when a real user is interviewed. One finding per sentence. No hedges.

Incorporate the findings: re-tag weakened claims, move at-risk items to Open questions.

---

## Phase 5: Write and report

Write `<briefs dir>/product-brief.md` (≤ 200 lines).

```
## Discovery complete — <product>
Sections with evidence: <n> · Sections with collection plan only: <n>
Mode: <mode> · Sources: <n files or rounds>

Not yet evidence-backed: <section names, or "none">

Next: /sdlc:brainstorm to refine | /sdlc:synthetic-users to stress-test | /sdlc:backlog to decompose
Brief: <briefs dir>/product-brief.md
```

---

## Not to be confused with

- **`/sdlc:brainstorm`** — for when there is no research yet. Run that first to scope.
- **`/sdlc:synthetic-users`** — stresses the brief by simulating user panels. Run after this.
- **Real user research tools** — surveys, analytics, session recordings. This command records
  and tags evidence; it does not gather it.
