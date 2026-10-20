---
ticket: GH-43-c
title: "Transcript copies in the archive — redacted session files, betterleaks, opt-outs"
status: draft
stacks: [bash]
depends-on: GH-43-b
---

# GH-43-c — Transcript copies land in the archive; betterleaks scanner; opt-outs

Source: https://github.com/emgiezet/aisdlc/issues/43 · plan: `specs/GH-43/decomposition.md`

## Problem

After GH-43-b the archive holds redacted phase logs and reports, but no agent transcripts:
claude sessions sit in `~/.claude/projects/` keyed by a path that will disappear; omp writes
`.jsonl` files per phase to the task's `sessions/` dir, which `clean` removes. The issue
requires betterleaks (when available) as a supplementary scanner pass, but GH-43-b implemented
built-in regex only. The `archive: off` / `archive_transcripts: off` opt-outs the issue
mentions are deferred from GH-43-b to this slice. Where those opt-outs live
(`.aisdlc/config.json` vs `.claude/sdlc.md`) is an open question — see below.

## Scope

In:
- **Transcript copy** — extend `archive_task()` in `plugins/sdlc/bin/aisdlc`: after copying
  phase files, iterate `task.json .sessions[]`:
  - *claude*: for each entry where `runtime == "claude"` and `transcript` is non-null and the
    source file exists, copy it via `_arc_file` to `sessions/<phase>-<session_id>.jsonl`.
  - *omp*: copy **all** `*.jsonl` files in `<task dir>/sessions/` (not only the one recorded
    in `transcript`, since omp may write multiple sub-agent session files per phase) to
    `sessions/omp-<original-filename>` in the archive. The `transcript` field in `task.json`
    is best-effort (latest file only, per GH-43-a `run_phase`); all sources must be preserved.
  - Append one record per copy attempt to `manifest.transcripts[]`:
    `{phase, session_id, src, dst_rel, copied, reason}`. On missing source:
    `copied: false, reason: "not found"`. On unreadable file: `copied: false, reason: "unreadable"`.
  - `manifest.files` sha256 entries include every successfully copied transcript.
- **betterleaks scanner integration** — betterleaks is a secrets *scanner* whose output is a
  findings report (JSONL in v2), not redacted text. Wrap `_arc_redact(src, dst)`:
  1. If `command -v betterleaks` succeeds (see Open questions on managed-path availability),
     invoke betterleaks in JSONL mode with validation and analysis explicitly disabled to
     prevent network I/O (exact flag syntax is version-dependent — see Open questions).
  2. Interpret exit codes: **rc=0** = no findings; proceed to built-in regex pass.
     **rc=1** = findings found (normal betterleaks result); parse JSONL output.
     **rc>1** = scanner error; **do not write this file to the archive**; log
     `archive scanner error: betterleaks rc=<N> on <rel-path>` to `run.log`. Whether to abort
     `archive_task()` or skip only this file is an open question (see below).
  3. For each JSONL finding record: check for `encodings`/`decode_depth > 0`. If present,
     `match.value` is the **decoded** form; the source contains the **encoded** form. Literal
     replacement finds zero bytes and the encoded credential survives. **Do not write this file
     to the archive.** Log `archive scanner gap: decoded finding (rule: <rule_id>)` to
     `run.log`. Coordinate-based replacement is an open question.
  4. Otherwise: replace the literal `match.value` in the working copy with
     `[REDACTED:betterleaks:<rule_id>]` and record the count.
  5. **Completeness gate**: parse the final JSONL scan metadata record. If `scan.state !=
     "complete"`, the scan was interrupted and secrets may have been missed. **Do not write
     this file to the archive.** Log `archive scanner incomplete: state=<state>` to `run.log`.
  6. After all finding replacements pass the gates, run built-in regex on the same working copy
     and merge counts from both passes.
  - UC-30 and UC-41 exercise the real scanner; the stub selftest alone is not scanner proof.
- **Opt-outs** — the issue says `archive: off` "in the profile" and `archive_transcripts: off`.
  The `archive: off` placement is an open question (see below) and is not implemented here.
  This slice implements `archive_transcripts` only:
  - `AISDLC_ARCHIVE=off` check (GH-43-b, unchanged) runs **first** in `archive_task()` —
    before any new checks — to preserve the no-extra-I/O guarantee.
  - `archive_transcripts` key in `.aisdlc/config.json`:
    `resolve_default "$repo" archive_transcripts "" "${AISDLC_ARCHIVE_TRANSCRIPTS:-}" "on"`;
    when `off`, skip the transcript-copy block only; set `manifest.transcripts = "disabled"`
    (string, not array).
- **Wiring** — all locations where new keys and env vars must appear:
  - `cmd_help` USAGE heredoc (`:2565-2648`): add `"archive_transcripts": "off"` as an
    optional key comment after the `model_roles` block (`:2625-2636`); add
    `AISDLC_ARCHIVE_TRANSCRIPTS` and `AISDLC_ARCHIVE` to the env-overrides line (`:2638-2640`).
    `AISDLC_ARCHIVE` was omitted from GH-43-b's cmd_help despite being added to
    `docs/ai-sdlc.md`; correct here.
  - `docs/ai-sdlc.md` archive section (GH-43-b): one paragraph on transcript handling,
    betterleaks scanner publication contract, and the `archive_transcripts` opt-out.
  - The `archive: off` wiring depends on open-question resolution.
- `evals/harness/selftest.sh`: new UC-14 through UC-18 cases; UC-30/41 require scanner scenarios.

Out:
- Changes to `_arc_merge()`, `index.jsonl` format, or other files copied in `archive_task()`
  (GH-43-b).
- `aisdlc archive` subcommands (GH-43-d).
- `/sdlc:retro --archive` (GH-43-e).
- Truncation, size-limiting, or integrity verification of transcript content.
- Modifying live transcript files under `~/.claude/projects/` or `<task dir>/sessions/`.
- The `AISDLC_ARCHIVE=off` env-var check (GH-43-b; unchanged).
- `AISDLC_ARCHIVE` path-value semantics (GH-43-b; unmodified).
- The `archive: off` config-layer opt-out (deferred to open-question resolution).
- Coordinate-based replacement for encoded betterleaks findings.
- betterleaks v1 support (v1 flags and field names unverified; open question).

Change budget: 230 added lines, 3 files, 3 modules

## Context

- `plugins/sdlc/bin/aisdlc` — `archive_task()` and its inner `_arc_file()` and `all_counts`/
  `files_json` dynamic-scope vars (GH-43-b); `_arc_redact(src, dst)` (GH-43-b); `_arc_merge()`
  (GH-43-b); `cfg(repo, key)` reads `.aisdlc/config.json` (`:109-114`);
  `resolve_default(repo, key, given, env, builtin)` (`:117-124`); `archive_task()` first check:
  `[ "${AISDLC_ARCHIVE:-}" = "off" ] && return 0` (GH-43-b, must remain first); `cmd_help`
  USAGE heredoc (`:2565-2648`), config.json example `:2622-2623`, env-overrides `:2638-2640`.
- `evals/harness/stub-claude` — emits per-phase `session_id`; `AISDLC_STUB=keyleak` plants
  `sk-ant-...` in implement result (GH-43-b).
- `evals/harness/stub-omp` — writes one `${ts}_${uuid}.jsonl` per invocation into
  `--session-dir` (`:73-75`); multiple files accumulate across phases.
- `evals/harness/selftest.sh` — `fresh_repo`, `arc_slug()` helper (GH-43-b),
  `AISDLC_ARCHIVE` env pattern (UC-6–UC-13).
- `docs/ai-sdlc.md` — archive section (GH-43-b).
- `task.json .sessions[]` contract: `{phase, runtime, session_id, transcript, started, ended}`
  (GH-43-a); `transcript` for omp is the latest session file only.
- betterleaks v2 JSONL output (confirmed from `betterleaks/betterleaks docs/scanning.md`):
  one `{"schema_version":"1","finding":{...}}` per secret found; final record
  `{"schema_version":"1","scan":{"state":"complete"|"incomplete",...}}`. Finding fields:
  `finding.rule_id` (string), `finding.match.value` (extracted secret bytes — decoded bytes for
  decoded findings), `finding.encodings` (array, present when decoding occurred),
  `finding.decode_depth` (int, present when decoding occurred). v2 invocation flag: `--jsonl`.
  v1 CLI flags and v1 JSON field names are unverified; v1 support is an open question.
- slop-guard `docs/slop-guard-spec.md:1529` — betterleaks used in pre-write hook context;
  `lib/secrets.sh:18-26` confirms rc=1 = findings found (not error).

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-14 | queue | stub claude task reaches `done`; stub emits per-phase `session_id` | `sessions/implement-<session_id>.jsonl` exists in archive task dir; content has planted key replaced by `[REDACTED:…]`; `manifest.transcripts[0].copied` is `true`; sha256 of copy in `manifest.files` | selftest |
| UC-15 | queue | stub omp task reaches `done`; stub-omp writes one `.jsonl` into `--session-dir` | file appears in `sessions/` as `omp-<original-filename>`; `manifest.transcripts` has one entry with `copied: true` | selftest |
| UC-16 | queue | `task.json .sessions[].transcript` names a file that does not exist at archive time | archive dir and other files present; `manifest.transcripts[0].copied` is `false` and `reason` is `"not found"`; task exit code unchanged | selftest |
| UC-17 | maintainer | `archive_transcripts: "off"` in `.aisdlc/config.json` or `AISDLC_ARCHIVE_TRANSCRIPTS=off` | no `sessions/` subdirectory in archive task dir; `manifest.transcripts` equals the string `"disabled"`; all other archive files present normally | selftest |
| UC-18 | queue | transcript source file present but mode 000 (unreadable) | `manifest.transcripts[0].copied` is `false` and `reason` is `"unreadable"`; archive dir and other files unaffected; `archive_task()` returns 0 | selftest |
| UC-30 | maintainer | betterleaks v2 on PATH; transcript has non-encoded secret betterleaks recognises but built-in regex does not; scan completes | archived copy has secret replaced by `[REDACTED:betterleaks:<rule_id>]`; `manifest.transcripts[0].copied` is `true` | manual — selftest cannot install betterleaks |
| UC-41 | maintainer | scanner is available but errors, reports an incomplete scan, or finds an encoded credential without supported source-coordinate redaction | affected file is never published; diagnostic records the reason without the credential; existing archives and live task outcome remain unchanged | manual scanner scenarios |

## Non-functional

- Transcript copy failure is non-fatal; `archive_task()` continues and returns 0.
- The live transcript source file is never modified or removed.
- betterleaks publication contract: a file is written to the archive only when all hold:
  (a) rc ≤ 1; (b) scan.state == "complete"; (c) no finding carries `encodings`/`decode_depth > 0`.
  Any failure withholds that file (or the entire archive — see Open questions).
- betterleaks invocation must disable validation and analysis to prevent network I/O (exact
  flags are version-dependent — see Open questions).
- betterleaks not on PATH: built-in regex only; no log entry; no behavior change.
- `make selftest` and `plugins/sdlc/tests/run-tests` pass on machines without betterleaks.

## Open questions

- [ ] **betterleaks version and v1 support**: v2 `--jsonl --no-banner` is confirmed. v1 CLI
  flags and field names are unverified (migration guide documents v1→v2 schema changes; v1
  field names differ). Require v2 only, or detect version and branch? Blocks implementation.
- [ ] **Network isolation flags**: betterleaks with `BETTERLEAKS_VALIDATE=true` or
  `BETTERLEAKS_ANALYZE=true` in the environment makes network requests, violating "nothing
  leaves the machine". v2 provides `--analyze=false --validate=false`. Are explicit flags
  required or is env-var override sufficient? What are the per-version flag names?
- [ ] **Decoded credential replacement**: when a finding carries `encodings`/`decode_depth > 0`,
  `match.value` is decoded and literal replacement finds zero bytes in the encoded source.
  Coordinate-based replacement using finding source coordinates is the safe approach but is
  unspecified. Until resolved: spec withholds publication for any file with a decoded finding.
  Is this the intended trade-off, or must coordinate-based replacement be implemented in GH-43-c?
- [ ] **betterleaks scanner error (rc>1) — abort archive or skip file**: both withhold the
  unscanned file. Abort `archive_task()` entirely (no archive entry for this task) vs skip only
  the failed file and complete the rest?
- [ ] **betterleaks availability — `command -v` vs managed path**: `command -v betterleaks`
  detects PATH installs. slop-guard's `lib/tools.sh:4-8` and `secrets.sh:9-15` use a managed
  `resolve_tool` path. The issue says "if slop-guard's betterleaks is available". Should
  `archive_task()` also check slop-guard's managed install location?
- [ ] **Where does `archive: off` opt-out live**: the issue says `archive: off` "in the
  profile". In aisdlc, "profile" = `.claude/sdlc.md` (generated by `/sdlc:init`). The runner
  uses `cfg()` which reads `.aisdlc/config.json`; no existing parser for key-value opt-outs
  from `.claude/sdlc.md`. Should `archive: off` live in `.aisdlc/config.json` (no new parser)
  or in `.claude/sdlc.md` (requires new grep/sed parser in `archive_task()`)? Determines
  wiring targets for cmd_help and `/sdlc:update`.
- [ ] **`AISDLC_ARCHIVE=off` and "no extra I/O" scope**: the issue acceptance criterion says
  `AISDLC_ARCHIVE=off` produces "no archive and no extra I/O". GH-43-a unconditionally records
  `runtime_version` and `sessions[]` regardless of `AISDLC_ARCHIVE`. Does "no extra I/O" mean
  no archive writes only (archive_task-scoped), or no additional I/O beyond phase work
  (implicating GH-43-a's session writes)?
