# Pipeline Gaps — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the pipeline past the draft PR (review → fix → merge → housekeeping) and before
the spec (issue intake, bug chain, discovery), add a browser-backed QA surface and a retro, so the
`sdlc` plugin covers every stage the `open-mercato/skills` collection covers — in this harness's
vocabulary and under its rules.

**Architecture:** Phase 0 lays shared ground once: a tracker descriptor and a browser descriptor
selected by the project profile, a contracts skill (chain markers, verdict tokens, claim lock,
labels), a `review` queue phase, and an issue queue. Slices A–E then add commands, one agent, and
three skills that only ever talk to the tracker and browser through those descriptors. The spec
stays the only human gate; the bug chain's approval is the human-labelled issue, recorded in the
generated spec. `/sdlc:merge` is interactive-only.

**Tech Stack:** Bash (runner, hooks, harness), Markdown instruction files, JSON manifests, `jq`,
`make`, `shellcheck`. Go + JavaScript only inside the hermetic eval fixture.

**Spec:** `specs/SDLC-005/spec.md` (Phase 0), `specs/SDLC-006-a/spec.md`,
`specs/SDLC-006-b/spec.md` (slice A), `specs/SDLC-007/spec.md` (B), `specs/SDLC-008/spec.md`
(C), `specs/SDLC-009/spec.md` (D), `specs/SDLC-010/spec.md` (E).

## Global Constraints

- Budgets enforced by `make validate`: `templates/CLAUDE.md` ≤ 90 lines; every playbook ≤ 70;
  **new from this plan:** every `commands/*.md` ≤ 220 lines; every `templates/trackers/*.md` and
  `templates/browsers/*.md` ≤ 120 lines. `SKILL.md` files 75–105 lines.
- Every `SKILL.md` starts with `---` and contains a case-insensitive "use when" sentence; every
  `skills/<s>/agents/eval-set.json` is an array of `{query, should_trigger, note}` with ≥ 1
  `should_trigger: false` (`.github/workflows/validate.yml`).
- `Makefile:11-13` `COMMANDS`, `SKILLS`, `PLAYBOOKS` and `Makefile:8-10` `SCRIPTS` (mirrored in
  `validate.yml` "Lint shell scripts") are the enforced lists. Integration (Task 10) owns them.
- House voice: imperative, unhedged; tables over prose for cases; exact commands over intentions;
  numbered `## Phase N:` sections with `[HARD STOP]`/`[GATE]`/`[REQUIRED]` tags; a first-action
  file check in every command that takes an artefact; a closing `## Not to be confused with`.
  Model: `plugins/sdlc/commands/ship.md`.
- Commands read the profile `.claude/sdlc.md`; **no command names `gh`, `playwright`, or
  `agent-browser` directly** — only descriptor operations in bold, e.g. **create-pr**.
- Orchestrating commands invoke sibling commands through the `SlashCommand` tool
  (`allowed-tools` lists it); when unavailable, they read
  `${CLAUDE_PLUGIN_ROOT}/commands/<name>.md` and follow it verbatim. Outputs pass between steps in
  a block headed `— PREVIOUS STEP (/sdlc:<name>) said —`.
- No organisation vocabulary (CI step "Framework stays project-agnostic").
- `merge`, `brainstorm`, `discover`, `synthetic-users`, `backlog`, `ux-shape`, `ux-setup`,
  `ux-review`, `retro`, `merge-buddy`, `issue`, `test-env` are never added to `ALL_PHASES`.
- Commit style `type(scope): description`; commit after every task. Skip formatters, linters and
  project-wide test suites inside slice tasks — Task 10 runs `make validate selftest eval-dry` once.

---

## Shared contracts (pinned; every slice consumes these verbatim)

### C1. Profile keys (`templates/sdlc.md`, written by `/sdlc:init`)

```markdown
## Artefacts
- **Briefs live in:** `specs/briefs/`
## Issue tracker
- **Kind:** `github`            <!-- github | local | jira-mcp (reads only) | none -->
- **Tracker descriptor:** `.claude/trackers/github.md`
- **Pipeline labels:** `review`, `changes-requested`, `merge-ready`, `blocked`
- **Claim label:** `in-progress`
## Browser
- **Browser descriptor:** `none`   <!-- .claude/browsers/playwright.md | .claude/browsers/agent-browser.md | none -->
## Definition of Ready   <!-- optional; written by /sdlc:init --discovery -->
- Problem and who has it stated
- Expected outcome observable
- No blocking open question
```

### C2. Tracker descriptor format (`templates/trackers/<kind>.md`, ≤ 120 lines)

One `### <operation>` heading per operation, body = the exact shell command(s) with `{param}`
placeholders, then `Returns:` one line. Operations, exact names:

`auth-check current-user get-issue search-issues create-issue comment-issue close-issue
label-issue unlabel-issue assign-issue get-pr list-prs search-prs create-pr update-pr comment-pr
label-pr unlabel-pr assign-pr review-pr merge-pr get-pr-diff get-pr-checks get-run-failed-logs
checkout-pr attach-image-evidence ensure-labels claim release check-claim`

Parameter shapes and return values: `plugins/sdlc/templates/trackers/TEMPLATE.md` (committed in
Task 1) is the authoritative list; `github.md` and `local.md` are the two implementations.

Composite semantics:
- **claim** `{kind issue|pr} {n} {command}` → **assign-issue/pr** to **current-user**, **label**
  `in-progress`, comment `🤖 /sdlc:{command} claimed {ISO-8601}`. Read back all three.
- **check-claim** `{kind} {n}` → `free | mine | other:<login> | stale:<login>` (stale = other's
  claim older than 60 min with no newer comment/commit from them).
- **release** `{kind} {n} {command} {outcome}` → **unlabel** `in-progress`, comment
  `🤖 /sdlc:{command} completed: {outcome}. Lock released.`
- Label mutations: check the label exists first; missing → log `label <x> absent — skipped`, never
  create silently except `ensure` in `/sdlc:init`.
- `github.md` implements with `gh` (REST via `gh api` for mutations, `gh pr/issue` for reads).
- `local.md` implements with files: issues `.aisdlc/tracker/issues/<n>.md` (frontmatter
  `title labels assignees state` + body + `## Comments`), PRs `.aisdlc/tracker/prs.jsonl`
  (`{number, branch, title, label, state, verdict, reviews:[], body_path}`), comments appended
  to the issue file or `prs/<n>.comments.md`. **checkout-pr** = `git checkout <branch>`.
  **attach-image-evidence** = copy images to `.aisdlc/tracker/evidence/pr-<n>/` and list paths.

### C3. Browser descriptor format (`templates/browsers/<provider>.md`, ≤ 120 lines)

Same shape. Operations: `boot-check open goto click fill assert-text screenshot close`.
`screenshot {path}` writes PNG at `{path}`. `boot-check` exits non-zero with an install hint when
the provider is absent. SDLC-005 ships the headings with `TODO: SDLC-009` bodies; SDLC-009 fills.

### C4. Chain markers and verdict tokens

- Last lines of every PR-producing report: `PR: #<n> (<url-or-path>)`. Issue-producing:
  `Issue: #<n> (<url-or-path>)`. Both when both exist, `PR:` first.
- Verdict line, immediately above the markers: `Verdict: APPROVED|CHANGES_REQUESTED` (review),
  `Verdict: NO_ACTION_NEEDED|BUG|FEATURE` (triage), `Verdict: PASS|GAPS` (qa, existing).
  `LOW_CONFIDENCE` is a trailing token on the root-cause section, copied into the PR body.
- Consumers grep these exact strings; never paraphrase them.

### C5. Pipeline labels

Exactly one of `review | changes-requested | merge-ready | blocked` on an open PR, plus the
profile label (`ai-sdlc`) always, plus `in-progress` while claimed. Transitions: ship → `review`;
review CHANGES_REQUESTED → `changes-requested`; review APPROVED → `merge-ready`; BLOCKED.md or
`⚠ NEEDS HUMAN` → `blocked`. Set via **unlabel-pr** old + **label-pr** new.

### C6. Bugfix approval (SDLC-007)

`specs/GH-<n>/spec.md` frontmatter:
```yaml
kind: bugfix
status: approved
approved-by: issue #<n> (label bug, @<author>)
```
`/sdlc:implement` Phase 0 and `bin/aisdlc`'s spec gate accept this **only if** `kind: bugfix`
**and** `approved-by` matches `^issue #[0-9]+` **and** **get-issue** shows label `bug` now.

### C7. Queue (`bin/aisdlc`)

- `ALL_PHASES="implement qa ship review"`; `ISSUE_PHASES="triage root-cause implement qa ship review"`.
- `--no-pr` removes `ship` **and** `review`.
- Phase prompt: `review` → `/sdlc:review <pr#> --autofix` where `<pr#>` is parsed from
  `task.json.pr_url` (`/pull/([0-9]+)` or local `#([0-9]+)`); missing → phase fails with
  `error: no PR number after ship`.
- `aisdlc add --issue <n>`: ticket `GH-<n>`, phases `ISSUE_PHASES`, **check-claim** must be
  `free|stale` else `die "issue <n> already claimed by <who>"`, then **claim** `issue <n> aisdlc`.
  Descriptor resolved from `.claude/sdlc.md` `Tracker descriptor:`; `gh`-based operations run
  from the runner as shell; the `local` descriptor is implemented natively in the runner
  (`tracker_local_*` functions) because the runner cannot ask a model to read a descriptor.
- `run_phase` review outcome: `Verdict: CHANGES_REQUESTED` in `review.json` result and
  `⚠ NEEDS HUMAN` or autofix exhausted → task `failed`, `error: review blockers remain`, worktree
  kept (SDLC-006-a UC-8).
- `cmd_inbox` columns: `#`, title, `Verdict`, pipeline label, url — from **list-prs** / prs.jsonl.

---

## File Structure

**Created**

| Path | Responsibility | Task |
|---|---|---|
| `plugins/sdlc/templates/trackers/{github,local,TEMPLATE}.md` | Tracker providers (C2) | 1 |
| `plugins/sdlc/templates/browsers/{playwright,agent-browser,TEMPLATE}.md` | Browser providers (C3), bodies filled in Task 8 | 1, 8 |
| `plugins/sdlc/skills/pipeline-contracts/SKILL.md` + `agents/eval-set.json` | C2–C7 as the one loadable reference | 2 |
| `plugins/sdlc/commands/{review,fix-pr,review-prs,autopilot}.md` | SDLC-006-a | 4 |
| `plugins/sdlc/agents/code-reviewer.md` | The review engine | 4 |
| `plugins/sdlc/skills/code-review/SKILL.md` + `agents/eval-set.json` | Severity scale, verdict rule, checklist, spec lenses | 4 |
| `plugins/sdlc/commands/{continue,merge,merge-buddy,followup,close-fixed,changelog}.md` | SDLC-006-b | 5 |
| `plugins/sdlc/commands/{issue,triage,root-cause,fix-issue}.md` | SDLC-007 | 6 |
| `plugins/sdlc/commands/{brainstorm,discover,synthetic-users,backlog,ux-shape,ux-setup}.md` | SDLC-008 | 7 |
| `plugins/sdlc/skills/discovery/SKILL.md` + `references/brief-template.md` + `agents/eval-set.json` | Brief format, evidence tags, DoR | 7 |
| `plugins/sdlc/commands/{test-env,integration-tests,ux-review}.md` | SDLC-009 | 8 |
| `evals/harness/scenarios/ui-flow/{spec.md,scenario.json}` | SBX-4 UI scenario | 8 |
| `plugins/sdlc/commands/retro.md` | SDLC-010 | 9 |

**Modified**

| Path | Change | Task |
|---|---|---|
| `plugins/sdlc/templates/sdlc.md` | C1 keys | 1 |
| `plugins/sdlc/commands/init.md` | tracker/browser questions, copy descriptors, `ensure` labels, `.aisdlc/tracker/` + gitignore, `--discovery` | 1, 7 |
| `plugins/sdlc/commands/ship.md` | descriptor cutover, `--docs`, `LOW_CONFIDENCE` copy, image evidence | 1, 6, 8 |
| `plugins/sdlc/commands/implement.md` | Phase 0 accepts C6 | 3 |
| `plugins/sdlc/commands/spec.md` | read `specs/briefs/*.md` when present | 7 |
| `plugins/sdlc/commands/mockup.md` | read `specs/briefs/ux-<slug>.md` when present | 7 |
| `plugins/sdlc/agents/auto-qa.md` | browser pass, `Screenshot` column | 8 |
| `plugins/sdlc/bin/aisdlc` | C7 | 3 |
| `evals/harness/selftest.sh`, `evals/harness/stub-claude` | review phase, `--issue`, `artifacts_exist` | 3, 8 |
| `evals/harness/run.sh` (or `score.sh`) | `artifacts_exist` assertion | 8 |
| `Makefile`, `.github/workflows/validate.yml` | lists, new budgets | 10 |
| `plugins/sdlc/hooks/session-start` | announce new commands/skills | 10 |
| `plugins/sdlc/templates/CLAUDE.md` | 3 router rows | 10 |
| `README.md`, `docs/ai-sdlc.md`, `docs/overlay-contract.md`, `.claude-plugin/marketplace.json`, `plugins/sdlc/.claude-plugin/plugin.json` | docs, version bump | 10 |

---

## Phase 0 — Foundation (Tasks 1–3, one agent, sequential)

### Task 1: Descriptors, profile, init, ship cutover

**Files:** create `templates/trackers/{github,local,TEMPLATE}.md`,
`templates/browsers/{playwright,agent-browser,TEMPLATE}.md`; modify `templates/sdlc.md`,
`commands/init.md`, `commands/ship.md`.

- [ ] Write `templates/trackers/TEMPLATE.md`: C2 format, every operation heading with a one-line
      "what it must do" and `Returns:`; ≤ 120 lines.
- [ ] Write `github.md`: each operation as the exact `gh` command. Mutations via `gh api` REST
      (`gh api -X POST repos/{owner}/{repo}/issues/{n}/labels -f 'labels[]={label}'` etc.); reads
      via `gh pr view --json …`. **claim/check-claim/release** per C2. **attach-image-evidence**:
      push to an `evidence/pr-{n}` orphan branch and embed raw URLs; private repo → link instead.
- [ ] Write `local.md` per C2 file layout; every operation is `jq`/`printf`/`git` over
      `.aisdlc/tracker/`. Issue numbers = next integer in `issues/`.
- [ ] Write browser `TEMPLATE.md` and the two providers with C3 headings; body of each
      operation is exactly `TODO: SDLC-009` so Task 8 can grep its work.
- [ ] `templates/sdlc.md`: add C1 keys; `Kind:` comment updated to `github | local | jira-mcp | none`.
- [ ] `init.md` Phase 1: detect remote/`gh auth status` → propose `github` else `local`; detect
      Playwright config or `agent-browser` binary → propose provider else `none`. Phase 3: copy
      the chosen descriptors to `.claude/trackers/` and `.claude/browsers/`, `mkdir -p
      specs/briefs .aisdlc/tracker`, add `.aisdlc/tracker/` to `.gitignore`, run **ensure** for the
      five labels (github only). Keep ≤ 220 lines — move the survey checklist to
      `templates/init-survey.md` if needed and reference it.
- [ ] `ship.md`: replace every `gh …` with the bold operation (**create-pr**, **label-pr**,
      **comment-pr**); Phase 4 becomes "the `local` provider" — no separate offline path; add
      `--docs` (SDLC-005 UC-7: allowed globs `*.md docs/** CHANGELOG*`, refuse listing others);
      report ends with `Verdict:` + `PR:` per C4; set label `review` per C5.
- [ ] Commit `feat(sdlc): tracker and browser descriptors, profile keys, ship cutover`.

### Task 2: `pipeline-contracts` skill

**Files:** create `skills/pipeline-contracts/SKILL.md`, `skills/pipeline-contracts/agents/eval-set.json`.

- [ ] SKILL.md 75–105 lines: frontmatter with "Use when a command needs the tracker, a claim, a
      verdict token, or a chain marker…"; sections: Descriptors (how to resolve and read one),
      Operations table (C2 names, one line each), Chain markers (C4), Verdict tokens (C4), Claim
      lock (C2 composite + staleness), Pipeline labels (C5), Bugfix approval (C6).
- [ ] eval-set.json: ≥ 6 queries, ≥ 2 negative.
- [ ] Commit `feat(sdlc): pipeline-contracts skill`.

### Task 3: Queue — review phase, issue queue, bugfix gate

**Files:** modify `bin/aisdlc`, `commands/implement.md`, `evals/harness/selftest.sh`,
`evals/harness/stub-claude`.

- [ ] selftest: add cases (write first, watch them fail):
      `review phase runs after ship with the PR number` (stub ship writes a `PR: #7 (…)` line;
      assert `review.log` exists and the prompt in it contains `/sdlc:review 7 --autofix`);
      `--no-pr strips ship and review`; `add --issue claims once` (local tracker in the fresh repo:
      `issues/42.md` with `labels: [bug]`; after add, file has `in-progress` and a `🤖` comment;
      second add exits 1 with `already claimed`); `bugfix spec passes the gate` (spec with C6
      frontmatter and issue labelled bug → implement runs; same with label removed → refused).
- [ ] stub-claude: handle `/sdlc:review*` (write `Verdict: APPROVED` result), `/sdlc:triage*`,
      `/sdlc:root-cause*` as no-op successes with ≥ 1 turn.
- [ ] `bin/aisdlc`: implement C7 — `ALL_PHASES`, `ISSUE_PHASES`, `--issue` in `cmd_add`,
      `tracker_local_{get_issue,check_claim,claim,release,list_prs}` functions, descriptor kind
      read from `.claude/sdlc.md` (`grep -oE 'Tracker descriptor:\*\* `[^`]+'`), `github` path
      shelling `gh`; `run_phase` review-outcome rule; `cmd_inbox` columns; spec gate accepting C6;
      `cmd_help` text.
- [ ] `implement.md` Phase 0: add the C6 acceptance sentence and the **get-issue** re-check.
- [ ] Run `make selftest` (this task only — the runner is the deliverable). Commit
      `feat(aisdlc): review phase, --issue queue, bugfix approval gate`.

---

## Slices A–E (Tasks 4–9, one agent per slice, parallel; each owns only its listed files)

### Task 4: Slice A-I — review engine (SDLC-006-a)

**Files:** create `commands/{review,fix-pr,review-prs,autopilot}.md`, `agents/code-reviewer.md`,
`skills/code-review/SKILL.md`, `skills/code-review/agents/eval-set.json`.

- [ ] `skills/code-review/SKILL.md`: severity table (`blocker | major | minor | nit` with one
      example each from this harness: deleted test, `Out:` violation, contract not co-changed,
      density floor missed, naming), verdict rule verbatim (SDLC-006-a non-functional), the
      checklist = `docs/ai-sdlc.md` "Definition of done" bullets + security + contract surfaces
      + slop-guard import rule, spec-review five lenses, waiver format (`Waived: <major> — <why>
      — @<who>`). "Use when reviewing a PR, deciding a verdict, or writing a finding."
- [ ] `agents/code-reviewer.md`: `tools: Read, Grep, Glob, Bash`, `model: sonnet`; order: profile
      → spec (if ticket) → `Out:` → diff → tests → run the verification matrix → findings in the
      skill's format with `file:line`; output ends `Verdict: …`.
- [ ] `review.md` ≤ 220 lines: Phase 1 Preflight [HARD STOPS] (first action **get-pr**; missing →
      one line); Phase 2 Claim (**check-claim** → table: free/mine/other/stale × `--force`); Phase 3
      Signals (conflicts, **get-pr-checks**) recorded as findings, never stops; Phase 4 Isolated
      worktree (`git worktree add … pull/<n>/head` or **checkout-pr**); Phase 5 Review (Agent
      `code-reviewer`; spec-only → lenses); Phase 6 Verdict + labels (**review-pr**, C5); Phase 7
      Autofix [only when author == **current-user** or `--autofix`]: conflicts → findings → CI,
      new commits only, loop ≤ 3 re-reviews, stop on `⚠ NEEDS HUMAN`; Phase 8 Release + cleanup
      (finally); Phase 9 Report per C4.
- [ ] `fix-pr.md`: merge base → `/sdlc:review <n> --autofix` → CI stabilisation table
      (`real-bug | test-bug | flake | infra` × action; flake = one **rerun** via
      **get-run-failed-logs** evidence before code) → loop until `merge-ready`; `--ci-only`.
- [ ] `review-prs.md`: **list-prs** open + profile label, filter no review by **current-user**,
      newest first, skip `other:` claims listing them, invoke `/sdlc:review` each.
- [ ] `autopilot.md`: diagnosis table (state → evidence → next command), `--dry-run` prints
      chain only, `--allow-merge` appends `/sdlc:merge`; re-diagnose after each step; max 6 steps.
- [ ] Commit `feat(sdlc): review, fix-pr, review-prs, autopilot`.

### Task 5: Slice A-II — resume, merge, housekeeping (SDLC-006-b)

**Files:** create `commands/{continue,merge,merge-buddy,followup,close-fixed,changelog}.md`.

- [ ] `continue.md`: Phase 1 first action — locate `specs/<T>/BLOCKED.md` or **get-pr** by number;
      three entry states (UC-1/2/3) as a table; UC-2 writes `specs/<T>/continue-plan.md`
      checklist; UC-3 stops at a draft spec; then `/sdlc:implement` (resumes at first UC without a
      passing test — state this) and `/sdlc:qa`; C4 report.
- [ ] `merge.md`: `allowed-tools` excludes `Write`/`Edit`; gate table in fixed order (label,
      **get-pr-checks**, mergeable, QA verdict comment) → first failure = the one refusal line;
      **review-pr** approve + **merge-pr** squash; `--followup` → `/sdlc:followup`.
- [ ] `merge-buddy.md`: read-only, two tables, no `Bash(git:*)` writes.
- [ ] `followup.md`: dedupe by comment URL in **search-issues**; **create-issue** body template;
      **comment-pr** `Filed as Issue: #<m>`.
- [ ] `close-fixed.md`: **list-prs** merged since watermark `.aisdlc/close-fixed.json`
      (`{last_run, last_pr}`); parse `Fixes|Closes #n`; **close-issue** with comment; unmerged →
      **comment-issue**; write watermark last.
- [ ] `changelog.md`: `git describe --tags` default for `--since`; group by conventional type;
      author from `git log --format=%an` on the squash commit; write entry; `/sdlc:ship --docs`;
      `nothing to release` path.
- [ ] Commit `feat(sdlc): continue, merge, merge-buddy, followup, close-fixed, changelog`.

### Task 6: Slice B — issue intake and bug chain (SDLC-007)

**Files:** create `commands/{issue,triage,root-cause,fix-issue}.md`; modify `commands/ship.md`
**only** to copy `LOW_CONFIDENCE` into the PR body (one bullet in Phase 2 step 2 — coordinate
with Task 8 via hub before editing; Task 6 edits first).

- [ ] `issue.md`: Phase 1 dedupe (**search-issues**, **search-prs**); Phase 2 template (six
      sections, C4 `Issue:` marker); `--normalize` posts one `🤖 Normalized` comment, checks DoR
      block if present; `--all` = 25 fewest-sections, skip claimed, idempotent via marker search.
- [ ] `triage.md`: read-only; Phase 1 **get-issue** first action; Phase 2 already-fixed check
      (`git log --grep "#<n>"`, **search-prs**) → `NO_ACTION_NEEDED`; Phase 3 classify table
      (labels first, then verbs); Phase 4 on BUG write `specs/GH-<n>/spec.md` via the
      `/sdlc:spec` writer with C6 frontmatter, UC rows from Expected/Actual, `Out:` from adjacent
      modules; open questions → keep `draft`; FEATURE → `/sdlc:spec GH-<n>` draft. Report `Verdict:`.
- [ ] `root-cause.md`: read-only except the spec; `### Root cause` section format; `LOW_CONFIDENCE`
      rule (fewer than 2 corroborating references, or reproduction not achievable).
- [ ] `fix-issue.md`: orchestrator; Phase 1 **check-claim**; Phase 2 `/sdlc:triage`; stop on
      `NO_ACTION_NEEDED`/`FEATURE`; Phase 3 **claim** issue + worktree `ai/GH-<n>-<slug>`; Phase
      4–7 root-cause → implement → qa → ship (lock hand-off issue→PR: **claim** pr, **release**
      issue `handed off to PR #<m>`) → `/sdlc:review <m> --autofix`; Phase 8 release once
      (finally) with the abort text from SDLC-007 UC-8; C4 report with both markers.
- [ ] Commit `feat(sdlc): issue, triage, root-cause, fix-issue`.

### Task 7: Slice C — discovery (SDLC-008)

**Files:** create `commands/{brainstorm,discover,synthetic-users,backlog,ux-shape,ux-setup}.md`,
`skills/discovery/SKILL.md`, `skills/discovery/references/brief-template.md`,
`skills/discovery/agents/eval-set.json`; modify `commands/spec.md` Phase 1 (one paragraph: read
`specs/briefs/*.md` matching the ticket or slug), `commands/mockup.md` Phase 1 (read
`specs/briefs/ux-<slug>.md`), `commands/init.md` (add `--discovery`: append the C1 Definition of
Ready block to the profile — coordinate with the Phase 0 agent's final `init.md` via hub; Task 7
runs after Phase 0 so the file is stable).

- [ ] `skills/discovery/SKILL.md`: brief format (section list from SDLC-008 UC-2), evidence tags
      and the "never upgrades" rule, Definition of Ready, sizing (brief ≤ 80, product-brief ≤ 200),
      anti-patterns table. "Use when writing or reading a brief, tagging evidence, deciding if a
      ticket is ready…". `references/brief-template.md` = the blank.
- [ ] `brainstorm.md`: one question per message [REQUIRED]; alternatives incl. nothing;
      `Agent` challenger with a fixed prompt; `Next:` routing line; brief file.
- [ ] `discover.md`: modes table; context gate over a research folder (`--research <dir>`,
      default `specs/briefs/research/`); interview rounds; collection plan rule; skeptic subagent;
      quality gate: any untagged factual sentence → fix before writing.
- [ ] `synthetic-users.md`: personas only from tagged brief material; two runs; intersection
      rule; stances table; `[SYNTHETIC]` on every line; `Real-user check:` per finding.
- [ ] `backlog.md`: tree first [GATE]; readiness refusal (UC-6); `--research`; file via
      `/sdlc:issue`; adopt existing by title match.
- [ ] `ux-shape.md`, `ux-setup.md` per UC-7/UC-8; `ux-setup` writes a tier-3 rule ≤ 70 lines.
- [ ] Commit `feat(sdlc): discovery commands and skill`.

### Task 8: Slice D — test env and browser QA (SDLC-009)

**Files:** fill `templates/browsers/{playwright,agent-browser}.md` bodies (replace every
`TODO: SDLC-009`); create `commands/{test-env,integration-tests,ux-review}.md`,
`evals/harness/scenarios/ui-flow/{spec.md,scenario.json}`; modify `agents/auto-qa.md`,
`commands/ship.md` (evidence images — after Task 6's edit; coordinate via hub),
`evals/harness/run.sh` or `score.sh` (`artifacts_exist`), `evals/harness/selftest.sh` (scorer case).

- [ ] Browser bodies: `playwright.md` uses `npx playwright` with a generated
      `.aisdlc/browser/run.mjs` helper per operation; `agent-browser.md` uses its CLI verbs;
      `boot-check` install hints; `screenshot {path}`.
- [ ] `test-env.md`: discovery order table (profile `Integration tests need` → compose → Makefile
      `run|dev|start` → package scripts → `none`); generate `.aisdlc/test-env/{up.sh,down.sh}`
      POSIX; `env.json` fields; health = **boot-check** + HTTP 200 on `health_url`; warm reuse
      via `env.json` + port probe; `--down`; UC-2 template path.
- [ ] `integration-tests.md`: requires `env.json`; explore DOM through **open/goto** and read
      real locators; one test per UI UC named with the id in the profile's E2E runner; run;
      diagnosis table from artefacts.
- [ ] `auto-qa.md`: step 5 split — API UCs via `curl`, UI UCs via the browser descriptor when
      `Browser descriptor:` ≠ `none` (**boot-check** → `/sdlc:test-env` → per UC **goto/…/
      screenshot specs/<T>/qa/UC-<n>.png**); `Screenshot` column; `none` → the one-line skip.
- [ ] `ship.md`: after the QA comment, **attach-image-evidence** for `specs/<T>/qa/*.png` when any.
- [ ] `ux-review.md`: refuse without `design-system.md`; walk PR UI; findings format; one comment.
- [ ] Scenario `ui-flow` (SBX-4, approved, 2 UI UCs on the fixture frontend; `phases: "implement
      qa"`; `assert.artifacts_exist`); scorer support + selftest case.
- [ ] Commit `feat(sdlc): test-env, integration-tests, browser QA pass, ux-review`.

### Task 9: Slice E — retro (SDLC-010)

**Files:** create `commands/retro.md`.

- [ ] Classification table (SDLC-010 UC-1) with the `jq` filter per class; cause ranking `jq`
      over `task.json` + `<phase>.json`; metrics block; `n/a` path for `local`/unreachable;
      symptom → harness file table copied from `harness-eval`; single ask → `/sdlc:issue`;
      report ≤ 60 lines; `Not to be confused with` (`harness-eval` measures scenarios, retro
      measures production runs).
- [ ] Commit `feat(sdlc): retro`.

---

## Task 10: Integration (after all slices)

**Files:** `Makefile`, `.github/workflows/validate.yml`, `hooks/session-start`,
`templates/CLAUDE.md`, `README.md`, `docs/ai-sdlc.md`, `docs/overlay-contract.md`,
`.claude-plugin/marketplace.json`, `plugins/sdlc/.claude-plugin/plugin.json`.

- [ ] `Makefile`: `COMMANDS += review fix-pr review-prs autopilot continue merge merge-buddy
      followup close-fixed changelog issue triage root-cause fix-issue brainstorm discover
      synthetic-users backlog ux-shape ux-setup test-env integration-tests ux-review retro`;
      `SKILLS += pipeline-contracts code-review discovery`; new `TRACKERS := github local
      TEMPLATE`, `BROWSERS := playwright agent-browser TEMPLATE` required-file checks; agent
      `code-reviewer.md` required; budgets: commands ≤ 220, descriptors ≤ 120.
- [ ] `session-start`: announce the new entry points grouped as in the README.
- [ ] `templates/CLAUDE.md`: rows `Fix a reported bug → run /sdlc:fix-issue <n>`, `Review a pull
      request → run /sdlc:review <pr#>`, `Finish a stalled PR → run /sdlc:autopilot <pr#>`; stay ≤ 90.
- [ ] `README.md`: "What's included" tables extended; "The loop" gains the post-PR and issue
      rows; `docs/ai-sdlc.md` "The loop" table and "Definition of done" gain review; prune
      `docs/overlay-contract.md` items 1 and 4; bump `0.1.0 → 0.2.0` in both manifests.
- [ ] Run `make validate && make selftest && make eval-dry`; fix what fails; commit
      `chore(sdlc): integrate pipeline-gap commands, budgets, docs, 0.2.0`.

---

## Execution order

```
Task 1 → Task 2 → Task 3            (Phase 0, one agent)
        ↓
Tasks 4, 5, 6, 7, 8, 9            (one batch, six agents; shared-file edits: ship.md — Task 6 then Task 8; init.md — Task 7 only)
        ↓
Task 10                             (integration, then validate/selftest/eval-dry)
```
