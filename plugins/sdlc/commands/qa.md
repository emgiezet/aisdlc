---
description: Independently verify an implementation against its spec and close the test gaps — runs the auto-qa agent to build a UC×test coverage matrix, closes the gaps it finds, and writes specs/<TICKET>/qa-report.md with a PASS/GAPS verdict. Use after /sdlc:implement, before opening a PR or reviewing agent-written code.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
---

# /sdlc:qa

The step that decides whether a human should spend attention on this branch. It runs before
anyone reads the code, and its verdict is what they read first.

`$ARGUMENTS` is the ticket id. Read `.claude/sdlc.md` for the specs directory and the
verification commands; paths below assume the default `specs/`.

**First action, before anything else:** check that `specs/<TICKET>/spec.md` exists. If it does not,
print `no spec at specs/<TICKET>/spec.md — nothing to verify against` and stop. Do not search the
repository, do not look for the ticket elsewhere, do not reconstruct the requirements from the
diff. Verifying code against itself is worthless, and a missing file is an answer that must cost
one tool call.

Also requires a branch carrying the implementation (typically `ai/<TICKET>-<slug>`). If the diff
against the base ref is empty, say so and stop — there is nothing to verify yet.

---

## Phase 1: Independent verification

**Subagent mode:** dispatch the `auto-qa` agent with the ticket id, the spec path, and the
diff base. It reads the spec before the code deliberately, so do not pre-digest the
implementation for it in the prompt.

**Inline mode:** follow the `auto-qa` agent's order of work yourself — spec first, then diff,
then tests, then run everything, then hand-verify the UCs no test covers. The order is the
method; reading the implementation first makes you agree with it.

Either way the output is a UC×test matrix, real suite output, and a findings list.

---

## Phase 2: Close the gaps

For every gap the matrix shows — a UC with no test, or a test asserting something weaker than
its UC:

- **Subagent mode:** dispatch a test-writing subagent per gap, with the specific use-case row,
  its required observable result, and the file where the sibling tests live. One dispatch per gap
  keeps each context small and the tests focused.
- **Inline mode:** write the tests yourself, following `dense-testing`.

Rules for this phase:

- New tests carry their `UC-<n>` id in the name.
- A new test that fails is a **finding, not a task**: it means the implementation does not
  satisfy that UC. Do not fix the implementation here — record it and let the verdict be
  `GAPS`. Silently repairing the code is how a QA step stops being a check.
- Do not weaken an existing test to reconcile it with the code. A test contradicting the spec
  goes in the findings with both sides quoted.
- Scope creep found in the diff stays in the findings. Do not delete someone else's code as
  part of QA.

Then re-run the affected suites and refresh the matrix with the real numbers.

---

## Phase 3: Report

Write `specs/<TICKET>/qa-report.md` in the `auto-qa` format: verdict on the first line, UC
coverage table, exact suite output with skip counts, numbered findings with file and line, and
an explicit "Not verified" section.

Verdict rules:

- **PASS** — every UC has a passing test carrying its id, zero skips, no blocking finding.
- **GAPS** — anything else. A UC verified only by hand is `GAPS`: unattended work needs a
  regression net, not a one-time observation.

Never round up to PASS. The queue's value depends on this verdict being trustworthy: a human
who learns that PASS sometimes means "nearly" has to read every diff again, and the whole
pipeline collapses back to manual review.

**Then commit — the report is an artefact, not a scratch file.** `git add` the report plus any
tests written in Phase 2, and commit as `test(<scope>): QA report and coverage gaps (<TICKET>)`.
Leaving them uncommitted strands the evidence in a worktree, and `/sdlc:ship` refuses to run on
a dirty tree, so an unattended task would stall here with the work already done.

```
## QA complete — <TICKET>
Verdict: PASS | GAPS (<n> findings, <n> blocking)
UC coverage: <n>/<n> automated · Tests: <before> → <after> · Skipped: 0
Report: specs/<TICKET>/qa-report.md

## Next
PASS → /sdlc:ship <TICKET>
GAPS → fix the blocking findings, then re-run /sdlc:qa <TICKET>
```

---

## Not to be confused with

- **A test-writing agent** — writes tests on request. This command decides *which* tests are
  missing and why, then delegates the writing.
- **A code review agent or human review** — judges code quality, style, and maintainability. This command
  judges only one thing: does the code do what the spec said. Both belong on an agent-written
  PR; neither substitutes for the other.
- **Deployment readiness checks** — whatever your project runs before a release. Downstream of
  this, and not a substitute: passing QA says the code matches the spec, not that it is safe to
  ship on a Friday.
