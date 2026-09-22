---
description: Decompose a brief or spec into an evidence-gated epic → story → task tree and file each node through /sdlc:issue — dry-run prints, adoption matches existing issues by title. Use after a brief is evidence-ready to build the tracker backlog.
allowed-tools: Read, Write, Agent, SlashCommand
---

# /sdlc:backlog

`$ARGUMENTS`: `<brief|spec>` (path) `[--dry-run]` `[--research]`

**First action:** check the file exists. Missing → print
`no brief at <path> — pass a brief or spec path` and stop.

**Load the `discovery` skill** — it holds the readiness gate and evidence-tag rules.

Read `.claude/sdlc.md` for tracker settings and `Briefs live in:`.

---

## Phase 1: Readiness check [HARD STOP]

Read the Problem section. If **any sentence** in Problem is tagged `[ASSUMPTION]`:

```
brief rests on assumptions: Problem
Run /sdlc:discover --mode <mode> to gather evidence first.
Pass --research to file only collection-plan items from the brief.
```

`--research` bypasses this stop and limits Phase 3 to collection-plan items only — no epics,
no stories, no tasks outside those items. Each item becomes one issue filed via `/sdlc:issue`.

---

## Phase 2: Tree [GATE]

Decompose the brief into a tree. Print it before filing anything:

```
Epic: <title>
  Story: <title> [AC: <one-sentence acceptance criterion>]
    Task: <title>
    Task: <title>
  Story: <title> [AC: …]
```

Rules:
- One epic per distinct outcome in the brief's Scope (now) section
- One story per independently verifiable slice of the epic
- Tasks are implementation steps within a story
- Every story has one observable acceptance criterion

Stop and print:

```
⏸ BACKLOG REVIEW
Reply 'yes' to file these as issues, or describe what to change.
```

If `--dry-run`, print the tree and stop. Do not ask; do not file anything.

---

## Phase 3: File via /sdlc:issue [REQUIRED]

For each node, top-down:

1. **Adopt existing:** use **search-issues** `{title}` to find a matching open issue. If
   found, note `adopted #<n>` and use that number. Do not duplicate.
2. **File new:** invoke `/sdlc:issue` via `SlashCommand` with title, body, and labels.
   If `SlashCommand` is unavailable, read `${CLAUDE_PLUGIN_ROOT}/commands/issue.md` and
   follow it verbatim. Pass outputs in a block headed
   `— PREVIOUS STEP (/sdlc:issue) said —`.

**Epic body** includes a Markdown checklist of its stories:
```markdown
- [ ] Story: <title> (Issue #<n>)
```

**Story body** opens with `Epic: #<epic-n>`.

**Task body** opens with `Story: #<story-n>` and `Epic: #<epic-n>`.

---

## Phase 4: Report

```
## Backlog filed — <brief name>
Epics: <n> · Stories: <n> · Tasks: <n>
Adopted: <n> existing · Created: <n> new

Issue: #<root-epic-n> (<url>)
```

The last line is the chain marker. Print it exactly; other commands parse the issue number.

---

## Not to be confused with

- **`/sdlc:spec`** — writes an executable spec for one story. Run per story, not per epic.
- **`/sdlc:issue`** — files a single issue. This command calls it per tree node.
- **`/sdlc:brainstorm`** — thinks through the idea. Run before this, not after.
