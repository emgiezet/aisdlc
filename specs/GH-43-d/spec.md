---
ticket: GH-43-d
title: "aisdlc archive ls/show/grep/prune subcommands"
status: approved
stacks: [bash]
depends-on: GH-43-b
---

# GH-43-d — Read and maintain the archive from the command line

Source: https://github.com/emgiezet/aisdlc/issues/43 · plan: `specs/GH-43/decomposition.md`

## Problem

After GH-43-b the archive accumulates entries automatically, but there is no way to list,
inspect, search, or prune it. Operators cannot answer "what did we spend on GH-43 tasks last
month?" or remove stale entries without reading raw JSON files by hand.

## Scope

In:
- New `cmd_archive()` dispatcher in `plugins/sdlc/bin/aisdlc`, reached via `aisdlc archive
  <sub-action> [flags]`, with four sub-actions:

  - **`ls [--repo <slug>] [--status <s>] [--since <YYYY-MM-DD>]`** — read
    `<root>/index.jsonl`; filter by `repo_slug`, `status`, and `archived_at ≥ since`; print
    one tab-separated row per matching entry: `id | ticket | repo_slug | status | cost_usd |
    archived_at`.

  - **`show <id>`** — find all entries in `index.jsonl` where `.id == <id>`; if multiple
    (retries), print one header per attempt (`<id>`, `<id>.2`, …) followed by the resolved
    `manifest.json` as pretty JSON. If `<id>.<n>` is supplied, show only that attempt.
    Exit non-zero and print `not found: <id>` to stderr when no matching entry exists.

  - **`grep <pattern>`** — grep the extended-regex `<pattern>` over the `phases/*.log`,
    `phases/*.json`, and `sessions/*.jsonl` files within each task's archive directory;
    prefix each matching line with its archive-relative path. Never searches `manifest.json`,
    `task.json`, or `spec/` files. Read-only; never modifies any file.

  - **`prune --older-than <N>d`** — compute cutoff = now minus N days. First canonicalize
    `<root>` to its real absolute path (`canonical_root="$(realpath -m "$root")"`) so
    symlink or relative root values are resolved once. Under `flock "${root}/index.lock"` held
    for the full read-parse-filter-rewrite cycle: read all entries from `index.jsonl`; for
    each entry where `archived_at < cutoff`, resolve `path` to its canonical form; determine
    whether the canonical path is a strict descendant of `canonical_root` (begins with
    `canonical_root/` and is not equal to `canonical_root`); if not, skip with a stderr
    warning and retain the entry. For entries that pass the containment check, also verify
    that no retained entry (one whose `archived_at >= cutoff` or one already skipped) resolves
    to the same canonical path; if a retained entry shares the path, skip deletion with a
    stderr warning and retain the prunable entry in `index.jsonl` as well. Otherwise remove
    the archive task directory. Rewrite `index.jsonl` retaining all non-removed entries
    (younger, skipped, and shared-path). A second `prune` on a state where no entries fall
    below the cutoff is a no-op and exits 0.

- `cmd_help` USAGE block: add `aisdlc archive <ls|show|grep|prune>` with one-line description
  of each sub-action.
- `docs/ai-sdlc.md`: sub-section documenting each sub-action, flag semantics, and the
  retention-policy recommendation (default: `--older-than 180d`).
- `evals/harness/selftest.sh`: new UC-19 through UC-24, UC-38, and UC-40 test cases.

Out:
- Changes to `archive_task()`, `_arc_redact()`, `_arc_merge()`, or `index.jsonl` format
  (GH-43-b).
- Transcript copy (GH-43-c).
- `/sdlc:retro --archive` (GH-43-e).
- Remote or network archive paths.
- Pagination, streaming, or output formats other than plain text and pretty JSON.
- Pruning by cost or status (only by age).

Change budget: 260 added lines, 3 files, 3 modules

## Context

- `plugins/sdlc/bin/aisdlc` — `archive_task()` (GH-43-b); flock pattern on `index.lock`
  (GH-43-b); `cmd_clean`, `cmd_status` as structural examples; `cmd_help` USAGE heredoc.
- `index.jsonl` line schema (GH-43-b): `{id, ticket, repo, repo_slug, status, cost_usd,
  archived_at, path}`.
- `manifest.json` schema (GH-43-b): includes `archived_at`, `status`, `attempts`, `files`.
- Archive dir naming: `<root>/<slug>/<YYYY-MM>/<id>/` for first attempt;
  `<root>/<slug>/<YYYY-MM>/<id>.<attempts>/` for retries; `index.jsonl` may have multiple
  lines for the same `id` when retried.
- `evals/harness/selftest.sh` — `fresh_repo`, `arc_slug()` helper (GH-43-b).

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-19 | maintainer | `aisdlc archive ls` with two tasks in `index.jsonl` | stdout has exactly two data rows; each contains id, repo_slug, status, and archived_at; tab- or pipe-delimited | selftest |
| UC-20 | maintainer | `aisdlc archive ls --repo <slug> --status done --since <date>` | only rows matching all three predicates appear; a task from before `<date>`, from a different repo, or with a different status is absent | selftest |
| UC-21 | maintainer | `aisdlc archive show <id>` where `id` has two archived attempts | stdout contains two manifest blocks, one for `<id>` and one for `<id>.2`, in attempt order; exit 0 | selftest |
| UC-22 | maintainer | `aisdlc archive show <unknown-id>` | stderr contains `not found: <unknown-id>`; exit non-zero | selftest |
| UC-23 | maintainer | `aisdlc archive grep <pattern>` where `<pattern>` appears in one task's `phases/implement.log` and also in that same task's `spec/spec.md` | stdout contains the `phases/implement.log` match(es) prefixed with archive-relative path; the `spec/spec.md` content is not searched and its lines are absent from stdout; exit 0 | selftest |
| UC-24 | maintainer | `aisdlc archive prune --older-than 1d` after two tasks archived — one with `archived_at` 2 days ago, one with `archived_at` now (0 days ago) | the 2d-old task directory is removed and its `index.jsonl` entry is absent; the 0d-old task directory and its `index.jsonl` entry are retained; a second `prune --older-than 1d` exits 0 with no error | selftest |
| UC-38 | maintainer | `aisdlc archive prune --older-than 1d` with two `index.jsonl` entries for the same task `id` pointing to the same canonical directory, one 2d old and one 0d old | shared directory and both index entries remain intact; stderr explains the skipped shared-path deletion; exit 0 | selftest |
| UC-40 | maintainer | prune old entries using relative and symlink archive roots; include a valid descendant, the root itself, and a descendant symlink resolving outside the root | valid old descendant is removed under either root spelling; root and outside target remain untouched, their entries retained with safety warnings | selftest |

## Non-functional

- `archive ls` and `archive grep` are strictly read-only; they never modify archive files.
- `archive prune` canonicalizes `<root>` itself once via `realpath -m` before any comparison;
  also resolves each candidate `path` to its canonical form; never removes a directory whose
  canonical path does not begin with `canonical_root/` as a strict prefix, or that is
  referenced by any retained `index.jsonl` entry (i.e., a younger or safety-skipped entry
  that resolves to the same canonical path).
- `AISDLC_ARCHIVE=off`: all `archive` sub-actions print `archive disabled` to stderr and exit 0.
- Unknown sub-action: print usage to stderr and exit non-zero.
- `make selftest` and `plugins/sdlc/tests/run-tests` pass.

## Open questions

none
