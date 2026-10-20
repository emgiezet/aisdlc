---
ticket: GH-39
title: "/sdlc:review --adversarial: independent second pass, commit-by-commit, stricter verdict wins"
status: approved
stacks: [instructions]
---

# GH-39 — /sdlc:review --adversarial

Source: https://github.com/emgiezet/aisdlc/issues/39

## Problem

`/sdlc:review` dispatches one `code-reviewer` agent and accepts its verdict. A single reviewer
shares the author's blind spots and may approve plausible code that degrades the codebase.
SlopCodeBench (arXiv 2603.24755) finds structural erosion in 77 % of agent trajectories; best-agent
checkpoint pass rate is 14.8 %. An independent adversarial pass with a different mandate
reduces that blind spot.

## Scope

In:
- `plugins/sdlc/commands/review.md` — `## Phase 1`: accept `--adversarial`; read
  ``- **review-adversarial:** `true` `` from the Markdown profile. `## Phase 5`: adversarial dispatch block and merge rule.
  `## Phase 7`: note that re-dispatch repeats both passes when active. `## Phase 9`: per-pass
  finding counts line when flag is active.
- `plugins/sdlc/agents/code-reviewer.md` — new `## Adversarial mode` section: mandate and
  commit-by-commit read order (`git log -p <base>..HEAD`) before aggregate diff.
- `plugins/sdlc/skills/agent-orchestration/references/debate.md` — one sentence under
  `## In this harness` linking the adversarial two-pass as an application of the
  proposer/sceptic shape.
- `plugins/sdlc/templates/sdlc.md` — add the literal bullet ``- **review-adversarial:** `false` ``
  with a short explanation; `true` enables the second pass. Use this one spelling throughout.
- `README.md` — update the `/sdlc:review` row: `[--autofix] [--adversarial]`.

Out:
- Running the two passes on different models.
- Changes to `/sdlc:fix-pr`, `/sdlc:review-prs`, or the queue.
- A new agent file; the adversarial mandate is a section in existing `code-reviewer.md`.
- Changes to the severity scale, verdict rule enum, or findings format beyond the `(adversarial)` tag.
- Prescribing concurrent vs. sequential dispatch (implementation choice; issue requires independence
  only — the adversarial pass must not see the first pass's findings).

Change budget: 75 added lines, 5 files, 2 modules

## Context

- `plugins/sdlc/commands/review.md` — `## Phase 1` `$ARGUMENTS` line; `## Phase 5` single
  `code-reviewer` dispatch block and scope-report import; `## Phase 7` re-dispatch sentence;
  `## Phase 9` `Findings:` line and the two C4 chain markers.
- `plugins/sdlc/agents/code-reviewer.md` — `## Order of work` step 4 (diff read the adversarial
  mode overrides with commit-by-commit read first); `## Output` section (verdict format the merge
  rule consumes).
- `plugins/sdlc/skills/agent-orchestration/references/debate.md` — `## In this harness` section
  (currently "No implementation here").
- `plugins/sdlc/templates/sdlc.md` — add the `**review-adversarial:**` bullet; absent/false keeps one pass.
- `README.md` — `/sdlc:review` row in the commands table.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | reviewer | runs `/sdlc:review <n> --adversarial`; both passes return `APPROVED` | merged verdict is `APPROVED`; Phase 9 report contains two `Pass N:` finding-count lines above the merged totals line | e2e |
| UC-2 | reviewer | runs `/sdlc:review <n> --adversarial`; first pass returns `APPROVED`, second (adversarial) returns `CHANGES_REQUESTED` | merged verdict is `CHANGES_REQUESTED`; adversarial-only findings carry `(adversarial)` tag in merged list | e2e |
| UC-3 | reviewer | runs `/sdlc:review <n> --adversarial`; first pass returns `CHANGES_REQUESTED`, second (adversarial) returns `APPROVED` | merged verdict is `CHANGES_REQUESTED` (stricter wins regardless of which pass holds it) | e2e |
| UC-4 | reviewer | runs `/sdlc:review <n> --adversarial`; same finding (identical file and line) produced by both passes | that finding appears exactly once in the merged list with no `(adversarial)` tag | e2e |
| UC-5 | adversarial `code-reviewer` | receives its independent dispatch | execution trace reads commit-by-commit history before aggregate diff; dispatch does not expose the other reviewer's findings or verdict | e2e |
| UC-6 | reviewer | runs `/sdlc:review <n>` without `--adversarial` and without profile key set | Phase 9 report has no `Pass N:` lines; format is identical to a pre-feature run on the same PR | e2e |
| UC-7 | repo maintainer | sets the literal profile bullet ``- **review-adversarial:** `true` ``, then runs `/sdlc:review <n>` without flags | behaves like UC-1/UC-2; Phase 9 includes per-pass counts | e2e |
| UC-8 | reviewer | runs `/sdlc:review <n> --adversarial` on a spec-only PR (all changed files under `specs/`) | [INFERENCE] spec-only review path is taken; `--adversarial` has no effect; Phase 9 format unchanged — **confirm with issue author before approving** | e2e |

## Non-functional

- `CI= make validate` passes after the change.

## Open questions

- [x] Skip the adversarial pass for spec-only PRs. UC-8's conservative inferred behavior is the selected implementation contract under the user's instruction to proceed.
