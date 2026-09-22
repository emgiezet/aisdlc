---
description: Claim a PR, run the code-reviewer agent in an isolated worktree, submit the verdict through the tracker descriptor, label the PR, and optionally autofix eligible blockers. Use after /sdlc:ship, from the queue review phase, or to sweep a single PR.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, SlashCommand
---

# /sdlc:review

`$ARGUMENTS`: `<pr#> [--autofix] [--force]`. Read `.claude/sdlc.md` for the Tracker descriptor,
profile label, and spec directory.

Every tracker action is a bold operation (**get-pr**). Execute it exactly as the descriptor
defines; never substitute a CLI call.

---

## Phase 1: Preflight [HARD STOPS]

**First action, before anything else:** **get-pr** `{n}`. If the PR does not exist, print
`no PR #<n> found` and stop. A missing PR is an answer; finding that out must cost one tool call.

Stop with a one-line reason if:
- PR `state` is `closed` or `merged`
- Profile label (`ai-sdlc`) is absent from the PR

**auth-check**: failure is not a stop; record it as a Phase 3 signal.

---

## Phase 2: Claim [GATE]

**check-claim** `pr {n}`:

| Result | `--force`? | Action |
|--------|-----------|--------|
| `free` | — | **claim** `pr {n} review`; proceed |
| `mine` | — | post take-over comment; proceed; do not re-claim |
| `stale:<login>` | — | **claim** `pr {n} review`; note the takeover in a comment |
| `other:<login>` | no | stop: `PR #{n} claimed by <login>` |
| `other:<login>` | yes | **comment-pr** override notice; **claim** `pr {n} review`; proceed |

---

## Phase 3: Signals [REQUIRED]

Record as findings inside the review — never a reason to stop the run:

1. **get-pr** `mergeable` field → `CONFLICTED`: add `[blocker] merge conflicts`.
2. **get-pr-checks** `{n}` → each failing required check: `[major] CI check <name> failing`.

---

## Phase 4: Isolated worktree [REQUIRED]

If already inside a linked worktree at this PR's head: reuse it; skip setup.

Otherwise:
```bash
git fetch origin pull/{n}/head:review-pr-{n}
git worktree add /tmp/review-pr-{n} review-pr-{n}
```

Fallback (fork or fetch failure): **checkout-pr** `{n}`.

Remove in Phase 8 (finally): `git worktree remove --force /tmp/review-pr-{n}`.

---

## Phase 5: Review [REQUIRED]

**Determine scope:** inspect the diff (**get-pr-diff** `{n}`). If every changed file is under
`specs/`:

**Spec-only review** — apply the five lenses from `skills/code-review/SKILL.md`
(Risks, Compatibility, Gaps, Improvements, Simplicity). Autofix in Phase 7 edits only the spec.
No code checklist.

Otherwise, **code review** — dispatch the `code-reviewer` agent:

```
Ticket: <id from PR title or body, or "unknown">
PR: #{n}
Phase-3 signals: <list from Phase 3>
Diff: <get-pr-diff output>
```

The agent reads the profile, spec, `Out:`, diff, tests, and runs the verification matrix.
Collect its ranked findings list and `Verdict:` line.

After the agent returns: check `.aisdlc/slop-guard/report.json` (or the path in `.claude/sdlc.md`).
Import any blocker items as additional `[blocker]` findings.

---

## Phase 6: Verdict + labels [REQUIRED]

Write `/tmp/review-pr-{n}-body.md`: ranked findings, then the verdict line.

**review-pr** `{n} {approve|request-changes} /tmp/review-pr-{n}-body.md`.

C5 label transition:
- `APPROVED` → **unlabel-pr** `changes-requested`; **label-pr** `merge-ready`
- `CHANGES_REQUESTED` → **unlabel-pr** `merge-ready`; **label-pr** `changes-requested`

---

## Phase 7: Autofix [only when author == current-user or --autofix]

If PR author ≠ **current-user** and `--autofix` is absent: record
`autofix: skipped (not my PR)` and go to Phase 8.

If verdict is `APPROVED`: skip autofix.

Fix in this order; push each category as a separate commit (never `--force`; never bypass `guard`):

1. **Conflicts** — merge or rebase onto the base branch; resolve.
2. **Findings** — address every `blocker` and `major` from Phase 5.
3. **CI** — after findings are pushed, **get-pr-checks** `{n}`; for each failing check classify
   `real-bug | test-bug | flake | infra`:
   - `flake`: **get-run-failed-logs** `{run-id}`; re-run once via the descriptor; if it fails again → treat as `real-bug`.
   - `infra`: record `⚠ NEEDS HUMAN: infra failure in <check>`; label `blocked`; stop.
   - Never skip, comment-out, or lower a threshold.

After each push, re-dispatch Phase 5 (`code-reviewer`). On `APPROVED`: proceed to Phase 8.

Stop immediately on `⚠ NEEDS HUMAN`: label `blocked`; do not loop further.

Maximum 3 re-review loops. After 3 loops without `APPROVED`: stop; do not push further.

---

## Phase 8: Release [REQUIRED — runs even on failure]

**release** `pr {n} review <outcome>`:
- `APPROVED` → `approved`
- `CHANGES_REQUESTED`, autofix exhausted → `changes-requested; autofix exhausted`
- `⚠ NEEDS HUMAN` → `blocked; needs human`
- Aborted → `aborted: <reason>`

Remove the worktree: `git worktree remove --force /tmp/review-pr-{n}`.

---

## Phase 9: Report

```
## Review — PR #{n}
Findings: <n> blocker · <n> major · <n> minor · <n> nit
<Autofix: <n>/3 loops, committed as <sha> | autofix: skipped (not my PR) | autofix: not needed>

Verdict: APPROVED | CHANGES_REQUESTED
PR: #<n> (<url>)
```

The last two lines are C4 chain markers. Print them exactly, last, once.

---

## Not to be confused with

- **`/sdlc:fix-pr`** — wraps this command and adds a CI stabilisation loop. Use `fix-pr`
  when the PR is known to have red checks.
- **`/sdlc:qa`** — verifies the code matches the spec. Both belong on agent-written PRs;
  neither substitutes for the other.
- **`/sdlc:merge`** — reads the `merge-ready` label this command sets.
