---
ticket: SDLC-006-a
title: Post-PR loop I — review engine, autofix, CI stabilisation, autopilot
status: draft
stacks: [instructions, runner]
---

# SDLC-006-a — Post-PR loop I: review, fix-pr, autopilot

## Problem

A draft PR with a `PASS` verdict is where the pipeline stops and a human starts. Review is the
scarce resource (`docs/ai-sdlc.md` § "The shift"), yet nothing reviews the agent's own PR before a
person does, nothing resolves a conflict or a red check, and a `changes-requested` review is a dead
end until someone reopens the worktree by hand. The result is that reviewer attention goes on
mechanical findings the harness could have caught.

## Scope

In:
- `/sdlc:review <pr#> [--autofix] [--force]`: claim, isolated worktree, `code-reviewer` agent,
  severity-ranked findings, verdict submitted through the descriptor, pipeline label set, autofix
  loop on eligible PRs.
- `/sdlc:fix-pr <pr#> [--ci-only]`: base merge → review+autofix → CI stabilisation loop until
  `merge-ready`; never merges.
- `/sdlc:review-prs`: sweep of unreviewed open PRs carrying the profile label.
- `/sdlc:autopilot <pr#> [--allow-merge] [--dry-run]`: diagnose, dispatch, re-diagnose.
- `agents/code-reviewer.md` and `skills/code-review/SKILL.md` (severity scale, verdict rule,
  checklist, spec-review lenses).
- Queue `review` phase wiring to `/sdlc:review` (phase itself lands in SDLC-005).

Out:
- Merging, `continue`, follow-up issues, changelog, close-fixed sweep — SDLC-006-b.
- Any label beyond the five from SDLC-005; no priority/risk inference.
- Reviewing another author's PR *and* pushing to it without `--autofix`.
- A second review engine: `slop-guard` findings are consumed as input when its report exists,
  never re-implemented.

## Context

- `specs/SDLC-005/spec.md` — descriptor operations `get-pr get-pr-diff get-pr-checks
  get-run-failed-logs checkout-pr review-pr comment-pr label-pr unlabel-pr claim release
  check-claim current-user`; verdict tokens; chain markers.
- `plugins/sdlc/commands/qa.md` and `agents/auto-qa.md` — the spec-first reading order the
  reviewer copies: spec, then diff.
- `plugins/sdlc/skills/dense-testing/SKILL.md` § "Density floors", § "Non-negotiable" — floors the
  reviewer checks; weakened test = blocker.
- `plugins/sdlc/hooks/guard` — the reviewer's autofix never bypasses it.
- `plugins/slop-guard/` — when `.aisdlc/slop-guard/report.json` (or its configured path) exists in
  the worktree, its blockers are imported as findings.
- `docs/ai-sdlc.md` § "Definition of done for a queued task" — the review checklist's first six
  rows are these bullets.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | reviewer agent | `/sdlc:review <pr#>` on a PR whose diff deletes a test or touches a path in the spec's `Out:` | review submitted `CHANGES_REQUESTED`; the finding is tagged `blocker` and quotes `file:line`; pipeline label is `changes-requested`; report's last line is `PR: #<n> (<url>)` preceded by `Verdict: CHANGES_REQUESTED` | e2e |
| UC-2 | reviewer agent | `/sdlc:review <pr#>` on a PR with only `minor`/`nit` findings | review submitted `APPROVED`, findings listed in the body; label `merge-ready`; `Verdict: APPROVED` | e2e |
| UC-3 | reviewer agent | `/sdlc:review <pr#>` where the PR author is `current-user` (or `--autofix`) and blockers exist | fixes committed in the isolated worktree in the order conflicts → findings → CI, pushed as new commits (no force-push), re-review runs, loop ends at `APPROVED` or a `⚠ NEEDS HUMAN` finding; without eligibility the report says `autofix: skipped (not my PR)` and the branch is untouched | e2e |
| UC-4 | reviewer agent | `/sdlc:review` on a PR whose changed files are all under the specs dir | the specification review runs (risks, compatibility, gaps, improvements, simplicity) instead of the code checklist; autofix edits only the spec | e2e |
| UC-5 | developer | `/sdlc:fix-pr <pr#>` on a PR with a red required check | each failing check classified `real-bug | test-bug | flake | infra` in a PR comment; `real-bug` fixed with a test; `flake` re-run once before any code change; loop exits at `merge-ready` or a named blocker; `--ci-only` skips the review step | e2e |
| UC-6 | developer | `/sdlc:review-prs` | every open PR with the profile label and no review by `current-user` is reviewed newest-first; a PR with a live claim by another actor is skipped and listed as `claimed by <who>` | e2e |
| UC-7 | developer | `/sdlc:autopilot <pr#> --dry-run` | prints the diagnosed state (`unfinished-plan | unreviewed | changes-requested | red-ci | conflicted | merge-ready`) and the ordered command chain it would run; mutates nothing; without `--allow-merge` the chain never contains `/sdlc:merge` | e2e |
| UC-8 | queue | `aisdlc run` after `ship` | `review` phase runs `/sdlc:review <pr#> --autofix`; `aisdlc inbox` shows `Verdict` and pipeline label per PR; a `CHANGES_REQUESTED` that autofix could not clear marks the task `failed` with `error: review blockers remain` and keeps the worktree, while the PR itself stays open and labelled `changes-requested` | unit |

## Non-functional

- Verdict rule is verbatim from `skills/code-review/SKILL.md`: any `blocker` → request changes;
  any `major` without a documented waiver → request changes; only `minor`/`nit` → approve.
- Review is one complete pass: conflicts, red checks and inherited human comments become findings
  *inside* the review, never a reason to skip it.
- The reviewer reads the spec before the diff, as `auto-qa` does.
- CI stabilisation never weakens a check: no skip, no retry-until-green beyond one flake re-run,
  no lowered threshold — these are `guard`'s rules restated for CI.
- `make validate`, `make selftest`, `make eval-dry` stay green.

## Open questions

- [ ] none
