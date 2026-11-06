---
description: Claim a PR, run the code-reviewer agent in an isolated worktree, submit the verdict through the tracker descriptor, label the PR, and optionally autofix eligible blockers. Use after /sdlc:ship, from the queue review phase, or to sweep a single PR.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, SlashCommand
---

# /sdlc:review

`$ARGUMENTS`: `<pr#> [--autofix] [--adversarial] [--force]`. Read `.claude/sdlc.md` for the Tracker descriptor,
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

Set **adversarial mode** if `--adversarial` is present, OR the profile (`.claude/sdlc.md`) contains
``- **review-adversarial:** `true` ``. Absent or false: one pass only.
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

1. **get-pr** `mergeable` field → `CONFLICTING`: add `[blocker] merge conflicts`.
2. **get-pr-checks** `{n}` → each failing required check: `[major] CI check <name> failing`.

---

## Phase 4: Isolated worktree [REQUIRED]

Inside a linked worktree at this PR's head → reuse it. Otherwise
`git fetch origin pull/{n}/head:review-pr-{n} && git worktree add /tmp/review-pr-{n} review-pr-{n}`;
fork or fetch failure → **checkout-pr** `{n}`. Phase 8 removes it.

---

## Phase 4b: Ledger [REQUIRED]

`$W` is the worktree, `$J` `/tmp/review-pr-{n}-ledger.json`, `$L` `${CLAUDE_PLUGIN_ROOT}/bin/aisdlc-ledger`
(unset → the installed plugin's `bin/`). A `$L` call that prints a ledger is saved over `$J`
(`> $J.tmp && mv $J.tmp $J`). Never compute an id, anchor, scope or verdict yourself — `$L` does
(vocabulary: `pipeline-contracts` → `## Findings ledger`).

1. **get-pr-ledger** `{n}` → `jq -r .body` into `/tmp/review-pr-{n}-ledger.md`; `$L read --comment`
   it into `$J`. Empty output or exit 1 → `ledger: none`, `$L init --pr {n}` into `$J`.
2. `$L anchor --repo $W --ledger $J` — a moved line is followed; a finding whose line is gone resolves.
3. `$L changed-lines --repo $W --base origin/{base} > /tmp/review-pr-{n}-changed.txt`.
4. **Scope:** `review.head` set in `$J` and `git -C $W merge-base --is-ancestor <review.head> HEAD`
   exits 0 → `incremental since <review.head>`, lines from `$L changed-lines --repo $W --base origin/{base} --since <review.head>`; else `full`.

---

## Phase 5: Review [REQUIRED]

**Determine the kind:** inspect the diff (**get-pr-diff** `{n}`). If every changed file is under
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

When the scope is incremental, append exactly:

```
Scope: incremental since <sha>
Lines: <path:line, one per line — report only findings citing these>
Open findings (re-report each that still holds; one you omit resolves if its file changed since <sha>): <id> <severity> <path:line> <title>
A security finding may cite any line of the PR diff, in scope or not.
```

The agent reads the profile, spec, `Out:`, diff and tests, and runs the verification matrix.
Collect its ranked findings list and `Verdict:` line. Then add the imports — the slop-guard report
and `specs/<TICKET>/scope-report.md`, when present — exactly as `code-review` →
`## Imported findings` titles them.

**Adversarial pass** — adversarial mode on a **code review** (not spec-only): dispatch a second
`code-reviewer` with exactly this block (plus the incremental lines above, when they apply), first
line verbatim, without pass 1's findings or verdict:

```
Adversarial: true
Ticket: <same as pass 1>
PR: #{n}
Phase-3 signals: <same as pass 1>
Diff: <get-pr-diff output>
```

The agent follows its `## Adversarial mode` and returns an independent findings list and `Verdict:`; a finding pass 1 lacks at that `file:line` carries `(adversarial)` in its title.

**Record** — findings citing a `file:line` (both passes; checklist, or spec lenses on
`specs/<TICKET>/spec.md`) → `/tmp/review-pr-{n}-findings.jsonl`, one `{"severity","title","path","line"}`
per line; `$L add --ledger $J --repo $W --head "$(git -C $W rev-parse HEAD)" --changed
/tmp/review-pr-{n}-changed.txt` (plus `--since <review.head>` when incremental) `< …findings.jsonl`.
Same severity on the same line keeps one id, so both passes merge; keep its `dropped: <n>` stderr line
for Phase 9. Then Phase 3 signals and imports as `{"severity","title"}` lines, `$L add` without `--changed`.

---

## Phase 6: Verdict + labels [REQUIRED]

1. **get-pr** `{n}` body → `/tmp/review-pr-{n}-prbody.md`; `$L disposition --ledger $J --body` it
   (applies `Waived: F<id> …` / `Rejected: F<id> …`); then `$L seal --ledger $J --head <HEAD sha>`.
2. The verdict is what `$L verdict --ledger $J` prints. The agent's `Verdict:` is a cross-check: on
   disagreement the derived verdict wins and Phase 9 says so.
3. `$L render --ledger $J > /tmp/review-pr-{n}-ledger.md`; **put-pr-ledger** `{n}` with that file.
4. `/tmp/review-pr-{n}-body.md`: the `open` findings ranked, each prefixed `F<id>`, then the verdict
   line. **review-pr** `{n} {approve|request-changes} /tmp/review-pr-{n}-body.md`.

C5 label transition (unlabel every other pipeline label, then label the new state):
- `APPROVED` → **unlabel-pr** `review`; **unlabel-pr** `changes-requested`; **unlabel-pr** `blocked`; **label-pr** `merge-ready`
- `CHANGES_REQUESTED` → **unlabel-pr** `review`; **unlabel-pr** `merge-ready`; **unlabel-pr** `blocked`; **label-pr** `changes-requested`

---

## Phase 7: Autofix [only when author == current-user or --autofix]

If PR author ≠ **current-user** and `--autofix` is absent: record `autofix: skipped (not my PR)`
and go to Phase 8. If verdict is `APPROVED`: skip autofix.

Fix in this order; push each category as a separate commit (never `--force`; never bypass `guard`):

1. **Conflicts** — merge or rebase onto the base branch; resolve.
2. **Findings** — for **code review** (`specs/<TICKET>/spec.md` is read-only at all times):

   | Finding class | Autofix action |
   |---|---|
   | `[major] scope gap: <file>` — change is extraneous | remove its changes from the diff: restore the base version of an existing file; delete only a branch-added file; re-review |
   | `[major] scope gap: <file>` — change is required by the deliverable | emit `⚠ NEEDS HUMAN: scope gap: <file> — widen the spec or waive`; stop |
   | `[major] over change budget: <details>` | emit `⚠ NEEDS HUMAN: over change budget: <details> — widen the spec or waive`; stop |
   | `[blocker] over change budget: <details>` (including hard-ceiling breaches) | emit `⚠ NEEDS HUMAN: over change budget: <details> — widen the spec or waive`; stop |
   | all other `blocker` / `major` findings | fix in code as before |

   For **spec-only review**: autofix edits the spec directly; no `⚠ NEEDS HUMAN` for scope findings (behaviour unchanged from pre-fix).
3. **CI** — after findings are pushed, **get-pr-checks** `{n}`; for each failing check classify
   `real-bug | test-bug | flake | infra`:
   - `flake`: **get-run-failed-logs** `{run-id}`; **rerun-check** `{run-id}`; if it fails again → treat as `real-bug`.
   - `infra`: record `⚠ NEEDS HUMAN: infra failure in <check>`; **unlabel-pr** `review`; **unlabel-pr** `merge-ready`; **unlabel-pr** `changes-requested`; **label-pr** `blocked`; stop.
   - Never skip, comment-out, or lower a threshold.

After each push, re-enter Phase 4b, then Phase 5 and 6: loops 2 and 3 are incremental, and a fixed
finding resolves through `$L anchor` or `$L add --since`, never by your say. With adversarial mode,
the re-review repeats both passes. On `APPROVED`: proceed to Phase 8. Maximum 3 re-review loops;
after 3 without `APPROVED`: stop; do not push further.

Stop immediately on `⚠ NEEDS HUMAN`: **unlabel-pr** `review`; **unlabel-pr** `merge-ready`; **unlabel-pr** `changes-requested`; **label-pr** `blocked`; do not loop further.

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
Ledger: F1..F<n> · open <n> · resolved <n> · accepted <n> · rejected <n>
Scope: full | incremental since <sha8> (<n> files, <n> lines)
Dropped: <n> finding(s) citing lines this PR did not change
Findings: <n> blocker · <n> major · <n> minor · <n> nit
<Autofix: <n>/3 loops, committed as <sha> | autofix: skipped (not my PR) | autofix: not needed>
<only on disagreement: Agent verdict <token> overridden by the ledger>

Verdict: APPROVED | CHANGES_REQUESTED
PR: #<n> (<url>)
```

`Findings:` counts `open` ledger findings. When the second pass ran (never for spec-only PRs), add
`Pass 1: …` and `Pass 2 (adversarial): …` lines in the same shape above it. The last two lines are
C4 chain markers. Print them exactly, last, once.

---

## Not to be confused with

- **`/sdlc:fix-pr`** — wraps this command with a CI stabilisation loop; use it when checks are red.
- **`/sdlc:qa`** — verifies the code matches the spec; neither substitutes for the other.
- **`/sdlc:merge`** — reads the `merge-ready` label this command sets.
