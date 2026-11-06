# Research: AWS AI-DLC Mechanisms Worth Adopting

**Date:** 2026-11-06  
**Scope:** `awslabs/aidlc-workflows` compared with `plugins/sdlc` and our harness evals; selective adoption, not a methodology migration

AWS source citations below are relative to the read-only `aidlc-workflows` clone.
Our implementation pointers are relative to this repository. The ledger path was exercised once
end to end: a headless `/sdlc:review` (omp, Sonnet) on a local-tracker scratch PR found two
blockers, autofixed them, and the incremental re-review resolved both through `add --since`.

---

## 1. What AWS Built

AWS AI-DLC is a TypeScript engine that emits exactly one validated directive at a time
(`core/tools/aidlc-orchestrate.ts:1539-1542`), against a compiled stage graph whose authored
protocol specifies inputs, outputs and dependencies
(`core/aidlc-common/protocols/stage-definition.md:44-72,179-187`); its published lifecycle
contains 33 stages (`docs/guide/00-introduction.md:27-30,49-50`). Our shape is deliberately
different: markdown commands in `plugins/sdlc/commands/` and a bash queue in
`plugins/sdlc/bin/aisdlc` (`ALL_PHASES`, `ISSUE_PHASES`, `run_phase`), with deterministic
`run_scope_check` and `run_verify` gates. We adopted four mechanisms that strengthen that
shape rather than importing another orchestration engine.

---

## 2. What We Took

### 2.1 Approval integrity

**AWS mechanism.** Approval is a recorded event tied to evidence, not merely prose:
`GATE_APPROVED` records verification identity, approved evidence, fingerprints, command
hash and the human's input (`core/tools/aidlc-construction-checkpoints.ts:1844-1853`;
receipt fields at `core/tools/aidlc-construction-checkpoints.ts:1693-1705`).

**Our implementation.** Two fences protect the spec signature:

| Pointer | Responsibility |
|---|---|
| `plugins/sdlc/hooks/guard` — `written_rel_path`, `spec_approval_fence` | Resolve the written path and deny an agent write granting `status: approved` without an `approved-by:` line in the same written text. |
| `plugins/sdlc/bin/aisdlc` — `run_verify` | Fail the `spec approval` row when the branch changes `status:` or `approved-by:` in a spec present at base. |
| `plugins/sdlc/extensions/omp.mjs` — `writeTargets`, `buildWritePayload` | Carry written text into the guard on that host. |
| `plugins/sdlc/templates/sdlc.md` — Spec approval | Explain the human signature, fences and bug-triage exception. |

**Deliberate difference.** This is not an evidence-fingerprinted approval receipt system.
The write fence permits the `approved-by:` shape; `check_spec` in
`plugins/sdlc/bin/aisdlc` rechecks the issue's `bug` label for the triage exception.
The verify row is `n/a` when the spec did not exist at base, because seeding a new spec is
legitimate. Neither fence should be described as cryptographic proof of human authorship.

### 2.2 Persistent findings ledger and incremental re-review

**AWS mechanism.** A bot-owned ledger comment carries stable finding IDs, statuses and
line-hash anchors; only comments from `github-actions[bot]` are eligible
(`.github/scripts/ai-pr-ledger.ts:508-511,1241-1267`). Anchors hash line bytes after dropping
a trailing CR (`.github/scripts/ai-pr-ledger.ts:190-203`). Re-review intersects the changes
since the previous reviewed head with the whole PR diff; security findings are exempt from
that narrower scope (`.github/scripts/ai-pr-review.ts:975-1064,1117-1133`). The decision is
derived from open blocking findings (`.github/scripts/ai-pr-ledger.ts:639-641`).

**Our implementation.** `plugins/sdlc/bin/aisdlc-ledger` owns the deterministic operations:
`cmd_changed_lines`, `cmd_anchor`, `cmd_add`, `cmd_disposition`, `cmd_verdict`, `cmd_seal`,
`cmd_render` and `cmd_read`. `line_hash` normalizes trailing CR. The ledger records `F<n>`
identity, anchors, first/last seen heads, human decisions and the last completed review.

`plugins/sdlc/commands/review.md` — Phase 4b chooses full or incremental scope; Phase 6
applies dispositions, seals and publishes the ledger before the review; Phase 7 re-enters
that path after an autofix push. `plugins/sdlc/templates/trackers/github.md` and
`plugins/sdlc/templates/trackers/local.md` implement `get-pr-ledger` / `put-pr-ledger`.
`plugins/sdlc/commands/fix-pr.md` carries the verdict and `Ledger:` lines rather than a
second prose copy of the findings. Shared vocabulary lives in
`plugins/sdlc/skills/pipeline-contracts/SKILL.md` — Findings ledger.

**Deliberate differences and limits:**

- Our digest is unkeyed SHA-256 over canonical JSON: it detects inconsistent content,
  not the identity of its author. Foreign-comment isolation comes from `get-pr-ledger`
  selecting only the current user's comment, rather than AWS's bot-only rule
  (`.github/scripts/ai-pr-ledger.ts:1241-1267`).
- Our severity vocabulary remains `blocker / major / minor / nit`, not AWS's `P0..P3`
  (`.github/prompts/ai-pr-review-common.md:152-197`).
- A signed `Waived: F<id> — reason — @who` can accept even a blocker. Only **open**
  blocker/major findings contribute to our blocking verdict.
- An omitted re-report alone never closes a finding. On an incremental pass, `add --since`
  resolves an open finding the reviewer did not re-report only when a file it is anchored in
  changed since the last reviewed head; elsewhere it stays open. This is AWS's evidence rule for
  a judge-declared resolution — a cited line gone or a cited file touched
  (`.github/scripts/ai-pr-ledger.ts:945-970`) — with the omission standing in for the judge's
  explicit `resolved` disposition, which we do not have.

### 2.3 Review evidence discipline

**AWS mechanism.** The driver rejects evidence that is not on a changed line
(`.github/scripts/ai-pr-review.ts:1409-1415`). P0/P1 findings must carry REPRO, LOSS and
BLAME; a condition shared by base is `Pre-existing:` and P2 at most
(`.github/prompts/ai-pr-review-common.md:152-164`).

**Our implementation.** `plugins/sdlc/skills/code-review/SKILL.md` — Evidence and Imported
findings — requires a changed-line citation, concrete trigger, traced path and observable
wrong result. Blocker/major findings also need `Repro:`, `Loss:` and `Blame:`; a failed
blame case becomes `[minor] Pre-existing:`. `plugins/sdlc/agents/code-reviewer.md` — Findings
— makes this the emission gate. `plugins/sdlc/bin/aisdlc-ledger` — `cmd_add --changed` —
enforces changed-line membership instead of asking the model to police its own citations.

**Deliberate difference.** Repro/Loss/Blame remains a judgment rule, not a script pretending
to validate semantics. Command-computed signals and imported scope/slop reports cite whole
files by design and bypass `--changed`; agent findings do not. The incremental security
exception widens this pass's scope, not the whole-PR changed-line evidence boundary.

### 2.4 Harness coverage ratchet

**AWS mechanism.** Units are enumerated from source and matched to test `covers:` claims
(`tests/gen-coverage-registry.ts:992-1077`). Losing a previously covered unit fails; a new
uncovered unit is a note, not a failure (`tests/gen-coverage-registry.ts:1296-1309`). The
registry is deliberately not committed (`docs/reference/09-testing.md:747-758`).

**Our implementation.** `evals/harness/coverage.sh` — `units`, `claims`, `registry`, `check`
— enumerates commands, skills, hooks, runner subcommands, ledger subcommands and descriptor
operations. It compares current claims with a materialized base tree. `Makefile` exposes
`coverage` / `coverage-check`; `.github/workflows/validate.yml` — Harness coverage ratchet
— runs the comparison in CI.

**Deliberate difference.** We do not import AWS's mechanism-strength hierarchy
(`none < cli < sdk < tui`, `tests/gen-coverage-registry.ts:151-156,1138-1141`). A claim here
records that an existing case exercises a unit. It does not prove assertion quality or
complete behavioral coverage, and the ratchet does not demand coverage never established.

---

## 3. What We Did Not Take, and Why

| Mechanism | Source evidence | Decision |
|---|---|---|
| A new routing engine | Exactly one validated directive per dispatch: `core/tools/aidlc-orchestrate.ts:1539-1542`. | Keep the bash queue and existing deterministic gates. Replacing the coordinator is not necessary to protect approvals or derive review verdicts. |
| The complete 33-stage methodology | Stage count: `docs/guide/00-introduction.md:27-30,49-50`; authored stage schema and compiled drift gate: `core/aidlc-common/protocols/stage-definition.md:44-72,179-187`. | Keep our spec-to-implementation chain. More stage definitions are not evidence of better results for this harness. |
| Swarm and worktree-per-unit execution | Explicit stage-major/swarm selection and dependency-ready batches: `docs/guide/04-phases-and-stages.md:340-378`; Unit worktree verification: `docs/guide/12-cli-commands.md:2522-2548`. | Keep ticket-level isolation rather than add Unit DAGs, batch checkpoint state and another merge lifecycle. |
| ARS composite | Priors explicitly call themselves uncalibrated and advisory: `core/tools/data/ars-priors.json:2`; the calculation's stated contract agrees: `core/tools/aidlc-graph.ts:3289-3296`. | Do not introduce a numerical risk score with no local calibration. Prefer measured change budgets and explicit gates. |

For ARS, the plan's `ars-priors.json:1` citation is off by one: line 1 opens the JSON;
**line 2** contains the statement. The implementation exports `computeArs` and invokes it
from the `ars` CLI to emit proposal data (`core/tools/aidlc-graph.ts:3512-3515,4180-4182`).
A search of the engine tools found no routing consumer of that composite, consistent with
its explicit advisory contract (`core/tools/aidlc-graph.ts:3294-3296`). This supports the
narrow claim that the composite does not deterministically route the engine, not that ARS
component scores cannot influence a human's proposed stage selection.

---

## 4. Where We Are Ahead

These are concrete local capabilities, not an overall quality ranking.

| Capability | Our evidence | AWS comparison and boundary |
|---|---|---|
| Scored, costed cheap-model harness evaluation | `evals/harness/run.sh` — `score`, scenario/model loop and total-spend report — runs real branches, scores scenario assertions and reports cost and elapsed time; its documented cheap-model invocation is `--model haiku`. | `scripts/trace-audit.ts:7-13,1193-1202` is an operator-invoked extraction/judgment tool. Its judge emits friction items with severity and prose cost, not a scenario assertion score (`scripts/trace-audit-judge.ts:54-64`; `scripts/trace-audit-judge.md:75-82`). The recorded `total_cost_usd` is the judge call's cost (`scripts/trace-audit-judge.ts:202-211`), not the journey's cost. |
| Review controls pipeline merge eligibility | `plugins/sdlc/commands/review.md` — Phase 6 — derives the ledger verdict and sets `merge-ready` / `changes-requested`; `plugins/sdlc/commands/merge.md` — Phase 2 — refuses a non-`merge-ready` label. | AWS deliberately publishes a `COMMENT` event rather than `APPROVE` or `REQUEST_CHANGES` (`.github/scripts/ai-pr-review.ts:2025-2028`). This is a stronger gate in our command pipeline, not a claim that labels cannot be changed outside it. |
| Measured change surface and structural erosion | `plugins/sdlc/bin/aisdlc` — `run_scope_check`, `_size_eval`, `_struct_analyze`, `_struct_text` — measures added lines/files/modules and complexity-weighted erosion; size has a hard ceiling, structure findings promote PASS to GAPS rather than BLOCKED. | No equivalent combined budget/erosion gate was identified in the compared engine. AWS's documented sensor schema and traceability check address a different axis (`core/sensors/aidlc-traceability.md:1-23,68-89`). This is a bounded comparison finding, not proof of absence across every extension. |

The trace-audit path above is an unscored maintainer friction review, not a CI pass/fail
consumer of its findings (`scripts/trace-audit-judge.ts:248-299`). A search of
`.github/workflows/` found no `trace-audit` invocation; this absence is scoped to the
inspected workflows, not an assertion that AWS has no other tests or live-run tooling.
Its coverage registry does have a CI consumer (`.github/workflows/ci.yml:95-97`).

---

## 5. Deferred

- [SDLC-014 — Reverse traceability in verify](../../specs/SDLC-014/spec.md): add forward/reverse traceability output and identify changed behavior with no acceptance use case.
- [SDLC-015 — Workflow profiles](../../specs/SDLC-015/spec.md): select phase chain and ceremony together instead of relying on a phase-list escape hatch.
- [SDLC-016 — Namespace placeholders and generated host packaging](../../specs/SDLC-016/decomposition.md): resolve command namespaces at packaging time and generate host manifests with a determinism check; decomposed into `SDLC-016-a` (packager) → `-b` (generated marketplaces) → `-c` (install from the packaged tree) → `-d` (mechanical placeholder migration).
