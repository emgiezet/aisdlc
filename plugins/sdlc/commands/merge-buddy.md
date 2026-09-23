---
description: Read-only snapshot of the merge queue — two tables showing which labelled PRs can merge now and which are close but blocked, with the first blocking gate as the reason. Use when deciding what to merge next or when triaging the review inbox before running /sdlc:merge.
allowed-tools: Bash, Read, Grep, Glob, Agent
---

# /sdlc:merge-buddy

`$ARGUMENTS` is ignored. This command reads and reports only — it never calls `merge-pr`,
`review-pr`, `label-pr`, or any other mutation.

Read `.claude/sdlc.md` for the **Tracker descriptor** and the profile PR label (`ai-sdlc`).

---

## Phase 1: Collect PRs

Read `.aisdlc/config.json`. If it contains a `model_roles` key, dispatch `sdlc-scribe` to run
this phase: pass it the profile label and the fields below. It returns one row per PR — number,
title, pipeline label, required-check states, `mergeable`, and the newest `Verdict:` token or
`null` — and nothing else; comment threads and check payloads stay in its context. Classification
in Phase 2 is yours either way. Without the key, collect the same fields yourself:

1. **list-prs** `open` with the profile label — retrieve number, title, labels, url for each.
2. For each PR:
   - **get-pr** `<n>` — read `mergeable` and the full comment list.
   - **get-pr-checks** `<n>` — collect name and state for every required check.
   - Scan PR comments newest-first for a line starting `Verdict:`. Record the token
     (`PASS`, `GAPS`, or absent).

---

## Phase 2: Classify

Apply the four gates in this order; classify a PR by its **first failing gate**:

| # | Gate | Pass |
|---|---|---|
| 1 | Pipeline label | exactly `merge-ready` |
| 2 | CI checks | all required checks pass |
| 3 | Conflicts | `mergeable` is not `CONFLICTING` |
| 4 | QA verdict | latest `Verdict: PASS`, no blocking `GAPS` finding |

A PR that passes all four goes in **Can merge now**. Any failure puts it in
**Close but blocked** with the gate number and reason.

---

## Phase 3: Report

Print two tables. State only; never print a recommended action or a `/sdlc:merge` command.

### Can merge now

| PR | Title | CI | Mergeable |
|---|---|---|---|
| #<n> | <title> | ✓ | ✓ |

If the bucket is empty: `No PRs are merge-ready right now.`

### Close but blocked (<reason>)

| PR | Title | Blocked by |
|---|---|---|
| #<n> | <title> | gate 1: label is changes-requested |
| #<n> | <title> | gate 2: CI — <check-name> failing |
| #<n> | <title> | gate 3: conflicts |
| #<n> | <title> | gate 4: QA GAPS (blocking finding) |
| #<n> | <title> | gate 4: no QA verdict comment yet |

If the bucket is empty: `No PRs are blocked.`

---

## Not to be confused with

- **`/sdlc:merge`** — interactive command that executes the merge after the gates above pass.
  This command only reports state; it never calls `merge-pr`.
- **`/sdlc:review-prs`** — iterates open PRs and runs the review engine to produce the
  `Verdict:` comment. Run that first to populate the QA verdict column; run this to read it.
- **`/sdlc:autopilot`** — diagnoses the same signals and chains the next command. This command
  only prints; autopilot acts.
