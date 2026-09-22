---
description: Review every open PR carrying the profile label that has no review from current-user — newest first, skipping live claims by others. Use to sweep the review inbox without choosing a PR number.
allowed-tools: Bash, Read, Grep, Glob, SlashCommand
---

# /sdlc:review-prs

No arguments. Read `.claude/sdlc.md` for the Tracker descriptor and the profile label.

Every tracker action is a bold operation (**list-prs**). Execute it exactly as the descriptor defines.

---

## Phase 1: Collect candidates [HARD STOPS]

**First action:** **list-prs** `open {profile-label}`. If zero PRs are returned, print
`no open PRs with label {profile-label}` and stop.

**current-user** to get your login.

Filter out PRs whose `reviews` list already contains a review by **current-user**.

Sort the remaining PRs newest first (highest PR number first).

---

## Phase 2: Skip claimed PRs

For each candidate, **check-claim** `pr {n}`:

| Result | Action |
|--------|--------|
| `other:<login>` | skip; record `PR #{n} — claimed by <login>` |
| `free` / `mine` / `stale:<login>` | proceed to Phase 3 |

---

## Phase 3: Review each PR

For each remaining PR in newest-first order, invoke `/sdlc:review {n}` via the `SlashCommand`
tool. If unavailable, read `${CLAUDE_PLUGIN_ROOT}/commands/review.md` and follow it verbatim.

Pass each review's output to the next step in a block:
```
— PREVIOUS STEP (/sdlc:review {n}) said —
<output>
```

Collect the `Verdict:` line from each review.

---

## Phase 4: Report

```
## review-prs
Reviewed: <n> PRs

<PR #{n}>: Verdict: APPROVED | CHANGES_REQUESTED
…

Skipped (claimed): PR #{n} — claimed by <login>, …
Skipped (already reviewed): PR #{n}, …

PR: #<last-reviewed-n> (<url>)
```

Print one `PR: #<n>` line for the last PR reviewed (C4 chain marker). If no PR was reviewed,
omit the `PR:` line.

---

## Not to be confused with

- **`/sdlc:review`** — reviews one PR by number. This command calls it for each candidate.
- **`/sdlc:fix-pr`** — fixes a known-broken PR. After `review-prs` flags `CHANGES_REQUESTED`,
  use `fix-pr` or `autopilot` to repair it.
