---
ticket: GH-51
title: "scope-check: harness reports under specs/<TICKET>/ classified as undeclared"
kind: bugfix
status: approved
approved-by: issue #51 (label bug, @emgiezet)
stacks: [bash]
---

# GH-51 — `_branch_changes` helper shared by `run_scope_check` and `run_verify`

Source: https://github.com/emgiezet/aisdlc/issues/51

## Problem

`run_scope_check` obtains the branch diff via bare `git diff --name-only` with no
exclusion filter, so pipeline artefacts written by the harness into `specs/<TICKET>/`
(qa-report.md, scope-report.md, etc.) appear as "undeclared" files and cause every real
spec to get GAPS. `run_verify` already applies two exclusion rules — the task's own
`specs/<TICKET>/` prefix and the root bookkeeping files `AGENTS.md`, `CLAUDE.md`,
`.claude/` — and its comment says "same rule as scope-check", but scope-check never called
those rules. Commit 4750785 added a step-3 workaround that re-classifies `specs/<TICKET>/`
files as "in scope" after the fact; this leaves the artefacts visible in the report and
does not cover the root bookkeeping files. A shared `_branch_changes` helper centralises
the exclusion logic and removes both gaps.

## Scope

In:
- `plugins/sdlc/bin/aisdlc` — add `_branch_changes()` immediately before
  `run_scope_check()`; replace `run_scope_check()`'s bare `git diff --name-only` call with
  `_branch_changes`; remove the step-3 workaround block (8 lines); update `run_verify()`
  to call `_branch_changes` for its `changed` variable instead of the inline two-line
  pipeline, removing the duplicate exclusion logic.
- `evals/harness/selftest.sh` — update scope-pass, scope-gaps, scope-blocked, and
  scope-own-spec-dir test cases; add one direct unit-test section for `_branch_changes`
  covering own-specdir, root bookkeeping, sibling ticket, and custom specdir boundary cases.
- `docs/ai-sdlc.md` — append one sentence to the `scope-check` table row note (§ "The
  loop") documenting that `specs/<TICKET>/` artefacts and root bookkeeping files are
  automatically excluded from file classification.

Out:
- No changes to `_write_scope_report`, `_scope_bullets`, `_path_tokens`, `_context_lines`,
  `_size_stats`, or any other scope-check or size-budget helper.
- No changes to verdict logic (PASS/GAPS/BLOCKED rules).
- No changes to the size-budget or structure-check sections of `run_scope_check`.
- No changes to `run_verify`'s `deleted` variable, UC-coverage loop, or weakening checks.
- No changes to `docs/ai-sdlc.md` beyond the one appended sentence.

Change budget: 100 added lines, 3 files, 3 modules

## Context

- `plugins/sdlc/bin/aisdlc` — `_branch_changes()` contract:
  `_branch_changes <wt> <base> <task-specdir-relative>`
  where `task-specdir-relative` is the full ticket-specific path, e.g. `specs/SBX-1`.
  Stdout: newline-separated paths from `git diff --name-only "${base}...HEAD"`, excluding
  the literal ticket-directory prefix and exactly the root files `AGENTS.md`, `CLAUDE.md`,
  plus the `.claude/` subtree. Optional trailing git-diff options preserve caller filtering.
  Only the named task's spec directory is excluded; a sibling ticket's directory (e.g.
  `specs/SBX-2/`) and any real source file sharing the prefix remain visible.
- `plugins/sdlc/bin/aisdlc` — `run_scope_check()`: replace the line
  `changed="$(git -C "$wt" diff --name-only "${base}...HEAD" 2>/dev/null || true)"` with
  `changed="$(_branch_changes "$wt" "$base" "$specs_dir/$ticket")"`.
  Remove the entire step-3 block (`# 3. Pipeline artefacts…` through the closing
  `[ "$classified" -eq 1 ] && continue` — 8 lines total) as it is superseded.
- `plugins/sdlc/bin/aisdlc` — `run_verify()`: the `changed` variable is currently set by
  a two-line pipeline
  `git -C "$wt" diff --name-only --diff-filter=AMR "${base}...HEAD" 2>/dev/null
    | grep -v "^$specs_dir/$ticket/" | grep -vE '^(AGENTS\.md|CLAUDE\.md|\.claude/)' || true`.
  Replace with `_branch_changes "$wt" "$base" "$specs_dir/$ticket" --diff-filter=AMR`;
  preserve the verify caller's existing added/modified/renamed-file filter, while scope-check
  and the no-change guard use the unfiltered helper. Keep deletion checks unchanged.
  Update the preceding comment from "same rule as scope-check" to "via _branch_changes".
- `evals/harness/selftest.sh` — `fresh_repo_scope()` stub (ok mode) commits:
  `pkg/stub.go`, `pkg/stub_test.go`, `specs/SBX-1/qa-report.md`.
- `evals/harness/selftest.sh` — scope-pass case: currently declares `pkg/` and
  `specs/SBX-1/` in `In:`; after the fix `specs/SBX-1/` is redundant — change `In:` to
  `pkg/` only (one-line `in_section`); update the comment.
- `evals/harness/selftest.sh` — scope-gaps case: the existing assertions (GAPS verdict,
  `**undeclared**` present) are unchanged; add one negative assertion that the string
  `` `specs/SBX-1/qa-report.md` `` does not appear anywhere in `scope-report.md`;
  update the comment to reflect that the artefact is excluded, not merely reclassified.
- `evals/harness/selftest.sh` — scope-blocked case: currently uses
  `$'- \`specs/SBX-1/qa-report.md\`'` as the repo-wide OOB target; after the fix that
  path is excluded before the OOB check and can never trigger BLOCKED — change OOB to
  `$'- \`pkg/stub_test.go\`'` (a real committed file that is not in scope); update the
  comment accordingly.
- `evals/harness/selftest.sh` — scope-own-spec-dir case: logic unchanged; update ok/bad
  message strings from "in scope" to "excluded from diff" to reflect the new mechanism.
- `docs/ai-sdlc.md` — `aisdlc scope-check` row (§ "The loop" table): the cell currently
  reads `PASS/GAPS/BLOCKED — BLOCKED stops before ship`; append after it:
  `(specs/<TICKET>/, AGENTS.md, CLAUDE.md, .claude/ are never classified)`.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | scope-check | branch commits `pkg/stub.go`, `pkg/stub_test.go`, `specs/SBX-1/qa-report.md`; spec `In:` declares `pkg/` only | `scope_verdict` in task.json is PASS; `scope-report.md` contains no row for `specs/SBX-1/qa-report.md` (not undeclared, not in-scope) | unit |
| UC-2 | scope-check | same branch; spec `In:` declares `pkg/stub.go` only | `scope_verdict` is GAPS; `scope-report.md` marks `pkg/stub_test.go` as `**undeclared**`; the backtick-quoted string `` `specs/SBX-1/qa-report.md` `` does not appear anywhere in the report | unit |
| UC-3 | scope-check | branch commits `pkg/stub.go`, `pkg/stub_test.go`; repo OOB list contains `` `pkg/stub_test.go` ``; spec `In:` declares `pkg/stub.go` only | `scope_verdict` is BLOCKED; `scope-report.md` marks `pkg/stub_test.go` as `**out of bounds**`; ship phase does not run; task status is `failed` | unit |
| UC-4 | `_branch_changes` | sourced from aisdlc; worktree diff contains `pkg/stub.go`, `specs/SBX-1/qa-report.md`, `specs/SBX-2/spec.md`, `AGENTS.md`; called with third arg `specs/SBX-1` | stdout contains `pkg/stub.go` and `specs/SBX-2/spec.md`; stdout does not contain `specs/SBX-1/qa-report.md` or `AGENTS.md` | unit |

## Non-functional

None.

## Open questions

None.
