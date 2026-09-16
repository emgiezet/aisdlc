---
name: ship
description: >
  Use when /sdlc:qa has passed and the implementation branch is ready to be pushed as a draft
  PR with the spec and QA verdict attached, or from the aisdlc queue as the final delivery step.
allowed-tools: Bash(git:*), Bash(gh:*), Read, Write, Grep, Glob
---

# /sdlc:ship

The delivery end of the unattended pipeline. Its job is to make a human's next two minutes
efficient: the PR must say what was asked, what the QA verdict is, and where to look first.

The invocation input is the ticket id. Read `.claude/sdlc.md` for the specs directory, the pull
request label, and the branch convention; paths below assume the default `specs/` and label
`ai-sdlc`.

Requires `specs/<TICKET>/spec.md` and, unless `--no-qa` is passed, `specs/<TICKET>/qa-report.md`.

---

## Phase 1: Preflight [HARD STOPS]

**First action, before anything else:** check that `specs/<TICKET>/spec.md` exists. If it does
not, print `no spec at specs/<TICKET>/spec.md — nothing to ship` and stop. Do not search the
repo, do not look for the ticket in a tracker, do not ask where it went. A missing file is an
answer, and finding that out must cost one tool call.

Then refuse, with a one-line reason, if:

- `specs/<TICKET>/qa-report.md` is missing → "run /sdlc:qa first"
- the QA verdict is `GAPS` and it has a blocking finding → "QA blocking; fix before shipping"
- `specs/<TICKET>/BLOCKED.md` exists → "implementation stopped blocked"
- the working tree is dirty → commit or explain; never `git add -A` blind at this stage
- the current branch is `main`, `master`, or `develop` → "refusing to ship from a shared branch"
- `git log <base>..HEAD` is empty → "nothing to ship"

`gh` unavailable or unauthenticated → skip to Phase 4 (offline handoff) instead of failing.

---

## Phase 2: Open the PR

1. Push: `git push -u origin HEAD`.
2. Compose the body from the spec and the QA report — never from the diff alone. Order
   matters: verdict and scope first, file tour last.

```markdown
## <TICKET> — <spec title>
**QA verdict: PASS** · UC coverage: 8/8 automated · Tests: 412 → 448 · Skipped: 0

🤖 Written by an agent from `specs/<TICKET>/spec.md`. Review the spec's `Out:` scope first —
that is where an unattended run is most likely to have overstepped.

### What the spec asked for
<the UC table, verbatim>

### How to verify
<the exact CI commands that were run, so a reviewer can repeat them>
<for UI work: the mockup path and the Playwright scenario names>

### Review here first
<the 1–3 riskiest changes, with file:line — money maths, permission checks, migrations>

### Not covered
<anything from the QA report's "Not verified" section, or "nothing">
```

3. `gh pr create --draft --title "type(scope): <summary> (<TICKET>)" --body-file <tmp>`.
   Always `--draft`: an agent-authored PR entering review unread is how the review habit dies.
4. Label it with the profile's label: `gh pr edit --add-label <label>` (create it once if
   missing). The label is what makes `aisdlc inbox` and a phone-sized `gh pr list` work.
5. Post the QA report as a comment: `gh pr comment --body-file specs/<TICKET>/qa-report.md`.
   In the comment, not the body — the body stays scannable, the evidence stays one click away.
6. If a migration is in the diff, say so in the body and request review attention explicitly.

---

## Phase 3: Report

```
## Shipped — <TICKET>
PR: <url> (draft, label ai-sdlc)
QA: PASS · UC 8/8 · tests 448
Review first: <file:line>
```

---

## Phase 4: Offline handoff

No `gh`, no auth, or no remote: write `specs/<TICKET>/pr-body.md` with the same content, leave
the branch pushed if a remote exists, and report the branch name plus that path. The work must
never be lost because the delivery channel was missing.

---

## Not to be confused with

- **A human-facing PR generator** — one that interviews the diff while you watch. This command is
  non-interactive, refuses on a blocking QA verdict, and attaches spec-derived evidence. Keep
  using the interactive one for branches you wrote yourself.
- **Deployment readiness checks** — run those before merge, not before opening a draft.
