---
ticket: GH-43-e
title: "retro --archive reads cross-repo index.jsonl for pipeline metrics"
status: draft
stacks: [instructions]
depends-on: GH-43-b
---

# GH-43-e — `/sdlc:retro --archive` produces cross-repo pipeline metrics

Source: https://github.com/emgiezet/aisdlc/issues/43 · plan: `specs/GH-43/decomposition.md`

## Problem

`/sdlc:retro` reads only the current repo's `.aisdlc/tasks/` and cannot see tasks from other
repos, tasks that were cleaned, or the full cost history across a workflow. After GH-43-b the
archive holds a durable cross-repo `index.jsonl`; retro should be able to use it so recurring
failure patterns across all repos become visible.

## Scope

In:
- `plugins/sdlc/commands/retro.md`: add `--archive` as an accepted `$ARGUMENTS` flag.
- **Phase 0 (new, before Phase 1):** runs only when `--archive` is present.
  1. Resolve archive root: `${AISDLC_ARCHIVE:-${XDG_DATA_HOME:-$HOME/.local/share}/aisdlc/archive}`.
  2. If `AISDLC_ARCHIVE=off` or the archive root directory does not exist: print
     `archive unavailable or disabled` and stop (exit 0).
  3. Read `<root>/index.jsonl`; for each line apply `--since` (compare `archived_at` —
     note: live Phase 1 compares `.updated` from `task.json`; archive mode uses
     `archived_at`) and `--repo` (match `repo_slug`). Resolve `path` for each surviving
     entry; read its `task.json` at `<path>/task.json` (not `manifest.json`, which lacks
     `error`, `created`, and `updated`) to build each working task record. After reading,
     deduplicate by `(repo_slug, id)`: if multiple entries exist for the same `id` (retried
     tasks), retain the record with the highest task.json `attempts`, breaking ties by latest
     index `archived_at`. Then
     filter the deduplicated set to status `done` or `failed` only (`refused` and `cancelled`
     are excluded before Phases 2–4). `manifest.json` is read alongside `task.json` only for
     the `repo` field needed by Phase 3 tracker lookup.
- Phases 2, 3, 4 operate unchanged on the working task set. Supplementary files that Phases 2
  and 4 read are resolved from `<path>/spec/` in the archive (e.g. `<path>/spec/qa-report.md`
  for the `gaps` class, `<path>/spec/BLOCKED.md` for top causes), not from any live repo.
- Phase 3 cost-per-merged-PR: for each `done` task with non-null `pr_url`, extract the PR
  number and read the tracker descriptor at `<manifest.repo>/.claude/sdlc.md` (where
  `manifest.repo` comes from `manifest.json`.`repo`); execute **`get-pr`** operations in
  the context of `<manifest.repo>` as the working directory — **never** pass a filesystem
  path as the `{owner}/{repo}` tracker argument (a filesystem path is not a valid GitHub
  repo identity). Count a PR as merged only on an explicit merged state, normalizing case
  (`MERGED` from GitHub, `merged` from the local provider); `CLOSED` alone is not merged.
  If `<manifest.repo>` is absent on this machine, `.claude/sdlc.md` is missing, or the
  tracker call fails: classify the PR state as `unknown`; exclude from the merged
  denominator; print `n/a` for cost-per-merged-PR when no merged tasks have non-null
  `cost_usd`. Never count a non-null `pr_url` as "merged" without a successful tracker
  verification.
- Phase 2 `review-loop` classification: uses `manifest.pr_url` as the PR reference; read
  `<manifest.repo>/.claude/sdlc.md` for each task's tracker descriptor; execute the
  review-count lookup with `<manifest.repo>` as working directory; if the repo or descriptor
  is absent, mark the task's review-loop count as `n/a` and print the standard unavailability
  message.
- Phase 5 issue-handoff is unchanged.
- `--archive` absent: all behaviour is identical to today; archive root is never accessed.
- `docs/ai-sdlc.md`: one sentence cross-referencing `retro --archive` in the archive section.

Out:
- Changes to Phases 2–5 logic or output format when `--archive` is absent (zero regression).
- Reading live `.aisdlc/tasks/` when `--archive` is present.
- Writing to or modifying the archive.
- `aisdlc archive` subcommands (GH-43-d).
- Transcript copies (GH-43-c).
- Remote repo lookup or tracker calls when `manifest.repo` does not exist on this machine
  (absent-repo tasks report `unknown` PR state and are excluded from the merged count).

Change budget: 140 added lines, 2 files, 2 modules

## Context

- `plugins/sdlc/commands/retro.md` — Phase 1 discovery block (`ls .aisdlc/tasks/` hard-stop),
  `--since` / `--repo` arg handling, Phases 2–4 jq pipelines, Phase 5 issue handoff,
  `retro` non-functional constraints (≤ 60 output lines).
- `index.jsonl` schema (GH-43-b): `{id, ticket, repo, repo_slug, status, cost_usd,
  archived_at, path}`.
- `manifest.json` schema (GH-43-b, confirmed in `archive_task()` jq expression):
  `{id, ticket, repo, base, branch, pr_url, status, attempts, cost_usd, runtime,
  runtime_version, models, sessions, aisdlc_version, policy_fingerprint, archived_at,
  redactions, files}`. No `phases[]` field; no `error`, `created`, or `updated` — read
  `task.json` for these.
- `task.json` fields consumed by retro Phases 2–4: `.status`, `.updated`, `.created`,
  `.error`, `.cost_usd`, `.pr_url`, `.attempts`, `.id`. Archived copy at `<path>/task.json`.
- Archived supplementary files layout (GH-43-b): `<path>/spec/qa-report.md`,
  `<path>/spec/BLOCKED.md`.
- `evals/harness/selftest.sh` — `fresh_repo`, `arc_slug()`, existing retro invocation pattern.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-25 | maintainer | `retro --archive` with archive containing: repo-A (1 done task, cost_usd=0.10, pr_url set, tracker returns MERGED, error=null; 1 failed task, error="BLOCKED: spec was ambiguous", `spec/BLOCKED.md` first line "spec was ambiguous") and repo-B (1 done task, cost_usd=0.20, pr_url set, tracker returns MERGED, error=null; 1 failed task, error="BLOCKED: missing verify step", `spec/BLOCKED.md` first line "missing verify step") | Phase 2 table has 4 rows spanning both repos; `blocked` class count = 2; BLOCKED rate = 50% (2/4); cost-per-merged-PR = $0.15 (mean of 0.10 and 0.20); top causes include "spec was ambiguous" and "missing verify step"; no `.aisdlc/tasks/` path is accessed | harness-eval |
| UC-26 | maintainer | `retro --archive --since <date>` with one task having `archived_at` before `<date>` and one having `archived_at` after `<date>` | only the newer task appears in Phases 2–4 output; the older task's id is absent from all output | harness-eval |
| UC-27 | maintainer | `retro --archive --repo <slug>` with tasks from two distinct `repo_slug` values in `index.jsonl` | only tasks whose `repo_slug` matches `<slug>` appear in Phases 2–4 output; the other repo's tasks are absent | harness-eval |
| UC-28 | maintainer | `retro --archive` when `AISDLC_ARCHIVE=off` | prints `archive unavailable or disabled`; exits 0; no Phase 2–5 output produced | harness-eval |
| UC-29 | maintainer | `retro` (no `--archive`) in a repo with `.aisdlc/tasks/` entries | output matches current retro behaviour exactly; archive root directory is never stat'd or read | harness-eval |
| UC-39 | maintainer | `retro --archive` with archive containing: (a) one task id with two entries — attempts=1 cost_usd=0.10, attempts=2 cost_usd=0.30 (cumulative) — after dedup the task contributes $0.30 not $0.40; (b) one `refused` entry and one `cancelled` entry | cost-per-merged-PR denominator excludes the retry's earlier-attempt record; refused and cancelled tasks produce no rows in Phase 2 table and do not affect BLOCKED rate or total-finished count | harness-eval |
| UC-42 | maintainer | archive tasks reference PRs whose provider states are `MERGED`, `merged`, `OPEN`, and `CLOSED` | exactly the two explicitly merged PRs enter the merged denominator; neither open nor merely closed PR is counted as merged | harness-eval |

**Verification note:** UC-25 through UC-29, UC-39, and UC-42 verify the instruction prose by running
`/sdlc:retro --archive` end-to-end in a harness-eval scenario against stub archive data;
they confirm the computed metric values (BLOCKED rate, cost-per-merged-PR, top causes),
not merely that the jq filters parse the input.

## Non-functional

- `--archive` absent: archive root directory is never stat'd or read.
- Phase 0 reads `index.jsonl` once; manifest files are read once per entry. No writes.
- Report line-count budget ≤ 60 lines across Phases 2–4 is unchanged.

## Open questions

none
