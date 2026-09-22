---
description: Turn a PR comment or quoted text into a tracked issue — deduplicates by comment URL, creates the issue with the comment quoted and a link back to the PR, assigns the comment author when resolvable, and posts a confirmation comment on the PR. Use after /sdlc:merge --followup or whenever a review nit should become trackable work.
allowed-tools: Bash, Read, Grep, Glob
---

# /sdlc:followup

`$ARGUMENTS` is `<pr#> [<comment-url> | "<text>"]`. The second argument is optional.

Read `.claude/sdlc.md` for the **Tracker descriptor** and the profile PR label (`ai-sdlc`).
All tracker operations below are bold — execute them exactly as the descriptor defines.

---

## Phase 1: Preflight [HARD STOP]

**First action, before anything else:** **get-pr** `<pr#>`. If the PR does not exist, print
`PR #<n> not found` and stop.

---

## Phase 2: Resolve the input

| Second argument | How to obtain the issue text |
|---|---|
| A URL | **get-pr** `<pr#>` — match the comment by URL in the comments list; use its body |
| Quoted text | Use the text verbatim |
| Absent | Use the PR title and first paragraph of the PR body |

Extract the comment author login when the source is a comment URL. Record it for Phase 5.

---

## Phase 3: Deduplicate [GATE]

**search-issues** with query `is:open "<comment-url>"` (or the first 60 characters of the
text when no URL is present).

If an open issue whose body already contains the comment URL or text excerpt is found:
1. Print `Already tracked as Issue #<m> (<url>) — skipping creation.`
2. **comment-pr** `<pr#>` with body `Filed as Issue: #<m> (existing)`.
3. Stop. Report:
   ```
   Issue: #<m> (<url>)
   PR: #<pr#> (<pr-url>)
   ```

---

## Phase 4: Create the issue [REQUIRED]

Build the issue body from this template:

```markdown
## Follow-up from PR #<pr#>

> <comment body or input text, quoted verbatim>

Source: <comment-url or PR url>

Raised in review of: <PR title> (PR #<pr#>)
```

Derive the title:
- Comment or text input: first sentence truncated to 72 characters, prefixed `Follow-up: `.
- Absent second argument: `Follow-up from PR #<pr#>`.

**create-issue** with:
- `title`: derived above
- `body`: the template
- `labels`: the profile's PR label (`ai-sdlc`)

Capture the returned `number` as `<m>` and `url` as `<issue-url>`.

---

## Phase 5: Assign the author [REQUIRED when resolvable]

If a comment author login was extracted in Phase 2: **assign-issue** `<m>` `<login>`.
If the login is unresolvable (plain text input, no author field): leave unassigned and note
`assignee: unresolved` in the report.

---

## Phase 6: Link back [REQUIRED]

**comment-pr** `<pr#>` with body:

```
Filed as Issue: #<m> (<issue-url>)
```

---

## Phase 7: Report

```
## Followup filed — PR #<pr#>
Issue title: <title>
Assignee: @<login> | unresolved

Issue: #<m> (<issue-url>)
PR: #<pr#> (<pr-url>)
```

---

## Not to be confused with

- **`/sdlc:issue`** — creates an issue from a description or brief, not from a PR comment.
- **`/sdlc:merge --followup`** — passes `"<text>"` straight through to this command as the
  last merge step. The deduplication and body template live here, not in merge.
- **`/sdlc:close-fixed`** — closes issues that a merged PR explicitly fixed. This command
  creates a new tracking issue; it does not close one.
