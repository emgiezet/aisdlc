---
description: Deliver an approved spec end-to-end with no human gates — reads specs/<TICKET>/spec.md, routes through the matching playbook, writes one test per UC before its implementation, runs the full CI matrix, and stops hard with BLOCKED.md if it cannot finish. The unattended half of the pipeline, built to be run by the aisdlc queue.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
---

# /sdlc:implement

`$ARGUMENTS` is the ticket id (e.g. `ABC-123`), matching `<specs dir>/<TICKET>/spec.md`.

**Read `.claude/sdlc.md` first** — it names the specs directory, the verification commands,
the contract directory, and what is out of bounds repo-wide. No profile → detect what you can
and say what you assumed.

Runs with **no human in the loop**. Nobody will answer a question, approve a plan, or confirm a
summary. The approved spec is the approval. That changes three things versus a supervised build:

- Ambiguity is not resolved by asking — it is either resolved from the spec and the codebase,
  or it is a hard stop.
- There is no "present the plan" step. The UC table *is* the plan.
- Finishing in a broken state is worse than not finishing. A clean failure with evidence is a
  successful run of this command.

Load the `dense-testing` skill — density floors and the non-negotiables. Work surgically: touch
only what the spec requires, match the surrounding style, and let every changed line trace to a
use case or to the density grid.

---

## Phase 0: Gate on the spec [HARD STOP]

**Your first action is to read `specs/<TICKET>/spec.md`.** Nothing else — no repository survey, no
search for the ticket elsewhere, no reconstructing requirements from the code. Refuse to proceed,
with a one-line reason, if:

- the file does not exist → "no spec at specs/<TICKET>/spec.md — run /sdlc:spec <TICKET>"
- `status:` is not `approved` → "spec is <status>; a human must approve it"
- the `Open questions` section still has unchecked boxes → "open questions block execution"
- the UC table is empty or has a row with no observable result → "UC-<n> has no testable result"

For `kind: bugfix` specs: first confirm `approved-by` is present and matches
`^issue #[0-9]+` — if not, refuse with "bugfix spec requires approved-by: issue #<n>".
Then run **get-issue** on issue `<n>` and confirm it still carries label `bug` — label absent
means the approval is revoked; refuse with "bugfix approval revoked: issue #<n> no longer
labelled bug".

Refusing here costs one tool call. Guessing here costs a bad pull request that a human has to read,
and the wandering that precedes the guess costs more than the whole task should.

---

## Phase 1: Route and ground

1. Match the work to a row in the project's `CLAUDE.md` **Task Router** and read **only** that
   playbook. Spanning two stacks means two playbooks — no more.
2. Read the files named in the spec's `Context` section. If a fresh `.codebase-map/` exists,
   read the relevant map files; otherwise grep for the nearest sibling implementation and
   mirror it.
3. Build the **CI verification matrix** per
   [`ci-matrix.md`](../skills/dense-testing/references/ci-matrix.md) for the touched stacks
   only. Verify each tool is actually installed now — discovering a missing binary after
   writing the code wastes the whole run.
4. Create the working branch if not already on one: `ai/<TICKET>-<slug>`.

Output a 3–5 bullet grounding summary. Then start writing code — there is no gate here.

---

## Phase 2: Build, one UC at a time

Order the UCs walking-skeleton first: the one that proves the path end-to-end, then the rest,
negatives last. For each UC in order:

1. **Write the test first**, named with its id (`…UC3…`, `'UC-3: …'`). Assert the UC's
   observable result, not the implementation you are about to write.
2. **Run it. Confirm it fails for the right reason** — a compile error or a missing fixture is
   not a red test, it is a broken test. Fix it until it fails on the assertion.
3. **Implement the minimum** that makes it pass, following the playbook's sequence.
4. **Run it again.** Green → next UC. Not green after one targeted fix → Phase 4.
5. Commit per UC: `type(scope): <UC summary> (<TICKET>)`. Per-UC commits make the PR readable
   and give a bisect point when one UC turns out wrong.

Then fill the density grid from `dense-testing`: unit test per public symbol, case per error
return and validation rule, case per branch, render state per UI state. This is where most of
the test count comes from, and it is not optional.

Never touch anything in the spec's `Out:` scope. If the change appears to require it, that is
Phase 4, not a judgement call.

---

## Phase 3: Verify

Run the full CI matrix in order, with the one-fix-then-stop rule from `ci-matrix.md`. Then
self-check before handing off:

- `grep -rho 'UC-[0-9]\+' <test paths> | sort -u` covers every UC in the spec.
- Skip count is zero. No test was deleted or weakened — `git diff` proves it.
- `git status` is clean; nothing untracked that should be committed, no debug leftovers, no
  commented-out code.
- Every changed line traces to a UC or to the density grid.

All green → Phase 5. Anything red after its one fix → Phase 4.

---

## Phase 4: Blocked [HARD STOP]

Write `specs/<TICKET>/BLOCKED.md` and exit non-zero. No partial success reporting, no
"mostly done".

```markdown
# BLOCKED — <TICKET>
**Stopped at:** <UC-n / CI command / spec contradiction>

## What happened
<the exact command and its full output, or the two requirements that contradict>

## What I tried
<the single fix attempted and why it did not work>

## What I need from a human
<the specific decision or missing piece — one question, answerable>

## State
Branch `ai/<TICKET>-<slug>`, <n> commits, UCs done: UC-1, UC-2. Working tree: clean/dirty.
```

Stop here for: a spec/test contradiction, a second failure of the same CI command, a required
change inside `Out:` scope, a missing credential or service, an ambiguity with two defensible
readings. Committing what works before stopping is correct — leave the branch inspectable.

---

## Phase 5: Hand off

Do not open a PR from here; `/sdlc:ship` does that after QA.

```
## Implemented — <TICKET>
Branch: ai/<TICKET>-<slug> · <n> commits
UCs: <n>/<n> with tests carrying their ids
Tests: <before> → <after> · skipped: 0
CI matrix: <command> ✓ · <command> ✓ · …

## Next
/sdlc:qa <TICKET>     — independent verification against the spec
/sdlc:ship <TICKET>   — draft PR with the QA report attached
```

---

## Not to be confused with

- **A supervised build loop** — whatever your project uses when you are sitting there watching,
  with a plan-review gate and a sign-off at the end. Those gates make it unusable in a queue,
  which is the whole reason this command exists. Use the supervised path for exploratory work and
  this one for work whose contract is already settled.
- **`/sdlc:qa`** — verifies what this command built. Deliberately a separate run with a fresh
  context: an agent checking its own work in the same session grades its own homework.
