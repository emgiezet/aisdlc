---
ticket: GH-58
title: "review autofix edits the approved spec to close a scope gap"
kind: bugfix
status: approved
approved-by: issue #58 (label bug, @emgiezet)
stacks: [instructions]
---

# GH-58 — review autofix edits the approved spec to close a scope gap

Source: https://github.com/emgiezet/aisdlc/issues/58

## Problem

Phase 7 autofix in `/sdlc:review` silently fixes scope-gap `[major]` findings by editing the
approved `specs/<TICKET>/spec.md` to declare the undeclared file, rewriting the one artefact a
human approved without any human decision.

## Scope

In:
- `plugins/sdlc/commands/review.md` Phase 7 Findings step: narrow the "address every `blocker`
  and `major`" rule so that during a **code review** the approved `specs/<TICKET>/spec.md` is
  never written by autofix.
- For `[major] scope gap: <file> (not declared in spec)` during a code review:
  - If the file is not needed by the deliverable: remove it from the branch; the finding resolves
    without touching the spec.
  - If the file must remain: emit `⚠ NEEDS HUMAN: scope gap: <file> — widen the spec or waive`
    and invoke the existing NEEDS HUMAN stop path (unlabel, label `blocked`).
- For every change-budget finding during a code review (`[major] over change budget:`,
  `[blocker] over change budget:`, including the hard-ceiling breach): emit
  `⚠ NEEDS HUMAN: <finding text> — widen the spec or waive` and invoke the NEEDS HUMAN stop path.
- **Spec-only reviews** (every diff file under `specs/`): autofix may still edit the spec as
  before; the read-only constraint applies only to code reviews.
- `docs/ai-sdlc.md` loop table row for `/sdlc:review`: append that the approved spec is
  read-only to autofix during code review; scope-gap and change-budget findings that cannot be
  resolved without widening the spec escalate as `⚠ NEEDS HUMAN`.

Out:
- Mechanical enforcement (hook or pre-write guard denying writes to `specs/*/spec.md` during
  review): prose rule only, as the rest of Phase 7 is.
- Any change to Phase 1–6, Phase 8–9, or the spec-only review path.
- Changes to `plugins/sdlc/commands/spec.md`, `triage.md`, or any other playbook.
- Autofix behaviour for findings other than scope-gap and change-budget (e.g. real code bugs,
  conflicts, structural erosion, flaky tests): unchanged.
- The `[blocker] scope-check BLOCKED` import rule itself (Phase 5); this spec only changes
  Phase 7 handling of that finding class.

Change budget: 25 added lines, 2 files, 2 modules

## Context

- `plugins/sdlc/commands/review.md` — Phase 7 Findings step: `"address every blocker and major
  from Phase 5"` is the over-broad rule this fix narrows.
- `plugins/sdlc/commands/review.md` — Phase 5 `scope-report.md` import block: source of
  `[major] scope gap:`, `[major] over change budget:`, `[blocker] over change budget:`, and
  `[blocker] scope-check BLOCKED` findings (hard ceiling = 3000 added lines).
- `plugins/sdlc/commands/review.md` — Phase 7 `Stop immediately on ⚠ NEEDS HUMAN` paragraph:
  the existing stop sequence (unlabel `review`, `merge-ready`, `changes-requested`; label
  `blocked`; do not loop further) — reused verbatim; no new control flow.
- `plugins/sdlc/commands/review.md` — Phase 5 `Determine scope` step: distinguishes spec-only
  review from code review; the new restriction applies only to code review.
- `docs/ai-sdlc.md` — loop table, `/sdlc:review` row: `APPROVED → merge-ready, or
  CHANGES_REQUESTED and an autofix loop` — the minimal update target.
- Evidence: commit `48f8acb` — autofix added `tests/__init__.py` to `Context New:` in the
  approved spec, then marked the scope-gap finding `Resolved by autofix: declared in spec ✓`.
- Vocabulary: `pipeline-contracts`.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | autofix | code review autofix encounters `[major] scope gap: tests/__init__.py` and the file is extraneous (not needed by the deliverable) | autofix deletes `tests/__init__.py` from the branch; `specs/<TICKET>/spec.md` is unmodified; on re-review the scope-gap finding is absent | eval |
| UC-2 | autofix | code review autofix encounters `[major] scope gap: tests/__init__.py` and the file must remain | autofix emits `⚠ NEEDS HUMAN: scope gap: tests/__init__.py — widen the spec or waive`; PR is unlabelled from `review`/`merge-ready`/`changes-requested` and labelled `blocked`; autofix stops; `specs/<TICKET>/spec.md` is unmodified | eval |
| UC-3 | autofix | code review autofix encounters `[major] over change budget: added lines (450 vs 400)` | autofix emits `⚠ NEEDS HUMAN: over change budget: added lines (450 vs 400) — widen the spec or waive`; PR labelled `blocked`; autofix stops without editing `specs/<TICKET>/spec.md` | eval |
| UC-4 | autofix | code review autofix encounters `[blocker] over change budget: added lines (3500 vs 3000 hard ceiling)` | autofix emits `⚠ NEEDS HUMAN: over change budget: added lines (3500 vs 3000 hard ceiling) — widen the spec or waive`; PR labelled `blocked`; autofix stops | eval |
| UC-5 | autofix | spec-only review (all diff files under `specs/`) with a scope or wording gap found in the spec | autofix edits the spec directly; no `⚠ NEEDS HUMAN` emitted; PR not labelled `blocked`; behaviour is unchanged from pre-fix | eval |
| UC-6 | autofix | code review autofix run that hit UC-2 stop | `specs/<TICKET>/spec.md` byte-content is identical to its content at Phase 1 entry (no spec edit at any point in the loop) | eval |

## Non-functional

- The `⚠ NEEDS HUMAN` token and the stop sequence are identical to those already defined in
  Phase 7 for the `infra` CI-failure path; no new control-flow branch is introduced.
- Finding text in the NEEDS HUMAN message reproduces the exact finding string from Phase 5 output.
- **Verification limitation:** the `instructions` stack has no stub test that proves an LLM
  follows prose at runtime. `CI= make validate` and `make eval-dry` verify command syntax and
  scenario structure only. The `eval` test type above indicates harness-eval scenarios; parent
  will scenario-check the changed contract with a live agent and report the live-agent result
  separately. This spec does not assert mechanical proof of prose compliance.

## Open questions

none
