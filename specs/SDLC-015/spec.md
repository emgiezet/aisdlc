---
ticket: SDLC-015
title: Workflow profiles select phases and ceremony together
status: draft
stacks: [bash, instructions]
---

# SDLC-015 — Workflow profiles select phases and ceremony together

## Problem

The queue has one default phase chain for spec work and one for issue work. Maintainers can
select a subset of phases, but that choice does not select a review class, QA depth, budget,
or the applicability of mockup and architecture review. A shorter run can therefore mean less
ceremony only by convention, and the person inspecting the task cannot see one coherent policy.

## Scope

In:
- Named workflow profiles select an ordered phase chain and its ceremony: review class, QA
  depth, change budget, and whether mockup and architecture review apply.
- Resolve the selected profile before queueing and record its effective phases and ceremony
  with the task, so a later config edit cannot silently change a queued run.
- Carry the resolved ceremony to the existing command/agent boundaries that consume it.
- With no profile selected, preserve today's spec and issue chains and ceremony defaults.
- Document selection and precedence, including interaction with explicit phase overrides,
  issue entry, `--no-pr`, and per-spec change budgets, after those decisions are resolved.

Out:
- Replacing the bash queue with a compiled workflow graph or importing another methodology.
- Copying an external profile catalogue wholesale or adding swarm/worktree-per-unit machinery.
- Making profiles an alternative to a human-approved spec, changing the retired-test fence,
  or allowing a profile to bypass a mandatory gate merely by naming it differently.
- Changing review severity names, findings-ledger arithmetic, or the merge label gate.

Change budget: 380 added lines, 12 files, 6 modules

## Context

- `plugins/sdlc/bin/aisdlc` — `ALL_PHASES`, `ISSUE_PHASES`, and `cmd_add`'s
  `--phase|--phases` handling; `cmd_help` documents the phase escape hatch.
- `plugins/sdlc/templates/sdlc.md` — `## Change budget` and its per-spec override rule.
- `plugins/sdlc/commands/qa.md` — Phase 1 independent verification and Phase 3 report.
- `plugins/sdlc/commands/review.md` — Phase 5 review dispatch and Phase 6 verdict + labels.
- `plugins/sdlc/commands/mockup.md` — Phase 1 UI-surface extraction and Phase 2 mockup output.
- `plugins/sdlc/commands/arch-review.md` — Phase 1 document lookup and Phase 2 targets gate.
- `plugins/sdlc/commands/implement.md` — implementation entry point consuming the spec.
- `evals/harness/selftest.sh` — queue/stub fixtures for effective task configuration.
- `docs/ai-sdlc.md` — queue configuration and user-facing workflow documentation.
- External models, paths relative to the read-only comparison clone: `bugfix` declares
  Minimal depth, skeleton off, advisory review cap, and its guard/sensor/learning/confirmation/
  approval/collaborator settings (`core/scopes/aidlc-bugfix.md:2-20`); `feature` declares
  Standard depth, skeleton on, and its ceremony toggles (`core/scopes/aidlc-feature.md:2-13`).
  The latter explains that Standard changes ceremony depth while retaining the full lifecycle
  (`core/scopes/aidlc-feature.md:18-21`). These are examples of coupled policy, not fields
  every local profile must copy; notably the feature frontmatter does not explicitly declare
  `review_cap` (`core/scopes/aidlc-feature.md:2-14`).

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | maintainer | queues a spec task without selecting a workflow profile | task phases remain `implement qa scope-check verify ship review`; current ceremony defaults remain effective | selftest |
| UC-2 | maintainer | queues an issue task without selecting a workflow profile | task phases remain `triage root-cause implement qa scope-check verify ship review` | selftest |
| UC-3 | maintainer | queues a task with a valid named profile | stored task data identifies the profile and contains its resolved ordered phases, review class, QA depth, change budget, and mockup/architecture-review applicability | selftest |
| UC-4 | maintainer | selects an unknown profile or a profile with an invalid phase/value | queueing exits non-zero, names the offending profile and field, and leaves the queue unchanged without a model invocation | selftest |
| UC-5 | queue runner | starts a previously queued task after the selected profile's source definition is edited | the run uses the effective profile recorded by UC-3 rather than silently adopting the new definition | selftest |
| UC-6 | queue runner | runs a selected profile through QA and review | the QA dispatch carries the resolved QA depth and the review dispatch carries the resolved review class; their reports identify the effective setting | integration |
| UC-7 | queue runner | scope-checks a task whose diff exceeds its effective profile budget and has no spec budget override | the scope report names the effective profile limit and reports the breach through the existing budget mechanism | selftest |
| UC-8 | queue runner | prepares a task using profiles with mockup and architecture-review applicability enabled or disabled | the effective workflow visibly includes each applicable preparation step, or records it as not applicable; disabled steps do not invoke their commands — one fixture per toggle | integration |

`test` = the lowest tier that can observe the result: `selftest` | `unit` | `integration`.

## Open questions

- [ ] Where do named definitions live, how is a profile selected, and which names ship by
  default? Choose repo-config versus profile-document ownership and an explicit selection
  interface; do not infer a profile from issue prose or invent a CLI flag during implementation.
- [ ] What are the allowed review classes and QA depths, and which concrete checklist/test
  obligations does each select? A label passed in a prompt is not an operational policy.
- [ ] What is the precedence of an explicit `--phase/--phases` list versus a named chain,
  and how do `--issue` and `--no-pr` constrain it? Decide whether conflicts reject or override;
  an explicit phase subset must not silently erase the selected ceremony.
- [ ] Does a per-spec `Change budget:` always win over the profile, as it does over today's
  defaults, or is a profile a cap? Resolve this alongside repo hard ceilings before approval.
- [ ] Where do mockup and architecture review run relative to human spec approval and the
  queue's implementation phase? Define required inputs, skip/not-applicable results, and
  unattended handling when architecture review needs a human answer. UC-8 is not permission
  to fabricate an architecture document or silently skip a required preparation step.
- [ ] What happens to existing queued tasks without a recorded effective profile, and how
  should resumed tasks expose that they are using the legacy defaults?
