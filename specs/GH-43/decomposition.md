# Decomposition — GH-43

Source: https://github.com/emgiezet/aisdlc/issues/43 (central session archive)

Estimate: ~1025 added lines · 9 files · 5 modules (budget 400/15/6 from PR #45's profile;
defaults 400/15/3 without it). Added lines break the budget 2.5×.
Seam: walking skeleton, then vertical — capture first, then archive, then widen it.

| Slice | Outcome a user or operator can see | UCs | Budget | Depends on |
|---|---|---|---|---|
| `GH-43-a` | `task.json` names every phase's session id, transcript path and runtime version | UC-1…UC-5 | 110 lines, 4 files, 3 modules | — |
| `GH-43-b` | finished tasks land, redacted, in `~/.local/share/aisdlc/archive` with manifest and index; survive `clean` | UC-6…UC-13 | 360 lines, 4 files, 4 modules | `-a` |
| `GH-43-c` | the archive also keeps redacted transcripts; profile switches turn archive or transcripts off; betterleaks used when present | UC-14…UC-20 | 210 lines, 4 files, 4 modules | `-b` |
| `GH-43-d` | `aisdlc archive ls\|show\|grep\|prune` | UC-21…UC-28 | 300 lines, 4 files, 4 modules | `-b` |
| `GH-43-e` | `/sdlc:retro --archive` reports across repos | UC-29…UC-31 | 45 lines, 2 files, 2 modules | `-b` |

Order: -a → -b → (-c, -d, -e in any order). Each merges on its own; none waits for the next.

Not sliced out:
- Built-in redaction stays inside `-b`: an archive that ships without redaction keeps unredacted
  prompts beyond `clean`, which is a worse state than no archive.
- `AISDLC_ARCHIVE=off` stays inside `-b` for the same reason; the committed profile switches,
  which need a template field, move to `-c`.

Corrections to the issue, verified in the code:
- There is no `blocked` task status. Terminal statuses are `done`, `failed`, `refused`, `cancelled`.
- Claude's project-dir encoding replaces `.` as well as `/` with `-`
  (`~/.claude/projects/…-compare-service--claude-worktrees-…`).
- omp session files are `<ISO-ts>_<uuid>.jsonl`; the session id is the uuid.
