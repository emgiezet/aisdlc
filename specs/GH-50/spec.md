---
ticket: GH-50
title: "scope-check size budget: uv.lock counted as review surface"
kind: bugfix
status: approved
approved-by: issue #50 (label bug, @emgiezet)
stacks: [bash]
---

# GH-50 — uv.lock excluded from change-budget review surface

Source: https://github.com/emgiezet/aisdlc/issues/50

## Problem

`_SIZE_EXCLUDE` in `plugins/sdlc/bin/aisdlc` omits `uv\.lock`, so branches in uv-managed
Python projects inflate their added-line, file, and module counts; the scope report claims
lock files are excluded but the budget arithmetic includes them.

## Scope

In:
- `plugins/sdlc/bin/aisdlc` — `_SIZE_EXCLUDE` variable: append `uv\\.lock` to the
  lock-file alternation group (doubled backslash; the pattern travels through `awk -v`).
- `plugins/sdlc/tests/size_budget_test.sh` — fixture `work`-branch setup block: commit a
  `uv.lock` containing at least one line (e.g. 20 `dep` lines via `printf`) so the exclusion
  is exercised under realistic conditions; expected counts must remain 42 / 4 / 3.
- `docs/ai-sdlc.md` — "lock files" sentence (§ "A plan may be large; a pull request may not"):
  add `uv.lock` to the parenthetical example list so the documentation matches the code.

Out:
- No other lock-file patterns added or removed.
- No changes to `_size_stats()`, `_size_eval()`, `budget_value()`, `scope-check` command,
  or any other function.
- No changes to the scope-report template text.
- No changes to `.claude/sdlc.md` change-budget section.

Change budget: 15 added lines, 3 files, 2 modules

## Context

- `plugins/sdlc/bin/aisdlc` — `_SIZE_EXCLUDE` variable: the lock-file segment of the pattern
  ends with `poetry\\.lock`; `uv\\.lock` must be appended inside the same `(^|/)(…)$`
  alternation group.
- `plugins/sdlc/bin/aisdlc` — `_size_stats()`: passes `_SIZE_EXCLUDE` via `awk -v excl=`;
  both the `--numstat` and `--diff-filter` call sites inherit the fix from the variable alone —
  no function body change required.
- `plugins/sdlc/tests/size_budget_test.sh` — fixture `work`-branch setup block: currently
  commits `vendor/lib/generated.go` (vendored), `package-lock.json` (lock), `specs/T-1/spec.md`
  (spec artefact) as excluded files; `uv.lock` with nonzero content must be added here.
- `plugins/sdlc/tests/size_budget_test.sh` — size-stat assertion block: assertions
  `_sb_added=42`, `_sb_files=4`, `_sb_mods=3` must survive the fixture addition unchanged.
- `docs/ai-sdlc.md` — §"A plan may be large; a pull request may not": sentence ending
  "lock files and the specs directory never count"; receives `uv.lock` in the example list.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | `_size_stats` | worktree whose only diff vs base is a `uv.lock` file containing 20 lines | function prints `0 0 0` — zero added lines, zero files, zero modules; the 20 lines do not appear in the added-lines total | regression |
| UC-2 | test runner | `bash plugins/sdlc/tests/size_budget_test.sh` executed with `uv.lock` present in the fixture `work` commit | exits 0; prints `ok size: added lines count code only` (value 42), `ok size: files touched include the emptied file, exclude vendor/lock/specs` (value 4), `ok size: module = first two path segments` (value 3); FAIL counter zero | regression |
| UC-3 | `_size_stats` | branch adds any previously listed lock file (`poetry.lock`, `yarn.lock`, `pnpm-lock.yaml`, `composer.lock`, `Cargo.lock`, `go.sum`, `Gemfile.lock`) | zero added lines, zero files, zero modules for each; existing `package-lock.json` assertion in the test still passes | regression |
## Non-functional

None.

## Open questions

None.
