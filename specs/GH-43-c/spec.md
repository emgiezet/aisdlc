---
ticket: GH-43-c
title: "Transcript copies in the archive — redacted session files, betterleaks, opt-outs"
status: approved
stacks: [bash, instructions]
depends-on: GH-43-b
---

# GH-43-c — Transcript copies land in the archive; betterleaks scanner; opt-outs

Source: https://github.com/emgiezet/aisdlc/issues/43 · plan: `specs/GH-43/decomposition.md`

## Problem

After GH-43-b the archive holds redacted phase logs and reports, but no agent transcripts:
claude sessions sit in `~/.claude/projects/` keyed by a path that will disappear; omp writes
`.jsonl` files per phase to the task's `sessions/` dir, which `clean` removes. The issue
requires betterleaks (when available) as a supplementary scanner pass, but GH-43-b implemented
built-in regex only. The opt-outs deferred from GH-43-b are `Archive: off` in the repository
profile `.claude/sdlc.md` and `archive_transcripts: "off"` in `.aisdlc/config.json`.

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
  1. Discover an installed betterleaks on PATH or through slop-guard's existing managed-tool
     resolver; do not install or download it. Require v2 JSONL with `--analyze=false
     --validate=false` explicitly, overriding inherited network-enabling environment values.
  2. Interpret exit codes: **rc=0** = no findings; proceed to built-in regex pass.
     **rc=1** = findings found (normal betterleaks result); parse JSONL output.
     **rc>1** = scanner error; abort publication of the entire new archive; log
     `archive scanner error: betterleaks rc=<N> on <rel-path>` to `run.log`.
  3. For each JSONL finding record: check for `encodings`/`decode_depth > 0`. If present,
     `match.value` is the **decoded** form; the source contains the **encoded** form. Literal
     replacement finds zero bytes and the encoded credential survives. **Abort publication
     of the entire new archive.** Log `archive scanner gap: decoded finding (rule: <rule_id>)`
     to `run.log`; do not implement coordinate-based replacement.
  4. Otherwise: replace the literal `match.value` in the working copy with
     `[REDACTED:betterleaks:<rule_id>]` and record the count.
  5. **Completeness gate**: parse the final JSONL scan metadata record. If `scan.state !=
     "complete"`, the scan was interrupted and secrets may have been missed. **Abort publication
     of the entire new archive.** Log `archive scanner incomplete: state=<state>` to `run.log`.
  6. After all finding replacements pass the gates, run built-in regex on the same working copy
     and merge counts from both passes.
  - UC-30 and UC-41 exercise the real scanner; the stub selftest alone is not scanner proof.
- **Opt-outs**:
  - `Archive: off` in `.claude/sdlc.md` disables all archiving; use the profile's Markdown
    field convention and preserve explicit settings during update.
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
  - `/sdlc:init`, `/sdlc:update`, and the profile template expose `Archive` and preserve opt-outs;
    init/update also describe the optional `archive_transcripts` config key.
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
- Coordinate-based replacement for encoded betterleaks findings.
- betterleaks v1 support.

Change budget: 600 added lines, 7 files, 3 modules

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
  Only v2 is supported; a present but incompatible scanner fails closed without publication.
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
| UC-41 | maintainer | scanner is available but errors, reports an incomplete scan, or finds an encoded credential without supported source-coordinate redaction | no new archive or index entry is published; diagnostic records the reason without the credential; existing archives and live task outcome remain unchanged | manual scanner scenarios |
| UC-43 | maintainer | profile contains `Archive: off`, or `AISDLC_ARCHIVE=off` is set | no archive directory, scanner invocation, or archive write occurs; ordinary phase provenance remains available | selftest |

## Non-functional

- Missing or unreadable transcript sources are recorded and non-fatal; scanner or redaction
  failure withholds the entire new archive while preserving the live task outcome.
- The live transcript source file is never modified or removed.
- betterleaks publication contract: a file is written to the archive only when all hold:
  (a) rc ≤ 1; (b) scan.state == "complete"; (c) no finding carries `encodings`/`decode_depth > 0`.
  Any failure withholds the entire new archive and index entry.
- betterleaks invocation explicitly disables validation and analysis to prevent network I/O.
- No PATH or managed betterleaks installation: built-in regex only; no installation or download.
- `make selftest` and `plugins/sdlc/tests/run-tests` pass on machines without betterleaks.

## Approved decisions

The user selected “Zatwierdź ten wariant” for this contract and the corrected budget:
600 added lines / seven files / three modules, including init/update/profile wiring.

- Support installed betterleaks v2 only; do not guess v1 flags or install tools.
- Pass explicit `--analyze=false --validate=false`, including when inherited environment
  variables enable those features.
- Scanner errors, incomplete scans, or encoded findings abort the entire new archive.
  Preserve existing archives and the live task outcome; diagnostics must not contain secrets.
- Search PATH and the existing managed installation through slop-guard's resolver.
- Put `Archive: off` in `.claude/sdlc.md`; keep `archive_transcripts` in runner JSON config.
- `AISDLC_ARCHIVE=off` remains the first check. “No extra I/O” is archive-scoped; existing
  operational session/runtime provenance from GH-43-a is unchanged.
