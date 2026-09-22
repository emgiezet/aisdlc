---
description: Turn a verified branch into a reviewable draft PR without a human in the loop — pushes, opens the PR with the spec and QA verdict up front, labels it for the review inbox, posts the QA report as a comment, and hands the pipeline label to /sdlc:review. Use as the last step after /sdlc:qa, from the aisdlc queue, or with --docs for a documentation-only branch.
allowed-tools: Bash, Read, Grep, Glob
---

# /sdlc:ship

The delivery end of the unattended pipeline. Its job is to make a human's next two minutes
efficient: the PR must say what was asked, what the QA verdict is, and where to look first.

`$ARGUMENTS` is the ticket id, optionally followed by `--no-qa` or `--docs`. Read `.claude/sdlc.md`
for the specs directory, the pull request label, the pipeline labels, the branch convention and
the **Tracker descriptor**; paths below assume the defaults `specs/` and `ai-sdlc`.

Every tracker action below is a bold operation name (**create-pr**). Execute it exactly as the
descriptor file defines it; never substitute a CLI call of your own. `Tracker descriptor: none` →
there is no delivery channel: write `specs/<TICKET>/pr-body.md`, report the branch, stop.

Requires `specs/<TICKET>/spec.md` and, unless `--no-qa` or `--docs` is passed,
`specs/<TICKET>/qa-report.md`.

---

## Phase 1: Preflight [HARD STOPS]

**First action, before anything else:** check that `specs/<TICKET>/spec.md` exists. If it does
not, print `no spec at specs/<TICKET>/spec.md — nothing to ship` and stop. Do not search the
repo, do not look for the ticket in a tracker, do not ask where it went. A missing file is an
answer, and finding that out must cost one tool call.

**`--docs` replaces that check** with a diff check: every path in `git diff --name-only <base>..HEAD`
must match `*.md`, `docs/**` or `CHANGELOG*`. Any other path → print
`--docs: non-doc files in diff: <list>` and stop. `<TICKET>` may then be a slug (`changelog-1.2.0`)
and no spec or QA report is required.

Then refuse, with a one-line reason, if:

- `specs/<TICKET>/qa-report.md` is missing → "run /sdlc:qa first"
- the QA verdict is `GAPS` and it has a blocking finding → "QA blocking; fix before shipping"
- `specs/<TICKET>/BLOCKED.md` exists → "implementation stopped blocked"
- the working tree is dirty → commit or explain; never `git add -A` blind at this stage
- the current branch is `main`, `master`, or `develop` → "refusing to ship from a shared branch"
- `git log <base>..HEAD` is empty → "nothing to ship"

Run the descriptor's **auth-check**. A failure is not a stop: fall through to Phase 4.

---

## Phase 2: Open the PR

1. Push: `git push -u origin HEAD` (skip when there is no `origin`; the `local` provider does not
   need one).
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
<for UI work: the mockup path and the e2e scenario names>

### Review here first
<the 1–3 riskiest changes, with file:line — money maths, permission checks, migrations>
<if the spec's Context carries LOW_CONFIDENCE: "Root-cause analysis was LOW_CONFIDENCE — verify the diagnosis, not just the fix">

### Not covered
<anything from the QA report's "Not verified" section, or "nothing">
```

   A `--docs` body is shorter: title, what changed and why, the `git log --oneline <base>..HEAD`.

3. **create-pr** with title `type(scope): <summary> (<TICKET>)`, the body file, the profile's
   default base, and `draft` set. Always a draft: an agent-authored PR entering review unread is how
   the review habit dies. Keep the returned number and URL.
4. **label-pr** twice: the profile's PR label (`ai-sdlc`) and the pipeline label `review`. The first
   is what makes `aisdlc inbox` and a phone-sized PR list work; the second is what `/sdlc:review`
   and `/sdlc:merge` read. Both labels were created by `/sdlc:init`; a missing one is logged by the
   descriptor and never created here.
5. **comment-pr** with `specs/<TICKET>/qa-report.md` as the body file (skip under `--docs`). In the
   comment, not the body — the body stays scannable, the evidence stays one click away.
6. If `specs/<TICKET>/qa/*.png` exist: **attach-image-evidence** with them, slug `pr-<n>`.
7. If a migration is in the diff, say so in the body and request review attention explicitly.

Under the `local` provider these operations write `.aisdlc/tracker/prs.jsonl`, the PR body to
`specs/<TICKET>/pr-body.md` and comments beside it — the same steps, a different medium. Commit
`pr-body.md`; it is the reviewable artefact when there is no remote.

---

## Phase 3: Report

```
## Shipped — <TICKET>
Labels: ai-sdlc · review (draft)
QA: PASS · UC 8/8 · tests 448
Review first: <file:line>

Verdict: PASS
PR: #<n> (<url — or the pr-body.md path under local>)
```

The last two lines are the chain markers: the queue's `review` phase and `/sdlc:review` parse the
number from `PR: #<n>`. Print them exactly, last, once.

---

## Phase 4: No delivery channel

**auth-check** failed, the descriptor is `none`, or the push was refused: write
`specs/<TICKET>/pr-body.md` with the Phase 2 body, leave the branch pushed if a remote accepted it,
and report the branch name plus that path with `Verdict:` and `PR: #0 (specs/<TICKET>/pr-body.md)`.
The work must never be lost because the delivery channel was missing.

---

## Not to be confused with

- **A human-facing PR generator** — one that interviews the diff while you watch. This command is
  non-interactive, refuses on a blocking QA verdict, and attaches spec-derived evidence. Keep
  using the interactive one for branches you wrote yourself.
- **`/sdlc:review`** — reads the PR this command opened. Ship never reviews its own work.
- **Deployment readiness checks** — run those before merge, not before opening a draft.
