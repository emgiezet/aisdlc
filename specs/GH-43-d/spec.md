---
ticket: GH-43-d
title: aisdlc archive ls|show|grep|prune — read and retain the archive from the command line
status: approved
stacks: [bash]
depends-on: GH-43-b
---

# GH-43-d — Read side and retention for the archive

Source: https://github.com/emgiezet/aisdlc/issues/43 · plan: `specs/GH-43/decomposition.md`

## Problem

After `GH-43-b` the archive grows forever and is readable only with `jq` and `find`. A maintainer
needs to find a past task by repo, status or date, open what it left behind, search the redacted
logs for a recurring failure, and drop entries past a retention age.

## Scope

In:
- `aisdlc archive ls [--repo <slug-or-path>] [--status <s>] [--since <YYYY-MM-DD>]`: one line per
  `index.jsonl` entry, newest first: `archived_at`, id, repo_slug, ticket, status, cost.
- `aisdlc archive show <id>`: the manifest summary (ticket, repo, status, attempts, cost, runtime,
  runtime_version, sessions, redaction counts) and the archived file list.
- `aisdlc archive grep <pattern>`: `grep -E` over `phases/` and `sessions/` of every entry,
  each match prefixed `<id>:<relative path>:<line>`.
- `aisdlc archive prune --older-than <n>d`: removes entries whose `archived_at` is older than
  `n` days, and their `index.jsonl` lines, under the same `flock` as appends.
- All four resolve `<root>` the way `GH-43-b` does; `aisdlc help` lists them.
- `docs/ai-sdlc.md` and README: the subcommands and the retention recommendation (`180d`).

Out:
- Automatic or scheduled pruning; `cmd_clean` stays unaware of the archive.
- Any change to what is archived or how it is redacted — `GH-43-b`, `GH-43-c`.
- `/sdlc:retro --archive` — `GH-43-e`.
- Output formats other than plain text (no `--json`).

Change budget: 300 added lines, 4 files, 4 modules

## Context

- `plugins/sdlc/bin/aisdlc` — dispatch at the bottom of the file; `cmd_help`; the archive root
  resolver and index writer from `GH-43-b`; `cmd_status` / `cmd_logs` output style; `die`, `say`.
- `evals/harness/selftest.sh` — archive fixtures produced by running stub tasks (`GH-43-b`).
- `docs/ai-sdlc.md`, `README.md` — command tables.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-21 | maintainer | `aisdlc archive ls` with three archived tasks | three lines, newest first, each with id, repo_slug, ticket, status | selftest |
| UC-22 | maintainer | `aisdlc archive ls --status failed --since <today>` | only failed tasks archived today; exit 0 with no lines when none match | selftest |
| UC-23 | maintainer | `aisdlc archive show <id>` | output contains the ticket, status, each session id and every archived file path | selftest |
| UC-24 | maintainer | `aisdlc archive show nope` *(inferred negative)* | exit non-zero, stderr `no archived task nope`, nothing else printed | selftest |
| UC-25 | maintainer | `aisdlc archive grep 'REDACTED'` after UC-8 | at least one `<id>:phases/<phase>.log:<line>` match; no match from outside the archive root | selftest |
| UC-26 | maintainer | `aisdlc archive prune --older-than 0d` | every entry dir removed; `index.jsonl` empty | selftest |
| UC-27 | maintainer | `aisdlc archive prune --older-than 180d` with entries from today *(inferred)* | nothing removed; `index.jsonl` unchanged | selftest |
| UC-28 | maintainer | `aisdlc archive prune` without `--older-than`, or `--older-than 3w` *(inferred negative)* | exit non-zero naming the expected `<n>d` form; nothing removed | selftest |

## Non-functional

- With `AISDLC_ARCHIVE=off`, every `archive` subcommand exits non-zero with `archive is off`
  *(inferred)*.
- `ls`, `show` and `grep` never write to the archive.
- `make selftest` and `CI= make validate` pass.

## Open questions

none
