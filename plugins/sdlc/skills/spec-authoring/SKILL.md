---
name: spec-authoring
description: >
  Write specs that are fuel for agents rather than documents for humans — a fixed section
  layout with stable, testable UC ids that drive implementation, tests, and QA. Use when
  writing or reviewing a spec in specs/<TICKET>/spec.md, turning a ticket or a written request into
  acceptance criteria an agent can execute unattended, deciding whether a spec is ready to
  queue, or splitting an oversized spec.
---

# Spec Authoring

A spec in `specs/<TICKET>/spec.md` is the input to `/sdlc:implement`, `/sdlc:qa`, and the
`aisdlc` queue. Nobody reviews the plan mid-run — approving the spec *is* the approval, so
whatever the spec fails to say, the agent will invent.

Human-facing planning belongs elsewhere: decomposition of a vague ticket, design discussion,
the narrative of why. A spec is narrower — a contract with observable acceptance criteria, sized
for one unattended run and one pull request.

## Format

Fixed sections, in this order. Template: [`references/spec-template.md`](references/spec-template.md).

```yaml
---
ticket: ABC-123
title: Expose an account's balance to its owner
status: draft          # draft → approved (a human sets approved; the queue refuses drafts)
stacks: [backend]
---
```

1. **Problem** — 2–4 sentences: what is broken or missing, and for whom, in the product's own
   vocabulary (if the project has a glossary skill, use its terms). No solution.
2. **Scope** — `In:` and `Out:` bullet lists. `Out:` is the load-bearing one; it is how you
   stop an agent from redesigning an adjacent module.
3. **Context** — file and symbol references into the repo, the contract operation ids, and the
   recorded decisions that constrain this change. Point at code; never describe code in prose.
   `.claude/sdlc.md` says whether this project has a contract directory or ADRs at all — omit
   what does not exist rather than inventing a path.
4. **Acceptance criteria (UC table)** — the heart of the spec, see below.
5. **Non-functional** — only constraints that change the implementation: latency budget,
   transaction boundaries, idempotency, tenancy isolation, audit requirements, numeric precision.
   Omit the section rather than filling it with "should be fast".
6. **Open questions** — anything unresolved. **A spec with open questions cannot be
   `approved`.** Resolve them or move them to `Out:`.

## The UC table

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | account owner | `GET /v1/accounts/a-1001/balance` | 200, `balance` is an integer in minor units, `currency` present | integration |
| UC-2 | account owner | `GET /v1/accounts/unknown/balance` | 404, shared error envelope with code `account_not_found`, no other field | integration |
| UC-3 | other user | requests an account they do not own | 403, nothing about the account leaks into the body | integration |

Rules:

- **Atomic.** One actor, one action, one result. "Creates and notifies and audits" is three rows.
- **Observable.** The result is something a test can read: status code, database row, rendered
  text, emitted event, log entry. "Handles the case correctly" is not a result.
- **Stable ids.** `UC-<n>` ids are referenced from test names, `qa-report.md`, and PR
  comments. Append new ones; never renumber, never reuse a retired id.
- **Negative cases are first-class.** Every validation rule and permission boundary that
  matters gets its own UC. A spec of only happy paths produces an implementation of only
  happy paths.
- **`test` column is a floor, not a cap** — `integration`, `unit`, or `e2e`. `dense-testing`
  defines how many more tests the change needs beyond one per UC.

## Sizing

One spec is one queue task is one pull request. Split when the spec exceeds ~8 use cases, spans
more than two stacks, or contains a row that cannot be tested until another row ships. Split into
`specs/<TICKET>-a/`, `specs/<TICKET>-b/`, each independently shippable, each ordered
walking-skeleton-first. For a ticket needing a narrative sequence of slices, decompose it however
your team normally does, then write one spec per slice.

## Anti-patterns

| Smell | Why it breaks unattended runs |
|-------|-------------------------------|
| Prose paragraphs describing behaviour | The agent cannot tell requirement from background; it satisfies the sentence it noticed |
| UC without an observable result | Nothing to assert, so the agent writes a test that asserts its own implementation |
| Describing existing code instead of linking it | Drifts silently, and the description is what the agent trusts |
| Renumbered UC ids | Breaks the test-name and QA-report traceability chain |
| `status: approved` with open questions | The agent invents the answers, in the worst plausible way |
| Implementation instructions in the spec | Freezes an approach the code may have outgrown; state the *result*, let the playbook pick the how |

## Review checklist

- [ ] Every UC atomic, with a result a test can read
- [ ] Negative and authorization cases present, not just happy paths
- [ ] `Out:` scope lists the adjacent things not to touch
- [ ] Context points at files and contract operations, not prose descriptions
- [ ] No open questions left when flipping to `approved`
- [ ] ≤ 8 UCs and ≤ 2 stacks, or split
- [ ] UC ids stable versus the previous revision
