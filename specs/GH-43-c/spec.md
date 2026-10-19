---
ticket: GH-43-c
title: The archive keeps redacted agent transcripts; profile switches turn archive or transcripts off
status: approved
stacks: [bash, instructions]
depends-on: GH-43-b
---

# GH-43-c — Archive the agent transcripts, with opt-outs and a stronger redactor

Source: https://github.com/emgiezet/aisdlc/issues/43 · plan: `specs/GH-43/decomposition.md`

## Problem

After `GH-43-b` the archive keeps a task's logs and reports but not the transcript that explains
the agent's choices; the Claude transcript is lost to Claude's own retention and the omp session
dies with `clean`. Transcripts are also where secrets read from files are most likely to appear,
and some repositories must not keep them at all.

## Scope

In:
- For every `task.json .sessions` entry (`GH-43-a`), copy its `transcript` into the archive as
  `sessions/<phase>-<session_id>.jsonl`, redacted, hashed into `manifest.files`.
- A missing transcript file → `manifest.sessions[].transcript_archived: "missing"`; the archive is
  still written.
- Profile `.claude/sdlc.md`, new section `## Archive` in `plugins/sdlc/templates/sdlc.md`:
  `- **Archive:** on` and `- **Archive transcripts:** on` (`on|off`). `Archive: off` disables
  archiving like `AISDLC_ARCHIVE=off`; `Archive transcripts: off` archives everything but
  `sessions/` and sets `manifest.transcripts: "off"`.
- Redaction: when `betterleaks` is on `PATH`, run it over each file before the built-in rules and
  replace each finding's secret with `[REDACTED:betterleaks:<RuleID>]`; `manifest.redactor` is
  `betterleaks+builtin` or `builtin`.
- `docs/ai-sdlc.md`: transcripts, the two profile switches, the redactor.

Out:
- Read-side commands — `GH-43-d`; `/sdlc:retro` — `GH-43-e`.
- Installing or pinning betterleaks; `plugins/slop-guard/**` (its invocation is read, not changed).
- Transcripts of interactive (non-queue) sessions; Codex.
- Changing what the built-in rules from `GH-43-b` match.
- `commands/update.md`: it already proposes template profile fields that a repo lacks.

Change budget: 210 added lines, 4 files, 4 modules

## Context

- `plugins/sdlc/bin/aisdlc` — the archive writer added by `GH-43-b`; `_budget_profile` (reading a
  `**Label:**` under a `## ` section of the profile — the pattern for `## Archive`).
- `plugins/slop-guard/lib/secrets.sh` — how betterleaks is located and invoked
  (`for scanner in betterleaks gitleaks`), and `lib/stop.sh` for its report format.
- `plugins/sdlc/templates/sdlc.md` — section order; `## Archive` goes after `## Change budget`.
- `evals/harness/selftest.sh`, `evals/harness/stub-omp` (session file from `GH-43-a`).

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-14 | queue | a claude task reaches `done`; its transcript file exists at the recorded path | archive has `sessions/<phase>-<session_id>.jsonl` per phase, redacted, listed in `manifest.files` with a matching sha256 | selftest |
| UC-15 | queue | an omp task reaches `done` | archive has `sessions/<phase>-<uuid>.jsonl` copied from the task's `sessions/` | selftest |
| UC-16 | queue | a recorded transcript path does not exist *(inferred)* | archive written; that entry's `transcript_archived` is `missing`; no error status | selftest |
| UC-17 | maintainer | profile `Archive transcripts: off`, task reaches `done` | archive has no `sessions/` dir; `manifest.transcripts` is `off`; logs and reports present | selftest |
| UC-18 | maintainer | profile `Archive: off`, task reaches `done` | no archive dir, no index line | selftest |
| UC-19 | queue | a stub `betterleaks` on `PATH` reports a finding the built-in rules do not match | archived file has `[REDACTED:betterleaks:<RuleID>]`; `manifest.redactor` is `betterleaks+builtin` | selftest |
| UC-20 | queue | no `betterleaks` on `PATH` | `manifest.redactor` is `builtin`; UC-8's built-in redaction still applies | selftest |

## Non-functional

- betterleaks exiting non-zero for a reason other than "findings" → built-in rules only,
  `manifest.redactor: "builtin (betterleaks failed)"`; archiving continues *(inferred)*.
- `make selftest` and `CI= make validate` pass; tests use a generated betterleaks stub, no real binary.

## Open questions

none
