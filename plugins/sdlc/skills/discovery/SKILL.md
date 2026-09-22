---
name: discovery
description: >
  The vocabulary and format rules for discovery artefacts — brief files, evidence tags, and
  the Definition of Ready. Use when writing or reading a brief, tagging a claim as evidence
  or assumption, deciding whether a ticket is ready to spec, or running any discovery command
  (/sdlc:brainstorm, /sdlc:discover, /sdlc:synthetic-users, /sdlc:backlog, /sdlc:ux-shape).
---

# Discovery

Pre-spec artefacts live in `specs/briefs/` (C1 `Briefs live in:` key). A brief captures
claims at varying confidence levels. The evidence-tag system tells `/sdlc:backlog` and
`/sdlc:spec` which claims are ready to act on.

## Evidence tags

Every factual sentence in a brief ends with exactly one tag:

| Tag | Meaning |
|-----|---------|
| `[EVIDENCE: <source>]` | A human produced it; source named |
| `[ASSUMPTION]` | No human source; inferred or guessed |
| `[SYNTHETIC]` | Output of a synthetic-users run |

**A tag never upgrades.** `[SYNTHETIC]` stays `[SYNTHETIC]`. `[ASSUMPTION]` stays until a
human provides a source — then rewrite the sentence with `[EVIDENCE: <source>]`. The tag on
a sentence is the lowest confidence it has ever had.

`/sdlc:backlog` refuses when the Problem section contains any `[ASSUMPTION]` (UC-6).

## Brief formats

`specs/briefs/<slug>.md` — ≤ 80 lines. Blank: `references/brief-template.md`.

Sections in order: **Problem** · **Expected outcome** · **Alternatives considered**
(always includes "do nothing") · **Non-goals** · **Decisions** (owner each) · **Open questions**

`specs/briefs/product-brief.md` — ≤ 200 lines.

Sections in order: Problem · Who · Stakeholders · Rules · Flows · Benchmark · Success criteria ·
Scope (now / later / not) · Non-goals · Decisions (owner each) · Riskiest assumptions (test each) ·
Open questions

`specs/briefs/ux-<slug>.md` — ≤ 60 lines. Produced by `/sdlc:ux-shape`.

Sections: Direction · Scope · States (empty, loading, error, denied, success) ·
Riskiest assumption + test

## Definition of Ready

A brief is ready to pass to `/sdlc:spec` when all three hold:

1. Problem and who has it stated with `[EVIDENCE: …]` (not `[ASSUMPTION]`)
2. Expected outcome is observable and written down
3. No blocking open question remains

`/sdlc:init --discovery` writes this block into `.claude/sdlc.md`.

## Sizing

| Artefact | Limit | Why |
|----------|-------|-----|
| `specs/briefs/<slug>.md` | ≤ 80 lines | Loads beside the router and a playbook |
| `specs/briefs/product-brief.md` | ≤ 200 lines | Loads beside the router and a spec |
| `specs/briefs/ux-<slug>.md` | ≤ 60 lines | Loaded in `/sdlc:mockup` Phase 1 |

## Anti-patterns

| Pattern | Consequence |
|---------|-------------|
| Factual sentence with no tag | `discover` quality gate rejects; brief is blocked |
| `[SYNTHETIC]` treated as `[EVIDENCE]` | Invalidates the `backlog` readiness gate |
| Problem entirely `[ASSUMPTION]` | `backlog` refuses until research fills it |
| Numeric claims in synthetic output | Anchors the team to invented figures |
| Brief over its size limit | Cannot load beside a spec context |

## Review checklist

- [ ] Every factual sentence ends with exactly one evidence tag
- [ ] No `[ASSUMPTION]` in Problem (if passing to `backlog`)
- [ ] "Do nothing" appears in Alternatives considered
- [ ] Each Decision has an owner
- [ ] Open questions are genuine questions, not deferred tasks
- [ ] Sizes within limits above
