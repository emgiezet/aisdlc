---
ticket: GH-43-e
title: /sdlc:retro --archive computes its metrics across every archived repo
status: approved
stacks: [instructions]
depends-on: GH-43-b
---

# GH-43-e — Retro across repos, from the archive

Source: https://github.com/emgiezet/aisdlc/issues/43 · plan: `specs/GH-43/decomposition.md`

## Problem

`/sdlc:retro` reads one repository's `.aisdlc/tasks/*/task.json`, so it sees neither cleaned tasks
nor any other repository. Recurring failure causes across repos stay invisible, which is the
learning loop the archive (`GH-43-b`) exists to feed.

## Scope

In:
- `--archive` flag in `plugins/sdlc/commands/retro.md`: discovery reads `<root>/index.jsonl`
  (root resolved as in `GH-43-b`), keeps entries with `status` `done` or `failed` and
  `archived_at` ≥ `--since`, and reads each entry's archived `task.json` and `spec/BLOCKED.md`
  instead of the repo's.
- The same classes, cause ranking and metrics as today, computed over all kept entries, plus one
  line per repo_slug with its finished count and spend.
- `docs/ai-sdlc.md`: one line under the retro description.

Out:
- `--repo` combined with `--archive` (the archive is cross-repo by definition): rejected with a
  one-line message *(inferred)*.
- Tracker reads for archived tasks of other repositories: merge ratio and review-loop count print
  `n/a` with the existing "tracker is local or unreachable" line *(inferred: retro's tracker
  descriptor belongs to the current repo only)*.
- Any change to the classes, cost formula or issue hand-off; any `aisdlc` code.

Change budget: 45 added lines, 2 files, 2 modules

## Context

- `plugins/sdlc/commands/retro.md` — `$ARGUMENTS` line, `## Phase 1: Discover finished runs`,
  `## Phase 4: Metrics`.
- `index.jsonl` and manifest fields — `specs/GH-43-b/spec.md` In: list.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-29 | maintainer | `/sdlc:retro --archive` with archived tasks from two stub repos | the Phase 4 metric lines are printed once, computed over both repos' tasks, followed by one line per repo_slug | live run (sandbox) |
| UC-30 | maintainer | `/sdlc:retro --archive --since <date after every entry>` | `no archived runs since <date>` and stop | live run (sandbox) |
| UC-31 | maintainer | `/sdlc:retro --archive` when `<root>/index.jsonl` does not exist *(inferred negative)* | `no archive at <root>` and stop; nothing read from `.aisdlc/tasks/` | live run (sandbox) |

## Non-functional

- `retro.md` stays within its command line budget (`make validate`).

## Open questions

none
