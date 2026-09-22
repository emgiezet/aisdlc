---
description: Post-merge sweep — closes every issue referenced by Fixes/Closes in merged labelled PRs since the last run, adds a comment on issues whose PR closed without merging, and writes a watermark so re-runs are idempotent. Use after /sdlc:merge or periodically to keep the issue tracker in sync.
allowed-tools: Bash, Read, Grep, Glob
---

# /sdlc:close-fixed

`$ARGUMENTS` is empty. This command mutates issue state only — never PR branches, commits,
or files outside `.aisdlc/close-fixed.json`. Re-running with no new merges changes nothing.

Read `.claude/sdlc.md` for the **Tracker descriptor** and the profile PR label (`ai-sdlc`).
All tracker operations below are bold — execute them as the descriptor defines.

---

## Phase 1: Load watermark

Read `.aisdlc/close-fixed.json`. If the file does not exist, treat it as:

```json
{ "last_run": null, "last_pr": 0 }
```

`last_pr` is the highest PR number fully processed by the previous run.

---

## Phase 2: Collect merged PRs since watermark

**list-prs** `merged` with the profile label. Filter to PRs with number greater than `last_pr`.
Sort ascending by number so processing is deterministic and the watermark advances correctly.

If the filtered list is empty: print `Nothing to process since PR #<last_pr>.` then skip to
Phase 6 to refresh the `last_run` timestamp. Stop after Phase 6.

---

## Phase 3: Parse fix references

For each merged PR in ascending order:

1. Read the PR title and body.
2. Extract every match of the pattern `(?i)(?:Fixes|Closes)\s+#([0-9]+)` from both fields.
3. Collect tuples `(issue_n, pr_n)`.

A PR with no matches is still processed to advance the watermark — skip to the next PR.

---

## Phase 4: Close fixed issues [REQUIRED]

For each `(issue_n, pr_n)` collected above:

1. **get-issue** `issue_n` — read `state`.
2. If `state` is already `closed`: skip (idempotent).
3. **close-issue** `issue_n` with comment:
   ```
   Closed by PR #<pr_n>: <pr-title> (<pr-url>)
   🤖 /sdlc:close-fixed
   ```

---

## Phase 5: Comment on unmerged-closed PRs

**list-prs** `closed` (state closed, not merged) with the profile label. Filter to PRs with
number greater than `last_pr`.

For each such PR, parse `Fixes|Closes #n` from the title and body. For each referenced issue:

1. **get-issue** `issue_n` — if `state` is `closed`, skip.
2. **comment-issue** `issue_n`:
   ```
   PR #<pr_n> was closed without merging. This issue may still be open.
   🤖 /sdlc:close-fixed
   ```

---

## Phase 6: Write watermark [REQUIRED]

After all mutations in Phases 4 and 5 complete, write `.aisdlc/close-fixed.json`:

```json
{ "last_run": "<ISO-8601-now>", "last_pr": <highest-pr-number-seen> }
```

Write the watermark **last**. An interrupted run will re-process on the next call. The
idempotent check in Phase 4 (skip already-closed issues) prevents double-closing.

---

## Phase 7: Report

```
## close-fixed complete
Merged PRs scanned: <n>  (PR #<low>–#<high>)
Issues closed: <n>
Unmerged-close comments posted: <n>
Watermark: PR #<last_pr> · <ISO-8601>
```

---

## Not to be confused with

- **`/sdlc:merge`** — merges one PR interactively. This command sweeps after merges have
  already happened; run it afterward, not instead.
- **`/sdlc:followup`** — creates a new tracking issue from a comment. This command closes
  issues that a merged PR explicitly fixed — it does not create issues.
- **Closing issues by hand** — this command acts only on issues explicitly named in a merged
  PR body or title with `Fixes #n` or `Closes #n`. It does not infer fixes from the code.
