---
ticket: GH-43
title: "Central session archive — slice decomposition"
---

# GH-43 — Central session archive

Source: https://github.com/emgiezet/aisdlc/issues/43

## Problem

Everything an unattended run leaves behind is per-repo and short-lived: `aisdlc clean` deletes
the task dir; worktrees are removed on success or abort; the Claude session is never linked;
omp sessions vanish with the task dir; nothing is redacted; `/sdlc:retro` only reads one
repo. The result: no post-mortems, no cross-repo learning loop, no cost accounting history,
no provenance chain for compliance.

## Decomposition

| slice | status | what it delivers |
|-------|--------|-----------------|
| [GH-43-a](../GH-43-a/spec.md) | **merged** (48bb657) | `task.json` records `sessions[]` per phase and `runtime_version` |
| [GH-43-b](https://github.com/emgiezet/aisdlc/pull/61) | **PR #61 open** | archive on terminal status — manifest, redacted logs/reports, `index.jsonl`; built-in regex redaction only |
| [GH-43-c](../GH-43-c/spec.md) | draft | transcript copies in `sessions/` inside the archive; betterleaks scanner (v2 JSONL, findings-driven, no publication on error/incomplete/encoded credential); `archive_transcripts` opt-out in `.aisdlc/config.json`; `archive: off` placement open question |
| [GH-43-d](../GH-43-d/spec.md) | draft | `aisdlc archive ls\|show\|grep\|prune` read/maintenance subcommands |
| [GH-43-e](../GH-43-e/spec.md) | draft | `/sdlc:retro --archive` reads `index.jsonl` for cross-repo pipeline metrics |
| [GH-43-f](../GH-43-f/spec.md) | draft | phase verdict/timestamp/session provenance and preservation of recorded model identity; depends-on GH-43-b |

## Archive contracts produced by GH-43-b (consumed by c/d/e/f)

**Functions:**
- `archive_task(repo, id)` — called at every terminal-status site before any worktree removal;
  non-fatal; reads `AISDLC_ARCHIVE` env var only. (`archive: off` config-key support is in
  GH-43-c but placement unresolved — see GH-43-c open questions.)
- `_arc_redact(src, dst)` — copies `src` to `dst` with built-in regex redaction; prints
  JSON `{rule:count}` to stdout.
- `_arc_merge(a, b)` — merges two `{rule:count}` JSON objects.
- `_arc_file(src, archive-rel-path)` — local helper inside `archive_task`; calls `_arc_redact`,
  accumulates `all_counts` and `files_json` via dynamic scope.
- `arc_slug(abs-path)` — selftest helper: `<basename>-<first-8-hex-sha256-of-abs-path>`.

**index.jsonl line schema:** `{id, ticket, repo, repo_slug, status, cost_usd, archived_at, path}`

**Archive layout:**
```
${AISDLC_ARCHIVE:-${XDG_DATA_HOME:-$HOME/.local/share}/aisdlc/archive}/
  index.jsonl          # flock-ed via <root>/index.lock sidecar
  <repo-slug>/<YYYY-MM>/<task-id>/              # first attempt
  <repo-slug>/<YYYY-MM>/<task-id>.<attempts>/  # subsequent retries (attempts > 1)
    manifest.json     # id, ticket, repo, base, branch, pr_url, status, attempts,
                      # cost_usd, runtime, runtime_version,
                      # model (always non-null — GH-43-f), models (per-phase or null),
                      # sessions (from task.json), aisdlc_version, policy_fingerprint,
                      # archived_at, redactions {rule:count}, files {rel-path:sha256}
                      # phases [{name,verdict,session_id,started,ended}] — GH-43-f; null if pre-f task
                      # transcripts [{phase,session_id,src,dst_rel,copied,reason}]  — GH-43-c
    task.json
    phases/<phase>.log, <phase>.json   # redacted
    spec/spec.md, qa-report.md, scope-report.md, verify-report.md, pr-body.md, BLOCKED.md
    sessions/<name>.jsonl              # GH-43-c only — transcript copies, redacted
```

**betterleaks gap:** GH-43-b uses built-in regex only. GH-43-c adds betterleaks v2 scanner
integration: run in JSONL mode, rc=1 = findings found (normal), rc>1 = scanner error →
no publication; `scan.state != "complete"` → no publication; decoded findings
(`encodings`/`decode_depth > 0`) → no publication (coordinate-based replacement unspecified).
Exact network-isolation flags and v1 support are open questions in GH-43-c spec. The
`manifest.scanner_warnings` field is removed from the contract (spec logs to `run.log` instead).

**Phase/model provenance allocated to GH-43-f:** The issue requires
`phases[{name, verdict, session_id, started, ended}]`; GH-43-b's `sessions[]` lacks verdicts
and native phases. The draft adds phase capture and preserves the recorded base model.
When archiving legacy task records without these fields, retain unknown values as null;
do not rewrite existing archives or invent historical provenance.

**PR #61 prerequisite risk [INFERENCE from static review]:** attempt-0 and attempt-1 paths can both resolve to `<id>`,
contrary to its append-only contract. The prerequisite must preserve both snapshots before
the remainder lands. GH-43-d's shared-path pruning guard prevents deletion of retained data,
but does not repair producer overwrite; no duplicate implementation of PR #61 is planned.

## Dependencies between slices

- **c/d/e/f block on GH-43-b** and its append-only contract; do not duplicate the open PR.
- **c, d, and f are semantically independent** after b but share runner, selftest, and
  documentation files; one integration owner must serialize overlapping edits.
- **e consumes b's archived task.json and manifest**, not c's transcripts or f's new phases.
  Its command implementation can proceed independently, with shared documentation integrated
  by the coordinator.

## Out of scope for all slices

- Remote upload or hosted service.
- A UI.
- Codex adapter (runner supports `claude|omp` only).
- Archiving interactive (non-queue) sessions.
