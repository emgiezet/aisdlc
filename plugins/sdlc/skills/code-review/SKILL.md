---
name: code-review
description: >
  Severity scale, verdict rule, review checklist, and spec-review lenses for pull-request
  inspection. Use when reviewing a PR, deciding a verdict, or writing a finding.
---

# Code Review

## Evidence

A finding is reportable only when all four hold. Short of that it is not a finding, and saying it
anyway costs the review its credibility.

| Requirement | Test |
|---|---|
| Changed-line citation | the `file:line` it cites is an added or modified line of this PR's diff. A finding about a line the PR did not touch is dropped before the verdict. |
| Concrete condition | the input, state or sequence that triggers it — never "could be" or "may not handle" |
| Traced path | the call or control path from that condition to the wrong outcome |
| Observable wrong result | what a person or a test can read: status code, stored row, exit code, message, missing event |

Findings the command computes itself — Phase 3 signals, and everything imported from
`specs/<TICKET>/scope-report.md` or the slop-guard report — cite whole files by design and are
exempt from the changed-line test.

### A blocker or major carries three more lines

| Line | Content |
|---|---|
| `Repro:` | the steps, and the wrong result they produce |
| `Loss:` | what the user or the project loses. An untidy internal, a label, or something only an agent reads is not a loss |
| `Blame:` | this diff causes it, or this diff is the change that exists to fix it |

When `Blame:` fails — the base behaves the same way — report it as
`[minor] Pre-existing: <description>`. A pre-existing condition never blocks a PR; it becomes a
follow-up through `/sdlc:followup`. Arguing that a pre-existing condition should block means
making the `blocker` case on this diff's own evidence, not reclassifying by insistence.

## Severity scale

| Severity | Definition | Harness example |
|----------|------------|-----------------|
| `blocker` | Correctness, security, or test-baseline violation | Test deleted or skipped in the diff |
| `major` | Spec boundary or non-negotiable violated | File in the spec's `Out:` scope modified; density floor missed |
| `minor` | Co-change missing or consistency gap | Contract file updated without bumping its dependent handler |
| `nit` | Style or naming, non-blocking | Identifier doesn't follow the project's naming convention |

## Verdict rule

Any open `blocker` or `major` → `CHANGES_REQUESTED`. Only `minor` or `nit` findings open →
`APPROVED`. A finding a human waived or rejected by its ledger id is no longer open. `/sdlc:review`
derives the verdict from the PR findings ledger (`aisdlc-ledger verdict`), never from prose.

Waiver format — place in the PR body, one line per finding, by its ledger id:

```
Waived:   F<id> — <why this is acceptable> — @<approver>
Rejected: F<id> — <why this is not a finding> — @<approver>
```

A waiver without `@<who>` does not count. This form addresses the PR findings ledger
(`pipeline-contracts` → `## Findings ledger`); `/sdlc:arch-review`'s
`Waived: <finding> — <why> — @<who>` line is a different artefact and is unchanged.

## Review checklist

For code PRs, every item below is a finding when violated.

| Check | Severity |
|-------|----------|
| Every `UC-<n>` in the spec has a passing test carrying its id | `blocker` |
| Full CI matrix for every touched stack is green; skip count is zero | `blocker` |
| New tests sit at the lowest tier that can observe their result; no higher tier re-asserts a behaviour a lower one pins | `minor` |
| No file listed in the spec's `Out:` scope was modified | `major` |
| `qa-report.md` present and says `PASS` with an explicit "Not verified" section | `major` |
| Contract directory changed in the same commit as any handler whose contract moved | `minor` |
| PR is a draft, labelled, riskiest changes called out by `file:line` | `nit` |
| No hardcoded credentials; unvalidated input does not reach exec/eval; no new permissions without a spec row | `blocker` |
| Every operation the diff touches is traceable to a SKILL.md entry or spec row | `minor` |
| A new endpoint or schema field introduces a second error shape instead of the API's existing envelope (`rest-api-design`, `graphql-api-design`) | `major` |
| A published path, field, enum value or error code was removed, renamed or retyped in place, with no deprecation | `blocker` |
| A collection endpoint or list field ships with no bounded page size | `major` |

| Branch inside its `Change budget:` (or the repo default) for added lines, files and modules | `major` |
| Added lines past the repo's hard ceiling, or a scope report naming shotgun surgery | `blocker` |
| Mechanical change (rename, codemod, generated update) mixed into a behaviour change | `major` |

## Imported findings

`/sdlc:review` adds these itself, with exactly these titles; the reviewer never re-measures them.
They carry no `file:line` and are exempt from the changed-line test.

| Source | Entry | Finding |
|---|---|---|
| `.aisdlc/slop-guard/report.json` (or the `slop-guard:` path in `.claude/sdlc.md`) | an item it marks blocker | `[blocker] <its text>` |
| `specs/<TICKET>/scope-report.md` | a file **out of bounds** | `[blocker] scope violation: <file> (out of bounds)` |
| | a file **undeclared** | `[major] scope gap: <file> (not declared in spec)` |
| | `Verdict: BLOCKED` | `[blocker] scope-check BLOCKED` — the PR should not have reached review |
| | a `## Size` finding | `[major] over change budget: <measure> (<n> vs <budget>)`; `[blocker]` past the hard ceiling or naming shotgun surgery |
| | `## Structure` `erosion:` or `new hotspot:` | `[major] structural erosion: <finding text> — split the function or run /sdlc:decompose` |
| | `## Structure` `hotspot over 25:` | `[blocker] structural erosion: <finding text> — split the function or run /sdlc:decompose` |

A size breach is a decomposition finding, never a request for a more careful reviewer: the remedy
is `/sdlc:decompose <TICKET>`. A spec that declared a wider `Change budget:` for a mechanical slice
is compliant — the budget it set is the budget that applies. Structure needs `lizard` on the runner
PATH; `## Structure` saying `skipped: …` imports nothing. Structure never causes `BLOCKED`; it
promotes `PASS` → `GAPS` only.

## Spec-review lenses

When every changed file is under `specs/`, skip the code checklist and apply these lenses:

| Lens | What to look for |
|------|-----------------|
| Risks | Runtime failures if this spec ships as written |
| Compatibility | Changes that break a contract surface, label set, or API shape |
| Gaps | UCs lacking an observable result, a test column entry, or marked e2e without a critical journey |
| Improvements | Simpler ways to express the same intent |
| Simplicity | Constraints that over-specify without adding safety |

Report each finding with its lens name and `<section>:<line>` reference.

## Finding format

```
[blocker] <description> — `file:line`
  Repro: <steps> → <wrong result>
  Loss:  <what the user or the project loses>
  Blame: <this diff causes it | this diff exists to fix it>
[major]   <description> — `file:line`
  Repro: … / Loss: … / Blame: …   (same three lines as a blocker)
[minor]   <description> — `file:line`
[nit]     <description> — `file:line`
```

Rank: blockers first, then majors, minors, nits. End the review body with exactly:

```
Verdict: APPROVED
```

or

```
Verdict: CHANGES_REQUESTED
```

Never emit both; never paraphrase the tokens.
