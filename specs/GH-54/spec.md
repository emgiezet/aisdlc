---
ticket: GH-54
title: "scope-check: Out: cross-reference to a file In: requires reports it out of bounds"
kind: bugfix
status: approved
approved-by: issue #54 (label bug, @emgiezet)
stacks: [bash, instructions]
---

# GH-54 — scope-check: Out: cross-reference to a file In: requires reports it out of bounds

## Problem

`run_scope_check()` evaluates `Out:` patterns before `In:` patterns; every backtick-quoted
path-like token extracted from an `Out:` bullet becomes an immediate prohibition. When an `Out:`
bullet merely cross-references a file that `In:` explicitly requires, the file is classified
`spec-out` and the task is BLOCKED, stopping the pipeline for a file the spec told the agent
to write. GH-44's spec worked around this by removing all paths from its `Out:` section by hand;
every spec author is exposed to the same trap silently.

Source: https://github.com/emgiezet/aisdlc/issues/54

## Scope

In:
- `plugins/sdlc/bin/aisdlc` — `run_scope_check()` classification loop: before the spec-Out matching (step 1), collect the verbatim exact paths from `In:` bullets only — excluding tokens that contain glob characters (`*`, `?`, `[`) or end with `/` (directory patterns); if the changed file matches one of these verbatim exact paths, skip ONLY step 1 (spec-Out matching); step 2 (repo-wide prohibition) and all subsequent steps still apply unchanged
- `evals/harness/selftest.sh` — regression cases named `GH-54`: (a) exact verbatim `In:` name beats an `Out:` cross-reference (PASS); (b) directory-pattern `In:` entry does not exempt (BLOCKED)
- `docs/ai-sdlc.md` — one-sentence note in the scope-check behavior section documenting the verbatim `In:` exemption

Out:
- `Context:` lines: a file mentioned only in `Context:` never exempts from `Out:` matching
- Repo-wide prohibited paths (`## Repo-wide out of bounds` in `.claude/sdlc.md`): always win over any `In:` entry; the fix does not alter step 2
- `In:` glob patterns (`*`, `?`, `[...]`) and directory patterns (trailing `/`): never exempt from `Out:` matching
- Size-budget logic, structure check, verify phase, report format, or any other pipeline phase

Change budget: 130 added lines, 3 files, 3 modules

## Context

- `plugins/sdlc/bin/aisdlc`: `run_scope_check()` — locals `in_pats`, `out_pats`, `prohibited_pats` built from `_scope_bullets()` + `_path_tokens()`; per-file classification loop: step 1 spec-Out, step 2 repo-wide, step 3 spec-dir artefact auto-pass, step 4 In:
- `plugins/sdlc/bin/aisdlc`: `_scope_bullets()` — extracts `In:` / `Out:` bullet text from `## Scope`; `_path_tokens()` — extracts backtick path-like tokens; `_glob_match()` — exact / directory / glob / `**` matcher
- `docs/ai-sdlc.md`: scope-check description paragraph ("The section that earns its keep most is `Out:`")
- `evals/harness/selftest.sh`: `fresh_repo()` and `task_field()` test helpers; `scope_verdict` field in `task.json` written by `run_scope_check()`

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | scope-check | branch touches only `docs/TAXONOMY.md`; spec `In:` names it verbatim; spec `Out:` cross-references it in prose | `scope_verdict` in `task.json` is `PASS`; scope-report.md row for `docs/TAXONOMY.md` shows `in scope`; pipeline is not BLOCKED | regression |
| UC-2 | scope-check | branch touches `docs/TAXONOMY.md`; spec `In:` lists only `docs/` (directory pattern); spec `Out:` names `docs/TAXONOMY.md` explicitly | `scope_verdict` is `BLOCKED`; row shows `out of bounds (spec-out)`; directory-pattern `In:` entry does not exempt the file | regression |
| UC-3 | scope-check | branch touches `docs/TAXONOMY.md`; spec `In:` contains a glob pattern (e.g. `docs/*.md`, `docs/[A-Z]*.md`, or `docs/TAXON?MY.md`) covering the file; spec `Out:` names it explicitly | `scope_verdict` is `BLOCKED`; row shows `out of bounds (spec-out)`; glob `*`, `?`, and `[...]` `In:` entries do not exempt from `Out:` | regression |
| UC-4 | scope-check | branch touches `docs/TAXONOMY.md`; spec `In:` names it verbatim; spec `Out:` cross-references it; `.claude/sdlc.md` repo-wide prohibited list also matches it | `scope_verdict` is `BLOCKED`; row shows `out of bounds (prohibited)`; the verbatim `In:` exemption skips only spec-Out (step 1) and does not suppress the repo-wide check (step 2) | regression |
| UC-5 | scope-check | branch touches `docs/TAXONOMY.md`; it appears only in `Context:` (not in `In:`); spec `Out:` names it explicitly | `scope_verdict` is `BLOCKED`; row shows `out of bounds (spec-out)`; a `Context:` mention does not exempt from `Out:` | regression |
| UC-6 | scope-check | branch touches `docs/TAXONOMY.md` (verbatim `In:` beats `Out:` cross-ref) and `lib/helper.sh` (present in neither `In:` nor `Out:`) | `scope_verdict` is `GAPS`; `docs/TAXONOMY.md` row shows `in scope`; `lib/helper.sh` row shows `undeclared`; pipeline continues | regression |

## Non-functional

None.

## Open questions

None.
