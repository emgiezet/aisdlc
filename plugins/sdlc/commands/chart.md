---
description: Chart an effort too large for one session as a decision map — a destination, one tracker ticket per open decision, and the fog ahead of them — then resolve one ticket per session until nothing is left to decide. Use when the goal is nameable but the route is not; it plans and never builds, and hands a cleared map to /sdlc:spec.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, SlashCommand, Agent
---

# /sdlc:chart

Some efforts are too big to think through in one sitting and too unclear to spec. This command
keeps their route on a **decision map** — destination, one ticket per open decision, fog — and
resolves one ticket per session. Nothing is built here: building starts after `/sdlc:spec`.

`$ARGUMENTS` is a destination sentence, a map path or id, or empty.

Read `.claude/sdlc.md` for `Briefs live in:` (default `specs/briefs/`), `Specs live in:` (default
`specs/`), **Kind** and the **Tracker descriptor**. Every tracker action is a bold operation
(**create-issue**); execute it exactly as the descriptor defines, never substitute a CLI call.

**Load the `discovery` skill** — it holds the map format (`## Decision maps`), the four ticket
types, the HITL resolution rule and the question discipline. Follow its question discipline in
every message that asks the human something. **Load the `pipeline-contracts` skill** for the
decision-map labels, the resolution comment and the claim lock.

---

## Phase 0: Resolve the map and enter planning mode [GATE]

Find the map:

| `$ARGUMENTS` | Action |
|---|---|
| matches `<briefs dir>/map-*.md` by path, by slug, or by its frontmatter `map:` issue number | resume it: `status: charting` → Phase 2 (the human's reply confirmed or edited the destination); `status: open` → Phase 4; `cleared` or `abandoned` → print the status and stop |
| empty, exactly one map with `status: open` | resume it at Phase 4 |
| empty, no open map | print `usage: /sdlc:chart <destination sentence | map slug>` and stop |
| empty, several open maps | list them (slug, destination, open-ticket count) and stop |
| anything else | the destination of a new map → Phase 1 |

Then enter planning mode — write `.aisdlc/planning-mode` at the repository root, exactly three lines:

```bash
mkdir -p .aisdlc && printf 'map: %s\nsince: %s\nallow: %s\n' \
  "<briefs dir>/map-<slug>.md" "$(date -u +%FT%TZ)" "<allow list>" > .aisdlc/planning-mode
```

The allow list is the profile's specs dir, briefs dir and `.aisdlc/`, each with a trailing `/`,
space-separated, duplicates dropped (a briefs dir inside the specs dir is covered by it). From here
`guard pre-write` denies any write outside that list. That is the point: a map session plans and
does not build. Never edit or delete the marker to get a write through; if a write is denied, the
work belongs to another session.

Tracker mode, by **Kind**: `github` or `local` → tracker-backed tickets. `jira-mcp` or `none` →
file-only: `map: none` in the frontmatter, the `## Open tickets` table is the only ticket record,
and every bold operation below that the descriptor lacks is skipped with one line saying so.

---

## Phase 1: Destination [HARD STOP]

Ask one question per message until the destination is observable: what someone can see or check
when the map is finished, and what is beyond it. Then write `<briefs dir>/map-<slug>.md` from the
skill's `references/map-template.md` with `status: charting`, filling `## Destination` and
`## Out of scope` and nothing else. Print both sections and stop.

The human confirms or edits the destination before any ticket exists. Never propose a destination
and chart tickets in the same message. Their reply resumes this command at Phase 2.

---

## Phase 2: Fog sweep [REQUIRED]

Breadth-first, list every decision still open between here and the destination. Classify each:

- **ticket** — the question can be stated precisely now, as one sentence ending in `?`
- **fog** — you can see it coming but cannot phrase it yet; it goes to `## Not yet specified`

Anything beyond the destination goes to `## Out of scope`, never to fog.

No fog and at most two ticket candidates → the effort fits one session and a map costs more than
it returns: `rm .aisdlc/planning-mode`, set `status: abandoned`, verdict `NOT NEEDED`, Phase 6.

---

## Phase 3: Chart [GATE]

Caps: at most 7 tickets and 10 fog bullets. Over either → the destination is too wide: say which
part to cut, return to Phase 1. If the human refuses to narrow, chart the first 7 and leave the rest
as fog — never raise the cap.

Each ticket gets an id `D-<n>` (next unused; ids are never renumbered), its one-sentence question,
a type from the skill's table (`grilling` unless another type's "reach for it when" fits better),
and the ids that block it. A ticket that reads "build the X" is not a decision — rephrase it as the
question it hides, or drop it.

Tracker-backed, in this order:

1. **create-issue** the map: title `Map: <destination>`, label `map`, body linking the map file.
2. Per ticket, **create-issue**: title `D-<n>: <question>`, labels `decision` and
   `decision:<type>`, body (write it to a `mktemp` file):
   ```
   <question>

   Map: #<map>
   Type: <type>
   Mode: HITL | AFK
   ```
   Then **add-sub-issue** `<map> <ticket>`.
3. Per blocking edge, **link-blocks** `<blocker> <blocked>`.
4. **get-issue** one ticket and check its labels. A `decision:<type>` label came back absent →
   print `run /sdlc:update to create the decision-map labels` and carry on; the table records the type.

Write the map file: `map: #<map>` (or `none`), `status: open`, the `## Open tickets` table (claim
`—` everywhere), the fog. Print the `## Open tickets` table.

`research` tickets are the one exception to "nothing is resolved while charting": they are AFK and
ask the human nothing, so dispatch them now, in parallel, exactly as Phase 4 describes. Every other
ticket waits for its own session. Verdict `CHARTED`, Phase 6.

---

## Phase 4: Resolve exactly one ticket [REQUIRED]

**Pick.** Tracker-backed: **list-frontier** `decision`, keep only rows whose ticket is on this map's
`## Open tickets` table, then drop every row whose **list-blockers** is non-empty. Rows whose claim
column is the current user are candidates too (an unfinished ticket from an earlier session).
File-only: rows whose `blocked by` ids all appear in `## Decisions so far` and whose claim is `—`.
Empty frontier with open tickets left → every one is blocked or claimed: verdict `BLOCKED`, naming
the blocking ids. Several candidates → show them and let the human pick; no reply → lowest id.

**Claim.** Tracker-backed, **check-claim** `issue <n>`:

| Result | `--force`? | Action |
|--------|-----------|--------|
| `free` | — | **claim** `issue <n> chart`; proceed |
| `mine` | — | post take-over comment; proceed; do not re-claim |
| `stale:<login>` | — | **claim** `issue <n> chart`; note the takeover in a comment |
| `other:<login>` | no | stop: `D-<n> (#<n>) claimed by <login>` |
| `other:<login>` | yes | **comment-issue** override notice; **claim** `issue <n> chart`; proceed |

Write the login into the ticket's claim column. File-only: write `git config user.name` there.

**Work it, by type:**

- `grilling` → invoke `/sdlc:brainstorm "<question>"` via `SlashCommand`. If unavailable, read
  `${CLAUDE_PLUGIN_ROOT}/commands/brainstorm.md` and follow it verbatim. Pass its output forward in
  a block headed `— PREVIOUS STEP (/sdlc:brainstorm) said —`. Its brief is the artefact.
- `prototype` → build one self-contained file at
  `<specs dir>/<map-slug>/prototype-D-<n>/index.html`, following
  `${CLAUDE_PLUGIN_ROOT}/commands/mockup.md` Phase 2 verbatim, with two or three variants that
  differ on exactly the open question. Present them and let the human choose; choosing for them
  does not resolve the ticket.
- `research` → dispatch an `Agent` that reads outside the repository and writes
  `<briefs dir>/research/<map-slug>-D-<n>.md`: the question, then findings, every factual
  sentence tagged `[SOURCE: <url>]`, then one line `Answer: <one sentence> | UNKNOWN`. `UNKNOWN`
  leaves the ticket open and graduates the missing fact into a `grilling` ticket.
- `task` → do it when the agent can, inside the allow list. Otherwise **comment-issue** a numbered
  checklist for the human, leave the ticket open, and report `BLOCKED` with the checklist.

**Resolve.** Apply the skill's HITL rule first: a `grilling` or `prototype` ticket with no human
reply in this session stays open, **release** `issue <n> chart no human answer`, verdict `BLOCKED`.
Otherwise, in one pass:

1. **comment-issue** the resolution comment from `pipeline-contracts`, exactly.
2. **release** `issue <n> chart resolved D-<n>`, then **close-issue** `<n>`.
3. Map file: one line in `## Decisions so far`
   (`- D-<n>: <decision> — #<n> <evidence tag>`), remove the row from `## Open tickets`.
4. Fog this decision made statable → new tickets, charted as in Phase 3 (ids continue, caps apply),
   and removed from `## Not yet specified` in the same edit.
5. A decision that contradicts an earlier one: reopen nothing silently — follow the revision rule in
   `pipeline-contracts` (`Superseded by D-<m>`).

Then stop: one ticket per session, even when the next one looks quick. Verdict `RESOLVED`, unless
Phase 5 applies.

---

## Phase 5: Clear the map

`## Open tickets` empty and `## Not yet specified` empty → nothing is left to decide. Set
`status: cleared`, **close-issue** the map issue with comment `Map cleared — hand to /sdlc:spec`,
`rm .aisdlc/planning-mode`. Verdict `CLEARED`.

Planning mode otherwise stays on between sessions; `guard` ignores a marker older than 12 hours,
and every `/sdlc:chart` run rewrites `since:`.

---

## Phase 6: Report

```
## Decision map — <slug>
Verdict: CHARTED | RESOLVED | CLEARED | NOT NEEDED | BLOCKED
Destination: <one line>
Decided: <n> · Open: <n> · Fog: <n>
Resolved this session: D-<n> — <decision>        (RESOLVED only)
Map: <briefs dir>/map-<slug>.md

## Next
<CHARTED>   → /sdlc:chart <slug> resolves the first ticket; one per session
<RESOLVED>  → /sdlc:chart <slug> for the next; the frontier is <ids>
<CLEARED>   → /sdlc:spec <TICKET> seeded with <briefs dir>/map-<slug>.md
<NOT NEEDED>→ /sdlc:brainstorm "<destination>"
<BLOCKED>   → <the exact thing a human must decide or do>

Verdict: <token>
Issue: #<map-n> (<url>)
```

Print only the `## Next` line for this run's verdict. Omit `Issue:` when the map is file-only.

---

## Not to be confused with

- **`/sdlc:brainstorm`** — one session, one idea. This command schedules it per `grilling` ticket,
  and is the wrong tool when the whole effort fits in one sitting.
- **`/sdlc:decompose`** — slices an approved-sized intention into shippable code slices. It runs
  after the spec; this runs before it.
- **`/sdlc:backlog`** — files an epic → story → task tree of work to build, not questions to settle.
- **`/sdlc:verify-map`** — a verification map of the running application; an unrelated namesake.
