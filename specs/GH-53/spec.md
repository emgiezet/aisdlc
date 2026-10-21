---
ticket: GH-53
title: "aisdlc: depends-on in a spec is ignored; dependent slice runs on a base without its prerequisite"
kind: bugfix
status: approved
approved-by: issue #53 (label bug, @emgiezet)
stacks: [bash, instructions]
---

# GH-53 — depends-on in a spec is ignored

Source: https://github.com/emgiezet/aisdlc/issues/53

## Problem

`/sdlc:decompose` writes `depends-on: <DEP>` into slice specs, but `check_spec` does not read
it. A dependent slice queued before its prerequisite merges branches off a base that lacks the
prerequisite's code; every phase runs and fails, burning budget for nothing.

## Scope

In:
- `check_spec` in `plugins/sdlc/bin/aisdlc` gains a new `check_depends_on` helper called
  from inside `check_spec`. It reads the `depends-on:` frontmatter field via
  `spec_frontmatter_field`, derives the specs root as `dirname(dirname(spec))`, and for each
  space-separated token checks whether `<specs-root>/<DEP>/verify-report.md` exists with
  `PASS` as its first line. The file exists in the base tree only after the dependency branch
  merges; a dependency that is queued, running, or has an open PR does not count because its
  verify-report is not yet in the selected base. Any unmet token is collected; `check_spec`
  returns the list as the refusal reason.
- Every existing `check_spec` callsite in `run_task` (non-issue gate before the phase loop;
  issue gate before `implement`) and in `cmd_add` (non-issue spec gate) fires the new check
  without change to call signatures.
- At `add` time the check is bypassable with `--force` (same as today's status/label checks).
  The run-time gate inside `run_task` is not bypassable and sets status `refused`.
- The refusal message names only the unmet dependency tokens.
- `--force` description in `cmd_help` notes that the run-time depends-on gate is not bypassed.
- `## Phase 2: Write the slices` in `plugins/sdlc/commands/decompose.md` gains a sentence
  noting that `depends-on` is enforced by `check_spec` at queue and run time.
- `## Failure modes` table in `docs/ai-sdlc.md` gains a row for the dependency refusal
  symptom, and a `Limitation` note for dependencies implemented outside the pipeline (no
  verify-report → remove `depends-on:` from the spec).
- `evals/harness/selftest.sh` gains five regression cases covering UC-1 through UC-5.
- No new `.aisdlc/config.json` keys; no changes to `init_state`, profile templates, or
  the `/sdlc:update` command.

Out:
- `depends-on` in YAML list syntax or multi-line formats; only single space-separated line.
- Cycle detection or transitive chains beyond the directly listed tokens.
- Any change to `run_scope_check`, `run_verify`, or phase ordering.
- `plugins/sdlc/tests/` suites; the five cases land in `evals/harness/selftest.sh` only.

Change budget: 140 added lines, 4 files, 3 modules

## Context

- `plugins/sdlc/bin/aisdlc` — `spec_frontmatter_field`: already parses any frontmatter key
  from the `---` block by matching `<key>:` at column 1; reuse to read `depends-on:`.
  `check_spec`: current checks are `spec_status`, C6 bugfix-label validation via
  `spec_frontmatter_field("kind")` + `issue_has_label`, and `spec_open_questions`; the new
  `check_depends_on` call slots after the status/label block and before `spec_open_questions`.
  `cmd_add` non-issue branch: calls `check_spec "$spec" "$repo"`; existing `--force` flag
  already gates on the return value, prints WARNING, and continues. `run_task`: two
  `check_spec` callsites — one for non-issue tasks before the phase loop, one for issue tasks
  before `implement`; both already set status `refused` on non-zero return.
- `run_verify`: commits `specs/<TICKET>/verify-report.md` with first line `PASS` or `FAIL`
  inside the worktree; the file reaches the base tree only after the branch merges. A dep
  that is still queued, running, or open as a PR has not merged, so its verify-report is
  absent from the base — the file check naturally enforces the "landed in the base" requirement
  without any queue-state query.
- `plugins/sdlc/commands/decompose.md` — `## Phase 2: Write the slices`: documents writing
  `depends-on: <TICKET>-a` into dependent slice frontmatter; no enforcement note today.
- `docs/ai-sdlc.md` — `## Failure modes` table: rows cover spec/test/model/cost failure modes;
  the dependency-refused symptom and the outside-pipeline limitation are not mentioned.
- `evals/harness/selftest.sh` — `fresh_repo` helper and bugfix-gate block: model for new
  cases (create fixture repo, write spec with custom frontmatter via heredoc, optionally plant
  a verify-report, call `add` or `add --force` + `run --once`, assert exit code and
  `task_field` values).

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | `aisdlc add` | spec has `depends-on: DEP-a`; `specs/DEP-a/verify-report.md` absent from tree | `add` exits non-zero; output contains `DEP-a` | regression |
| UC-2 | `aisdlc add --force` then `aisdlc run --once` | same unmet dep as UC-1 | `add` exits 0 with `WARNING` in output; after run `task_field .status` is `refused`; `task_field .error` contains `DEP-a`; no `implement.log` in the task dir | regression |
| UC-3 | `aisdlc add` | spec has `depends-on: DEP-a`; `specs/DEP-a/verify-report.md` exists but first line is `FAIL` | `add` exits non-zero; output contains `DEP-a` | regression |
| UC-4 | `aisdlc add` | spec has `depends-on: DEP-a DEP-b`; `specs/DEP-a/verify-report.md` first line `PASS`; `specs/DEP-b/verify-report.md` absent | `add` exits non-zero; output contains `DEP-b`; output does not contain `DEP-a` | regression |
| UC-5 | `aisdlc add` then `aisdlc run --once` | spec has `depends-on: DEP-a`; `specs/DEP-a/verify-report.md` first line `PASS` committed to base | `add` exits 0; after run `task_field .status` is `done`; `implement.log` present in task dir | regression |

## Non-functional

- `check_depends_on` reads at most one `head -1` per listed token; no git subprocess.
- Spec with no `depends-on:` field (or empty value after trimming) passes through unchanged.
- Refusal message is plain ASCII, no colour codes, consistent with existing `check_spec` output.
- `refused` status set by the run-time path is identical to the existing spec-gate refusal paths
  in `run_task`, keeping `aisdlc status` output format unchanged.
- Limitation: a dependency implemented outside the pipeline has no verify-report; such a spec
  must have its `depends-on:` field removed before it can be queued.

## Open questions

none
