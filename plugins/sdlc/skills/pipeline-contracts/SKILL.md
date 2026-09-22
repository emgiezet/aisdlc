---
name: pipeline-contracts
description: >
  The shared vocabulary every /sdlc command after ship and before spec speaks — tracker and
  browser descriptors, the operation names, chain markers, verdict tokens, the claim lock, the
  pipeline labels, and the bugfix approval rule. Use when a command needs to talk to the tracker
  or a browser, hand a PR or issue number to the next command, decide whether it may take a
  PR another agent claimed, set or read a pipeline label, or decide whether a bugfix spec counts
  as approved.
---

# Pipeline contracts

Commands never call `gh`, `playwright` or `agent-browser`. They name an operation in bold and the
project's descriptor file says how it runs. Everything below is fixed text: consumers grep it, so
paraphrasing it breaks the chain.

## Descriptors

| Profile key (`.claude/sdlc.md`) | File | Templates |
|---|---|---|
| **Tracker descriptor** | `.claude/trackers/<kind>.md` | `templates/trackers/{github,local,TEMPLATE}.md` |
| **Browser descriptor** | `.claude/browsers/<provider>.md` | `templates/browsers/{playwright,agent-browser,TEMPLATE}.md` |

Resolve: read the profile line, open the file, find `### <operation>`, run its body with the
`{param}` placeholders filled. `none` → skip every step that needs it, say so in one line.
Read back every mutation before reporting it done. `local` is a real provider (files under
`.aisdlc/tracker/`), not a mock.

## Operations

| Group | Operations |
|---|---|
| Identity | **auth-check** **current-user** |
| Issues | **get-issue** **search-issues** **create-issue** **comment-issue** **close-issue** **label-issue** **unlabel-issue** **assign-issue** |
| Pull requests | **get-pr** **list-prs** **search-prs** **create-pr** **update-pr** **comment-pr** **label-pr** **unlabel-pr** **assign-pr** **review-pr** **merge-pr** **get-pr-diff** **get-pr-checks** **get-run-failed-logs** **checkout-pr** **rerun-check** **attach-image-evidence** |
| Labels | **ensure-labels** (only `/sdlc:init` calls it) |
| Lock | **claim** **check-claim** **release** |
| Browser | **boot-check** **open** **goto** **click** **fill** **assert-text** **screenshot** **close** |

Parameters and returns: `templates/trackers/TEMPLATE.md`, `templates/browsers/TEMPLATE.md`.

## Chain markers

The last lines of a report, in this order, exactly:

```
Verdict: <token>
PR: #<n> (<url — or the pr-body.md path under local>)
Issue: #<n> (<url>)
```

`PR:` when the run produced or acted on a PR; `Issue:` when it has a subject issue; both when
both. A consumer takes the number with `grep -oE '^PR: #[0-9]+'`. Outputs passed between chained
commands travel in a block headed `— PREVIOUS STEP (/sdlc:<name>) said —`, verbatim.

## Verdict tokens

| Command | Tokens | Meaning |
|---|---|---|
| `/sdlc:qa`, `/sdlc:ship` | `PASS` `GAPS` | existing QA verdict |
| `/sdlc:implement` | `BLOCKED` | `BLOCKED.md` written |
| `/sdlc:review` | `APPROVED` `CHANGES_REQUESTED` | the submitted review |
| `/sdlc:triage` | `NO_ACTION_NEEDED` `BUG` `FEATURE` | route decision |
| `/sdlc:root-cause` | `LOW_CONFIDENCE` | trailing flag, copied into the PR body by ship |
| `/sdlc:arch-review` | `SOUND` `GAPS` | architecture verdict; `GAPS` = a blocker or unwaived major |
| any autofix loop | `⚠ NEEDS HUMAN` | stop; a person decides |

## Claim lock

Three signals on the issue or PR, all set by **claim** `{kind} {n} {command}`: assignee =
**current-user**, label `in-progress`, comment `🤖 /sdlc:<command> claimed <ISO-8601>`.

| **check-claim** returns | Meaning | Action |
|---|---|---|
| `free` | no `in-progress` | claim, proceed |
| `mine` | lock is current-user's | re-entry: post a take-over comment, proceed, do not re-claim |
| `other:<login>` | live lock, someone else | stop and say so — unless `--force`, which posts an override comment first |
| `stale:<login>` | their claim comment is older than 60 min | claim, note the takeover |

**release** `{kind} {n} {command} {outcome}` removes the label and comments
`🤖 /sdlc:<command> completed: <outcome>. Lock released.` A lock a run opened is released in a
finally step even on failure, with `🤖 /sdlc:<command> aborted: <reason>. Lock released.`. A lock
inherited from the previous chain step is kept and annotated `Lock retained — chain continues.`
Hand-off issue → PR: **claim** the PR, then **release** the issue with outcome `handed off to PR #<n>`.

**review-pr** on a PR the current user authored (GitHub refuses self-review): the descriptor posts
the body as a comment headed `🤖 Review (self-authored PR) — Verdict: <token>` and returns success;
the command sets labels exactly as for a real review.

## Pipeline labels

Exactly one of `review` `changes-requested` `merge-ready` `blocked` on an open PR, always beside
the profile's PR label (`ai-sdlc`), plus `in-progress` while claimed. Transition = **unlabel-pr**
old + **label-pr** new.

| Event | Label |
|---|---|
| `/sdlc:ship` opens the PR | `review` |
| review `CHANGES_REQUESTED` | `changes-requested` |
| review `APPROVED` | `merge-ready` |
| `BLOCKED.md` or `⚠ NEEDS HUMAN` | `blocked` |

`/sdlc:merge` refuses anything not `merge-ready`. No priority, risk, or QA-gate labels exist.

## Bugfix approval

A spec is runnable by `/sdlc:implement` and the queue when `status: approved` **or** all three hold:

```yaml
kind: bugfix
status: approved
approved-by: issue #<n> (label bug, @<author>)
```

and **get-issue** `<n>` shows the label `bug` *now*. A human labelling the issue is the approval;
removing the label revokes it. `/sdlc:triage` writes this frontmatter; nothing else may.
