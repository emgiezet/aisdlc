# Open GitHub Issues Implementation Plan

> **For agentic workers:** Use issue-isolated implementation agents. The coordinator owns integration, all tests, formatting, and commits; workers skip gates and formatters.

**Goal:** Plan every open issue in `emgiezet/aisdlc`, implement approval-eligible work, and preserve explicit approval/dependency blockers.

**Architecture:** One planning agent per issue. Bug-labelled issues follow the triage approval contract; enhancement specs remain drafts until human approval. Implementation uses isolated checkouts because several issues touch the runner and selftest; only the coordinator integrates changes.

**Tech Stack:** Bash runner and regression harness, Markdown commands/specs, YAML slop-guard catalogue.

**Specs:** Per-issue `specs/GH-<n>/spec.md`; decomposed parents #42/#43 use `decomposition.md`. Existing approved `GH-42-a` and `GH-43-a` specs are preserved.

## Global Constraints

- No implementation of draft feature specs; bug approval must retain the live GitHub `bug` label and exact triage provenance.
- No changes to manifest versions, CI configuration, retired-test policy, or sandbox fixtures.
- Never weaken behavioral tests; issue/UC identifiers accompany regressions. Retire incidental source-wording checks rather than re-pinning them, and record the resulting verification limit.
- Never duplicate existing PR #61, which implements archive slice GH-43-b.
- No merge, issue closure, or approval mutation is implied by this plan.
- Current branch history is readable; `git log --all` fails on an unrelated corrupt ref `maximumtrasti/fix-agent-discipline-skill` (empty object `7a5b4333ad80335632e36d7a45b3c045a51df9b0`). Do not repair unrelated repository state.

## Full issue surface

| Issue | Required result | Planning owner | Execution gate / dependency |
|---|---|---|---|
| #38 | Open-PR and run-spend admission caps, defaults, stop reason in status, docs and stub cases | Issue38Plan | Enhancement approval and mixed stored-billing decision; shared runner/status surface |
| #39 | Independent adversarial review, commit-first reading, stricter merged verdict, tagged unique findings and per-pass counts | Issue39Plan | Enhancement spec approval; shared review command with #58 |
| #40 | Optional smol readiness score, threshold/force behavior, gap report, persisted score/status | Issue40Plan | Enhancement spec approval; shared add/check_spec surface with #53 |
| #41 | Bounded Mermaid change map, out-of-scope warnings, UC before/after table, docs-only omission | Issue41Plan | Enhancement spec approval |
| #42 | Complete the remaining mapped TypeScript rules and detection/reference examples | Issue42Plan | GH-42-a merged; b/c drafts need approval; external vendored sync needs its target-repo workflow |
| #43 | Session capture, archive/redaction, phase/model provenance, retained records, queries/pruning, cross-repo retro and opt-outs | Issue43Plan | Capture merged; PR #61 open; c/d/e/f drafts need approval and privacy/config decisions |
| #50 | Exclude uv.lock from review-size counts | Issue50Plan | Bug-labelled triage approval |
| #51 | Shared branch-change filter; harness reports/config excluded from scope classification | Issue51Plan | Bug-labelled triage approval; produces helper consumed by #52 |
| #52 | Fail empty/report-only implementation immediately; no QA invocation; diagnostic points to implement.json | Issue52Plan | Bug-labelled triage approval; integrate #51 first |
| #53 | Check depends-on evidence at add and runtime; force cannot bypass runtime; name only unmet dependencies | Issue53Plan | Bug-labelled triage approval |
| #54 | Exact In file overrides spec Out mention; directories/globs/Context do not; repo prohibitions still win | Issue54Plan | Bug-labelled triage approval |
| #58 | Code-review autofix treats approved spec as read-only; remove dispensable scope gaps or stop for human; spec-only review unchanged | Issue58Plan | Bug-labelled triage approval |
| #59 | Repo-only tolerance on soft budgets, report effective limit, unchanged hard ceiling, consistent implementation guidance | Issue59Plan | Enhancement spec approval; shared size accounting with #50 |
| #60 | Link task-local tracker to canonical repo tracker; local ship records survive clean | Issue60Plan | Bug-labelled triage approval |

## Ordered execution

1. Retrieve every open issue and comments, current spec status, default-branch fix history, and open PRs. Dispatch fourteen independent planning agents with disjoint spec ownership.
2. Review all generated spec acceptance tables against the source issues. Reject invented approvals, missing requirements, oversized unsplit work, and duplication of delivered/open work.
3. Implement #50, #51, #53, #54, and #60 in independent checkouts. Each agent writes behavioral regression cases and minimal production/doc changes, without running gates or committing.
4. Coordinator integrates those changes and runs shell syntax/static checks, plugin suites, `make selftest`, and `CI= make validate`. Exercise changed runner paths through the real CLI with isolated stub repositories. A red gate blocks the next phase.
5. Implement #52 against the verified #51 helper contract, concurrently with #58's independent review-command change. Verify their regression/smoke paths and the combined tree.
6. Run the final full gate matrix, record per-issue evidence and any concrete approval blockers, and commit focused green changes as required by the repository workflow. Leave draft feature specs for human approval; do not queue them forcibly.

## Verification ownership

The coordinator runs every gate once per integrated phase. No language server is configured; shell syntax/static tooling and executable tests provide diagnostics. Paid model evals require separate authorization and are not assumed by this plan. Instruction-only changes require a scenario check of the actual command contract plus `make eval-dry`; absence of a paid live-agent run must be reported rather than called proven runtime compliance.

## Execution result

All fourteen issues received separate planning agents. Seven bug-labelled issues received
separate implementation agents, with coordinator-owned integration and verification.

- `2823947` — #50, #51, #53, #54, #60: lockfile sizing, shared classification exclusions,
  prerequisites, exact-In precedence, and canonical local tracker storage.
- `5c7781b` — #52, #58: immediate empty-implementation rejection and immutable approved specs
  during code-review autofix, including safe restoration of pre-existing files.
- Per-issue `verify-report.md` files record observed UC evidence and verification limits.
- No PR was opened, no branch was merged or pushed, and no GitHub issue was closed.
  The existing `emgiezet/next-issues` workspace is preserved.

| Check | Final observed result |
|---|---|
| `make selftest` | 233 passed, 0 failed |
| `CI= make validate` | Local validation passed; PHPStan/Psalm unavailable |
| `make eval-dry` | All 13 trigger sets passed |
| Changed shell syntax / Docker ShellCheck | Exit 0 |
| GH-58 live local-provider instruction scenarios | Seven distinct cases passed coordinator checks |
| Draft/approval schema and archive UC ownership | 11 drafts, seven approved bugs; archive UC-1–42 each owned once |

The final review caught and corrected a bookkeeping-only size-gate bypass, a vacuous
markdown-only structure assertion, and unsafe deletion wording for pre-existing files.
Four GH-44 UC-8 token-presence checks were retired; they did not prove import behavior.
That criterion has no automated behavioral proof in this handoff. Its prior QA report
is intentionally retained as historical evidence, not a current coverage assertion.
No paid Claude/omp or Haiku/Sonnet evaluation matrix was run; live instruction exercises
covered bounded Phase 7 behavior, not the complete hosted GitHub review loop.
The additional default `make validate` invocation reached strict mode and failed solely
because PHPStan/Psalm were absent (23 configs validated, two skipped, zero failed).
Local-mode validation passed afterward; Docker ShellCheck separately covered the changed
shell files. No claim of a complete strict-CI tool matrix is made.

## Initial human approval queue (historical)

These features are planned, not implemented:

| Issue | Draft contract / unresolved decision |
|---|---|
| #38 | `specs/GH-38/spec.md`; mixed stored API/subscription billing needs a cap-policy decision |
| #39 | `specs/GH-39/spec.md`; adversarial handling of spec-only PRs needs a decision |
| #40 | `specs/GH-40/spec.md`; default-off, config-only readiness gate awaits approval |
| #41 | `specs/GH-41/spec.md`; bounded aggregation above 12 modules needs a decision |
| #42 | `specs/GH-42/decomposition.md`, GH-42-b/c; approve remaining rules and establish the external trasti-sdlc vendored-sync workflow |
| #43 | `specs/GH-43/decomposition.md`, GH-43-c/d/e/f; scanner/profile/no-I/O questions and PR #61 prerequisite remain |
| #59 | `specs/GH-59/spec.md`; repository-only budget tolerance awaits approval |

PR #61 was refreshed at handoff: OPEN, merge state DIRTY. It was neither duplicated nor
modified. Its append-only attempt-path concern is a static-review inference recorded in
the decomposition, not a reproduced or repaired defect claimed by this implementation.

## Approved continuation

The user instructed “ok jazda robić”, approving continuation of the remaining feature plans.
Selected conservative decisions are recorded in GH-38 (run-wide mixed-billing cap),
GH-39 (skip adversarial on spec-only PRs), and GH-41 (bounded aggregation without losing
out-of-scope warnings). Their specs, GH-40, GH-42-b/c, GH-43-d/e/f, and GH-59 are approved.
The user separately approved GH-43-c's installed-v2-only, network-disabled, whole-archive
fail-closed scanner contract, profile/config opt-outs, and 600-line / seven-file / three-module
budget correction for complete wiring. All remaining feature contracts are now approved.

The user then prioritized resolving PR #61 and authorized merge after safe verification.
After explicit approval of its 800-line / five-file / four-module repair budget, PR #61
was fixed and merged as `4825bc73fb807781ae212e0002d9bcbd69bdcb30`. Verification: 226 runner
checks, local validation, ShellCheck, trigger sets, independent code/security approval,
and both hosted CI jobs passed. The append-only concern was reproduced and repaired;
the earlier prerequisite-risk note is superseded.

The original checkout's unrelated corrupt Git object prevents fetching. Execution therefore
continues in a healthy clone, preserving the original issue commits via a Git bundle and
merging the new main into their history. No unrelated ref or user worktree is repaired.
The coordinator remains the sole integration owner; each remaining issue receives an
isolated implementation agent, and overlapping runner/command edits are combined centrally.

The combined prerequisite baseline passed 282 runner checks, 721 slop-guard checks and
75 SDLC checks (`make selftest`, `CI= make validate`). Two new regression assertions first
failed for missing archives on empty implementations and local-tracker link failures.
Both now pass. Separate CLI retry/run smokes also observed failed task records, retained
worktrees, and corresponding failed archive manifests/index entries for both paths.

## Continuation budget approval

After integration exposed missing boundary/concurrency coverage, the user selected
“Zatwierdź szersze budżety”. Functional scope and verification gates remain unchanged;
the following corrected limits are now reflected in the approved specs:

| Spec | Added lines | Files | Modules |
|---|---:|---:|---:|
| GH-38 | 350 | 6 | 3 |
| GH-40 | 400 | 8 | 3 |
| GH-59 | 200 | 4 | 1 |
| GH-43-d | 500 | 3 | 3 |
| GH-43-f | 300 | 3 | 3 |

## Local review prerequisite approval

Live descriptor probes returned an empty diff at the PR head and `MERGEABLE` for a
real base/head add/add conflict. The user selected “Napraw w ramach #39”: include
`templates/trackers/local.md`, keeping the 75-line/2-module limit and widening the
file limit from 5 to 6. GH-39 now includes the stored-base comparison regression.

## TypeScript detector corrections

The real pinned-tool suite showed two approved premises were wrong. The user selected
“Popraw UC-1 do realnego detektora”: `anti-slop/no-reduce-accumulator-copy` 0.3.0 reports
`Object.assign`/`Array.from`/array-copy accumulators and explicitly leaves spread copies to
oxc, so GH-42-c UC-1 uses `Object.assign`. The user also selected “Tak, popraw fixture’y w
GH-42-b”: GH-42-a's two good fixtures declared `unknown`-returning functions, which GH-42-b's
`no-unknown-returns` correctly reports; they now declare an `unknown` boundary value, raising
GH-42-b's file limit from 12 to 14.

## Line-limit increase

Measured after repairs: GH-43-f 444 added lines (approved 300), GH-38 362 (approved 350).
The user answered “limity trzeba podnieść do 4000”: both specs now allow 4000 added lines,
with file and module limits unchanged. The profile hard ceiling (3000) still applies to scope-check.

