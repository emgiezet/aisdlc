# Multi-Level Planning and the Skillify Loop — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the pipeline a planning level above the spec (`/sdlc:arch`) and one below it
(`/sdlc:design`, also a queue phase whose artefact binds the build), and a step that turns QA
findings into permanent repo instructions (`/sdlc:skillify`).

**Architecture:** Three new command instruction files, one new skill holding both planning
formats, one new queue phase in `bin/aisdlc`, and additive eval scoring for the declared file
scope. The spec remains the only human gate: `design.md` is agent-authored and committed inside
the worktree; `arch.md` and skillified rules are interactive-only because they are decisions a
human owns and because the queue's own permission set denies `.claude/**` writes.

**Tech Stack:** Bash (runner, hooks, eval harness), Markdown instruction files, JSON manifests,
`jq`, `make`, `shellcheck`. Go + JavaScript only inside the hermetic eval fixture.

**Spec:** `specs/SDLC-001/arch.md` (epic), `specs/SDLC-001-a/spec.md`,
`specs/SDLC-001-b/spec.md`, `specs/SDLC-001-c/spec.md`, `specs/SDLC-002/spec.md`,
`specs/SDLC-004/spec.md`

## Global Constraints

- Instruction budgets, enforced by `make validate`: `plugins/sdlc/templates/CLAUDE.md` ≤ 90 lines;
  every file in `plugins/sdlc/templates/playbooks/` ≤ 70 lines. `.claude/rules/*` ≤ 70 lines and
  router table ≤ 12 rows are enforced by instruction text, not by the Makefile.
- Every `SKILL.md` must begin with `---` and contain a case-insensitive `use when` sentence
  (`.github/workflows/validate.yml`, step "Skill frontmatter and trigger sets").
- Every `agents/eval-set.json` is a JSON array of `{"query", "should_trigger", "note"}`, with at
  least one `should_trigger: false` entry.
- `Makefile:10-12` — `COMMANDS`, `SKILLS`, `PLAYBOOKS` are the lists `make validate` enforces. A
  new command or skill that is not listed is not validated; a listed file that is missing fails
  the build.
- `shellcheck -S warning` must stay clean for every script in `Makefile:7-9` (`SCRIPTS`) and in
  the CI "Lint shell scripts" step. Both lists must be updated together.
- No organisation vocabulary anywhere (CI step "Framework stays project-agnostic").
- House voice for instruction files: imperative and unhedged, tables over prose for anything with
  cases, exact commands over intentions, a closing `## Not to be confused with` section. Commands
  are 85–185 lines; `SKILL.md` files are 75–105 lines.
- Artefact caps: `design.md` ≤ 120 lines, `arch.md` ≤ 120 lines.
- `arch` and `skillify` are never added to `ALL_PHASES`.
- Thresholds are numbers, never adjectives: "more than 3 use cases", "more than one stack".
- Commit style: `type(scope): description` (conventional commits). Commit after every task.

---

## File Structure

**Created**

| Path | Responsibility |
|---|---|
| `plugins/sdlc/skills/program-design/SKILL.md` | Both planning formats, sizing limits, anti-patterns, review checklist |
| `plugins/sdlc/skills/program-design/references/design-template.md` | The `design.md` blank |
| `plugins/sdlc/skills/program-design/references/arch-template.md` | The `arch.md` blank |
| `plugins/sdlc/skills/program-design/agents/eval-set.json` | Trigger set for the skill |
| `plugins/sdlc/commands/design.md` | `/sdlc:design` — program design for one ticket |
| `plugins/sdlc/commands/arch.md` | `/sdlc:arch` — epic decomposition and component boundaries |
| `plugins/sdlc/commands/skillify.md` | `/sdlc:skillify` — findings become instructions |
| `evals/harness/score.sh` | The scenario scorer, extracted so it can be tested offline |
| `evals/harness/scenarios/go-design-scope/spec.md` | `SBX-3` approved spec (deposit endpoint) |
| `evals/harness/scenarios/go-design-scope/scenario.json` | Assertions including the new keys |

**Modified**

| Path | Change |
|---|---|
| `Makefile` | `COMMANDS`, `SKILLS`, `SCRIPTS` |
| `plugins/sdlc/bin/aisdlc` | `ALL_PHASES`, artefact collection, `cmd_logs`, `cmd_status` column, `cmd_help` |
| `plugins/sdlc/hooks/session-start` | Announce the three commands and the new skill |
| `plugins/sdlc/templates/CLAUDE.md` | Router rows for the new commands |
| `plugins/sdlc/commands/implement.md` | Read `design.md`, execute its slices, stay inside `files:` |
| `plugins/sdlc/commands/qa.md` | Design conformance, skillify candidates, hand-off |
| `plugins/sdlc/commands/spec.md` | Consume an epic's `arch.md`; name the arch step when over threshold |
| `plugins/sdlc/agents/auto-qa.md` | Two new report sections and the matching gap rows |
| `plugins/sdlc/skills/task-router/SKILL.md` | "Harvesting an instruction from a finding" |
| `plugins/sdlc/skills/task-router/agents/eval-set.json` | One positive trigger for harvesting |
| `evals/harness/run.sh` | Source `score.sh` instead of defining `score()` |
| `evals/harness/selftest.sh` | Design-phase assertions; offline scorer test |
| `evals/harness/stub-claude` | A `/design*` case |
| `.github/workflows/validate.yml` | `score.sh` in the shellcheck list |
| `README.md`, `docs/ai-sdlc.md`, `docs/overlay-contract.md`, `.claude-plugin/marketplace.json` | Documentation and manifest text |

---

## Task 1: The `program-design` skill

**Files:**
- Create: `plugins/sdlc/skills/program-design/SKILL.md`
- Create: `plugins/sdlc/skills/program-design/references/design-template.md`
- Create: `plugins/sdlc/skills/program-design/references/arch-template.md`
- Create: `plugins/sdlc/skills/program-design/agents/eval-set.json`
- Modify: `Makefile:11`

**Interfaces:**
- Consumes: nothing.
- Produces: the two artefact formats every later task depends on. `design.md` frontmatter keys
  `ticket`, `spec`, `files:` (a YAML list of repo-relative paths — the declared file scope, read
  by Task 4 and Task 5). `design.md` sections, in order: `## Approach`, `## Components`,
  `## Signatures`, `## Call graph`, `## Contract and data changes`, `## Build order`, `## Risks`.
  `arch.md` frontmatter keys `epic`, `title`, `status`, `slices:`; sections `## Problem`,
  `## System context`, `## Component boundaries`, `## Decisions`, `## Slices`, `## Risks`,
  `## Out of scope`, `## Open questions`.

- [ ] **Step 1: Register the skill and watch validation fail**

```bash
sed -i 's/^SKILLS := .*/SKILLS := spec-authoring task-router dense-testing harness-eval program-design/' Makefile
make validate
```

Expected: FAIL — `✗ skills/program-design/SKILL.md MISSING`.

- [ ] **Step 2: Write the design template**

Create `plugins/sdlc/skills/program-design/references/design-template.md` exactly:

````markdown
---
ticket: TICKET-000
spec: specs/TICKET-000/spec.md
files:
  - path/to/file.ext
---

# Design — TICKET-000

## Approach

<3–5 sentences: the approach taken, in this repo's existing vocabulary. One line on the
alternative rejected and why. Never restate the requirements — the spec holds those.>

## Components

| component | file | responsibility | state |
|-----------|------|----------------|-------|
| `<Name>` | `path/to/file.ext` | <one line> | new / changed |

## Signatures

```<language>
// Exact declarations to add or change. No bodies, no pseudo-code.
func (s *Store) Deposit(id string, amount int64) (Account, error)
```

## Call graph

- `httpapi.handleDeposit` → `ledger.Store.Deposit` → `ledger.Store.Get`
- <one edge per line, entry point first; name real symbols, not layers>

## Contract and data changes

| what | change | backward compatible |
|------|--------|---------------------|
| `<operationId>` in <the contract directory named in .claude/sdlc.md> | <the change> | yes / no — <why> |
| <table, column, index, migration> | <the change> | yes / no — <why> |

Delete this section when the change touches no contract and no schema.

## Build order

Vertical slices, end-to-end skeleton first. Every `UC-<n>` in the spec appears in exactly one row.

| slice | UC ids | delivers | observable proof |
|-------|--------|----------|------------------|
| 1 | UC-1 | <the thinnest path that runs end to end> | <the assertion that proves it> |
| 2 | UC-2, UC-3 | <the next increment> | <its assertion> |

## Risks

- <at most three: the parts most likely to be wrong, and what would reveal it>
````

- [ ] **Step 3: Write the architecture template**

Create `plugins/sdlc/skills/program-design/references/arch-template.md` exactly:

````markdown
---
epic: EPIC-000
title: <one line, in the product's own vocabulary>
status: draft
slices: [EPIC-000-a, EPIC-000-b]
---

# EPIC-000 — <title>

## Problem

<4–8 sentences: what is broken or missing across components, and for whom. No solution.>

## System context

| Component | Owns | Files |
|---|---|---|
| `<name>` | <the one responsibility> | `path/` |

Only the components this epic touches or depends on. This is not a catalogue of the repo.

## Component boundaries

| Component | Exposes | Consumers |
|---|---|---|
| `<name>` | <the contract: endpoint, function, event, artefact> | <who calls it> |

## Decisions

| Decision | Rejected alternative | Why |
|---|---|---|
| <the call made> | <what was not done> | <the reason, in one line> |

Hard-to-reverse rows become ADRs at the location `.claude/sdlc.md` names. When it says `none`,
this table is the record.

## Slices

Walking skeleton first. Each slice is independently shippable and leaves the system working.

| Slice | Ticket | Delivers | Depends on | Observable proof |
|---|---|---|---|---|
| <name> | `EPIC-000-a` | <outcome> | — | <what a test or a command would show> |

## Risks

- <the parts most likely to be wrong, and what would reveal it>

## Out of scope (epic-wide)

- <what no slice may touch — inherited by every slice's spec `Out:` section>

## Open questions

- [ ] <unresolved decision — must be empty before a slice's spec is approved>
````

- [ ] **Step 4: Write `SKILL.md`**

Create `plugins/sdlc/skills/program-design/SKILL.md`. Frontmatter exactly:

```yaml
---
name: program-design
description: >
  Plan the shape of the code before writing it — component boundaries and slices at the epic
  level, signatures and call graph at the ticket level, both committed as artefacts an agent
  and a reviewer can be held to. Use when a spec is approved but the code shape is undecided,
  when a change spans more than one component, when an agent keeps inventing its own module
  layout mid-build, or when an epic needs splitting into independently shippable slices.
---
```

Body, 75–105 lines, these sections in this order:

1. `# Program Design` — the failure mode this prevents, stated plainly: a model optimising for a
   green suite reaches for a swallowed exception, a widened type, or a helper in the nearest
   file, because nothing said where the change belongs. Two levels, two artefacts, one
   non-negotiable: **neither artefact is a gate. The spec is the only approval point.**
2. `## Two levels` — table: level / artefact / who writes it / who reads it / when it is
   required. Rows: architecture → `specs/<EPIC>/arch.md` → agent proposes, human owns →
   `/sdlc:spec` → more than 3 use cases or more than one stack; program → `specs/<TICKET>/design.md`
   → agent, unattended → `/sdlc:implement`, `/sdlc:qa` → every ticket the queue runs.
3. `## The design format` — link `references/design-template.md`, list the seven sections with
   one line each, and state the two load-bearing rules verbatim:
   - `files:` in the frontmatter **is** the declared file scope. Anything outside it is out of
     scope until the list is amended in the same commit, with a reason.
   - Every `UC-<n>` in the spec appears in exactly one build-order row; slice 1 is the thinnest
     path that runs end to end.
4. `## The architecture format` — link `references/arch-template.md`, and the slice rules: every
   row names a ticket id, what it delivers, what it depends on, and its observable proof;
   walking skeleton first; a slice that cannot ship alone is not a slice.
5. `## Sizing` — `design.md` ≤ 120 lines and ≤ 10 components; over that means the spec must split.
   `arch.md` ≤ 120 lines and ≤ 6 slices; over that means the epic must split. Never shrink by
   deleting the signatures — they are the part that does the work.
6. `## Anti-patterns` — table, smell → why it breaks unattended runs. At minimum: prose
   describing the approach with no signatures (nothing to compare the diff against); a `files:`
   list of directories rather than files (scope check becomes vacuous); repeating the spec's
   requirements (two copies drift, the agent trusts the wrong one); designing the tests
   (`dense-testing` owns the floors); an empty `Call graph` on a multi-component change.
7. `## Review checklist` — checkboxes matching the rules above.

- [ ] **Step 5: Write the trigger set**

Create `plugins/sdlc/skills/program-design/agents/eval-set.json` exactly:

```json
[
  {"query": "Write the program design for ABC-123 before any code", "should_trigger": true, "note": "the design.md format is this skill's core"},
  {"query": "What sections does design.md need, and how long may it be?", "should_trigger": true, "note": "format and sizing limits"},
  {"query": "Split this epic into slices and write down the component boundaries", "should_trigger": true, "note": "the architecture level of the same skill"},
  {"query": "The agent invented its own module layout mid-build again", "should_trigger": true, "note": "the failure mode upfront design prevents"},
  {"query": "Write the use-case table for ABC-204", "should_trigger": false, "note": "spec-authoring owns the spec format"},
  {"query": "How many tests does this new endpoint need?", "should_trigger": false, "note": "dense-testing owns the density floors"},
  {"query": "Why does this scenario only pass on opus?", "should_trigger": false, "note": "harness-eval owns instruction-versus-model diagnosis"}
]
```

- [ ] **Step 6: Verify**

```bash
make validate && make eval-dry
wc -l plugins/sdlc/skills/program-design/SKILL.md
```

Expected: `✓ skills/program-design/SKILL.md`, `✓ program-design  trigger:4  no-trigger:3`, and a
line count between 75 and 105.

- [ ] **Step 7: Commit**

```bash
git add Makefile plugins/sdlc/skills/program-design
git commit -m "feat(skills): add program-design — arch and design artefact formats (SDLC-001-a)"
```

---

## Task 2: `/sdlc:design`

**Files:**
- Create: `plugins/sdlc/commands/design.md`
- Modify: `Makefile:10`
- Modify: `plugins/sdlc/templates/CLAUDE.md` (router table)
- Modify: `plugins/sdlc/hooks/session-start` (the pipeline block, currently lines 23–32)

**Interfaces:**
- Consumes: the `program-design` skill and `references/design-template.md` from Task 1.
- Produces: `specs/<TICKET>/design.md`, committed. The command name `design` is the phase name
  Task 3 adds to `ALL_PHASES`, so the prompt the runner builds (`/sdlc:design <TICKET>`) resolves.

- [ ] **Step 1: Register the command and watch validation fail**

```bash
sed -i 's/^COMMANDS := .*/COMMANDS := init spec mockup design implement qa ship/' Makefile
make validate
```

Expected: FAIL — `✗ commands/design.md MISSING`.

- [ ] **Step 2: Write the command**

Create `plugins/sdlc/commands/design.md`, 95–130 lines. Frontmatter exactly:

```yaml
---
description: Turn an approved spec into a committed program design at specs/<TICKET>/design.md — components, exact signatures, the call graph, the contract changes, and an ordered list of vertical slices whose declared file scope binds the build. The phase the aisdlc queue runs before /sdlc:implement. Use to design a ticket before any code is written, or to refresh a design whose spec changed.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
---
```

Body, following the structure of `commands/implement.md`:

- Opening: `$ARGUMENTS` is the ticket id. **Read `.claude/sdlc.md` first** — specs directory,
  contract directory, ADR location, stacks. **Load the `program-design` skill.** State the
  contract of this phase in three lines: it writes one document and no code; it is not a gate,
  because the spec is the gate; a design nobody can compare a diff against is worthless, so
  every component gets a file and every entry point gets a signature.
- `## Phase 0: Gate on the spec [HARD STOP]` — first action is to read
  `specs/<TICKET>/spec.md`, nothing else. Refuse with one line and write no file if: the file is
  missing (`no spec at specs/<TICKET>/spec.md — run /sdlc:spec <TICKET>`), `status:` is not
  `approved` (`spec is <status>; a human must approve it`), or unchecked `Open questions` remain
  (`open questions block execution`). Same wording as `implement.md:29-42` — the two gates must
  read identically.
- `## Phase 1: Ground it in the code` — read the files named in the spec's `Context`; read the
  one playbook the project's router names for this task; find the nearest sibling implementation
  and mirror its layering; resolve the contract operations and the ADRs that constrain the
  change. If `specs/<EPIC>/arch.md` exists for this ticket's epic, read it and treat its
  component boundaries as given. Output a 3–5 bullet grounding summary.
- `## Phase 2: Write the design` — write `<specs dir>/<TICKET>/design.md` from the skill's
  template. Rules, imperative: exact signatures, no bodies; real symbol names in the call graph;
  `files:` lists every file the build may touch and nothing speculative; every `UC-<n>` in
  exactly one build-order row; slice 1 runs end to end; ≤ 120 lines. Never write code, never
  write tests, never touch a source file in this phase.
- `## Phase 3: Self-check` — a checklist run against the written file: every UC mapped; every
  component has a file; every new entry point has a signature; `files:` non-empty and every
  existing path in it resolves (`ls` them); nothing in `files:` sits inside the spec's `Out:`
  scope; the document is under its cap. Any failure is fixed here, not left for `implement`.
- `## Phase 4: Commit the design [REQUIRED]` — the queue runs in a throwaway worktree, so an
  uncommitted design does not exist and the next phase starts blind:

```bash
git add specs/<TICKET>/design.md
git commit -m "docs(design): program design for <TICKET>"
git status --porcelain     # must print nothing
```

- `## Phase 5: Hand off` — a report block with the file, the component and slice counts, the
  declared file count, and `Next: /sdlc:implement <TICKET>`.
- `## Not to be confused with` — `/sdlc:arch` (the level above: components across an epic, not
  inside one ticket); the spec (what must be observable, never how); a written implementation
  plan for a human (this one is read by an agent with no context and a fresh session).

- [ ] **Step 3: Add the router row and the session announcement**

In `plugins/sdlc/templates/CLAUDE.md`, inside the **Task Router** table, immediately above the
`Deliver an approved spec end-to-end` row:

```markdown
| Design the code shape for an approved spec | run `/sdlc:design <TICKET>` |
```

In `plugins/sdlc/hooks/session-start`, inside `context_raw`, immediately above the
`/${NAME}:implement` line:

```
  /${NAME}:design <TICKET>  → specs/<TICKET>/design.md — signatures, call graph, slice order
```

- [ ] **Step 4: Verify**

```bash
make validate
wc -l plugins/sdlc/templates/CLAUDE.md          # must stay ≤ 90
bash -n plugins/sdlc/hooks/session-start && plugins/sdlc/hooks/session-start | jq -r '.additional_context' | grep design
```

Expected: all validate checks pass, the template is under budget, and the injected context names
the new command.

- [ ] **Step 5: Commit**

```bash
git add Makefile plugins/sdlc/commands/design.md plugins/sdlc/templates/CLAUDE.md plugins/sdlc/hooks/session-start
git commit -m "feat(commands): add /sdlc:design, the program design phase (SDLC-001-a)"
```

---

## Task 3: The `design` queue phase

**Files:**
- Modify: `evals/harness/selftest.sh` (the block at lines 56–69)
- Modify: `evals/harness/stub-claude`
- Modify: `plugins/sdlc/bin/aisdlc` — line 28, line 452, line 544/547, line 606, `cmd_help` ~708
- Test: `make selftest`

**Interfaces:**
- Consumes: `/sdlc:design` from Task 2 — the phase name and the command name must match exactly.
- Produces: default `phases == ["design","implement","qa","ship"]`; `design.log` in the task dir;
  `design.md` copied out of the worktree beside `qa-report.md`.

- [ ] **Step 1: Write the failing assertions**

In `evals/harness/selftest.sh`, in the block `every requested phase runs, in order`, after the
`status is done` assertion (line 62) and before the `implement.log` assertion, insert:

```bash
[ "$(task_field "$R" '.phases | join(" ")')" = "design implement qa" ] \
    && ok "default phases start with design" \
    || bad "phases" "$(task_field "$R" '.phases | join(" ")') — expected 'design implement qa'"
```

and after the `diff collected` assertion (line 69) append:

```bash
[ -f "$D/design.log" ] && ok "design ran" || bad "design" "no design.log"
[ -f "$D/design.md" ] && ok "design collected" || bad "artifacts" "design.md not copied out"
git -C "$R" ls-tree -r --name-only "$(task_field "$R" .branch)" 2>/dev/null \
    | grep -qx "specs/SBX-1/design.md" \
    && ok "design.md committed on the branch" \
    || bad "design commit" "design.md is not in the branch tree — it would vanish with the worktree"
```

- [ ] **Step 2: Run the selftest to verify it fails**

```bash
make selftest
```

Expected: FAIL — `phases: implement qa — expected 'design implement qa'`, `design: no design.log`.

- [ ] **Step 3: Teach the stub to answer the design prompt**

In `evals/harness/stub-claude`, in the `case "$prompt" in` block, immediately before the
`/implement*)` case:

```bash
    /design*)
        mkdir -p "specs/$ticket"
        {
            echo "---"
            echo "ticket: $ticket"
            echo "spec: specs/$ticket/spec.md"
            echo "files:"
            echo "  - pkg/stub.go"
            echo "  - pkg/stub_test.go"
            echo "---"
            echo
            echo "# Design — $ticket"
            echo
            echo "## Build order"
            echo
            echo "| slice | UC ids | delivers | observable proof |"
            echo "|---|---|---|---|"
            echo "| 1 | UC-1 | Stub() returns a non-empty string | TestStub_UC1 |"
        } > "specs/$ticket/design.md"
        commit "docs(design): program design for $ticket"
        ;;
```

Also extend the header comment's behaviour list so `ok` reads
`design + implement + qa succeed and commit`.

- [ ] **Step 4: Add the phase to the runner**

Four edits in `plugins/sdlc/bin/aisdlc`:

```bash
# line 28
ALL_PHASES="design implement qa ship"

# line 452 — artefact collection, above the qa-report.md line
[ -f "$wt/$specs_dir/$ticket/design.md" ]    && cp "$wt/$specs_dir/$ticket/design.md" "$dir/"

# line 606 — cmd_logs
for f in "$dir"/run.log "$dir"/design.log "$dir"/implement.log "$dir"/qa.log "$dir"/ship.log; do
```

and in `cmd_status`, widen the phase-initials column from `%-6s` to `%-8s` (line 547 and the
header printf above it) so `d·i·q·s` still aligns.

In `cmd_help`, replace the sentence at lines 708–711:

```
How it works: one git worktree per task, branched off <base>, then four headless
\`claude -p\` calls (/$PLUGIN_NAME:design → :implement → :qa → :ship) with a fresh context
each. Success leaves a draft PR labelled \`$BUILTIN_LABEL\`. Failure keeps the worktree so you
can read what happened.
```

and add one line to the `add` flag list:

```
      --phase <list>    phases to run (default: design,implement,qa,ship)
```

- [ ] **Step 5: Run the selftest and the validator**

```bash
make selftest && make validate
```

Expected: every selftest case passes, including the three new ones; `shellcheck clean`.

- [ ] **Step 6: Commit**

```bash
git add plugins/sdlc/bin/aisdlc evals/harness/selftest.sh evals/harness/stub-claude
git commit -m "feat(runner): run design as the first queue phase (SDLC-001-a)"
```

---

## Task 4: `implement` and `qa` bound to the design

**Files:**
- Modify: `plugins/sdlc/commands/implement.md` — Phase 0 (lines 29–42), Phase 1 (45–58),
  Phase 2 (62–82), Phase 3 (86–96), Phase 4 (100–124)
- Modify: `plugins/sdlc/commands/qa.md` — Phase 1 (25–36), Phase 3 (64–79), Phase 5 (100–111)
- Modify: `plugins/sdlc/agents/auto-qa.md` — order of work (6–28), gap taxonomy (30–42),
  report format (44–67)

**Interfaces:**
- Consumes: `design.md` frontmatter `files:` and its `## Build order` table (Task 1), committed by
  the design phase (Task 3).
- Produces: the `## Design conformance` section of `qa-report.md` that Task 5's scenario and
  Task 11 both rely on; amended `files:` entries carrying a reason.

- [ ] **Step 1: Bind `implement` to the design**

Four edits in `plugins/sdlc/commands/implement.md`:

1. Phase 0, after the four existing refusal bullets, add one sentence: `specs/<TICKET>/design.md`
   is read next when it exists; when it does not — a task queued without the `design` phase —
   proceed exactly as before and do not refuse for its absence.
2. Phase 1, as step 2: read `design.md` in full. Its `files:` list is the file scope for this
   run; its `## Signatures` are the declarations to write; its `## Call graph` is the wiring; its
   `## Build order` replaces the UC ordering decision.
3. Phase 2, replace the ordering sentence ("Order the UCs walking-skeleton first…") with the
   slice loop, stated imperatively: work the build-order table top to bottom, one slice at a
   time; per slice, write the test carrying each of its `UC-<n>` ids, confirm it fails on the
   assertion, implement the minimum, run it, then commit with the slice's UC ids in the message.
   Never start slice *n+1* while slice *n* is red — that is Phase 4. Add the scope rule: touching
   a file outside `files:` requires amending `files:` in the same commit with a one-line reason;
   a file inside the spec's `Out:` scope is never amendable and is always Phase 4.
4. Phase 3 self-check, add two bullets: every build-order slice has at least one commit naming
   its UC ids; `git diff --name-only <base>...HEAD` contains no path outside the final `files:`
   list (excluding `specs/`).
5. Phase 4, add to the hard-stop list: a design that contradicts the spec, and a required file
   inside `Out:` scope.

- [ ] **Step 2: Teach QA to check conformance**

In `plugins/sdlc/agents/auto-qa.md`:

- Order of work: insert a step between "Read the spec first" and "Then read the diff" — read
  `specs/<TICKET>/design.md` when it exists and write down the declared file list and the slice
  order *before* reading the diff.
- Gap taxonomy: add three rows — a file in the diff that no `files:` entry declares and no
  amendment explains (**blocking**); a `files:` amendment with no reason; a signature in the
  design that the code does not implement, or a public symbol the design never declared.
- Report format: add, between `## UC coverage` and `## Test suites`:

```markdown
## Design conformance
| check | result |
|-------|--------|
| declared files touched | 4/4 |
| undeclared files touched | 1 — `internal/audit/log.go` (no amendment) |
| scope amendments | 1 — `+ internal/httpapi/errors.go` "shared envelope lives here" |
| signatures implemented | 6/6 |
```

  and, after `## Findings`, a section whose absence is itself a defect:

```markdown
## Skillify candidates
<findings whose cause is a missing or weak instruction, one line each: the finding, and the tier
that should have prevented it — rule, playbook, or invariant. Or "none".>
```

  State the rule that keeps this honest: a candidate is a *proposal*, never a written rule —
  `auto-qa`'s only write remains `specs/<TICKET>/qa-report.md`.
- In `qa.md`: Phase 1 gains "read the design before the diff, when one exists"; Phase 3 gains the
  two new sections in the report and one verdict rule — an undeclared file with no amendment is a
  blocking finding, so the verdict is `GAPS`; Phase 5's hand-off gains
  `recurring finding → /sdlc:skillify <TICKET>`.

- [ ] **Step 3: Verify**

```bash
make validate && make selftest
grep -c 'design.md' plugins/sdlc/commands/implement.md plugins/sdlc/commands/qa.md plugins/sdlc/agents/auto-qa.md
grep -n 'Design conformance\|Skillify candidates' plugins/sdlc/agents/auto-qa.md
```

Expected: validate and selftest green; every file references `design.md` at least twice; both new
report sections present. (The stub does not exercise these instructions — Task 5's scenario does.)

- [ ] **Step 4: Commit**

```bash
git add plugins/sdlc/commands/implement.md plugins/sdlc/commands/qa.md plugins/sdlc/agents/auto-qa.md
git commit -m "feat(commands): bind implement and qa to the committed design (SDLC-001-a)"
```

---

## Task 5: Eval scoring for the declared scope

**Files:**
- Create: `evals/harness/score.sh`
- Create: `evals/harness/scenarios/go-design-scope/spec.md`
- Create: `evals/harness/scenarios/go-design-scope/scenario.json`
- Modify: `evals/harness/run.sh` (delete lines 72–200, source `score.sh` instead)
- Modify: `evals/harness/selftest.sh` (new offline scorer case)
- Modify: `Makefile:7-9` (`SCRIPTS`) and `Makefile:64-68` (shellcheck list)
- Modify: `.github/workflows/validate.yml` (shellcheck list)

**Interfaces:**
- Consumes: `design.md` frontmatter `files:` (Task 1); the committed `design.md` (Task 3).
- Produces: two additive `scenario.json` assertion keys — `assert.files_committed` (array of
  paths that must exist in the branch tree) and `assert.scope_from_design` (boolean). `score()`
  keeps its signature `score <sandbox> <scenario_json> <ticket> <base>` and its `A_PASS`/`A_FAIL`
  counters, so `run.sh` needs no other change.

- [ ] **Step 1: Extract the scorer**

Move `assert_ok`, `assert_fail`, the `declare -i A_PASS=0 A_FAIL=0` line, and the whole `score()`
function out of `run.sh` into a new `evals/harness/score.sh` starting with:

```bash
#!/usr/bin/env bash
# score.sh — scenario assertion scoring, sourced by run.sh and by selftest.sh.
#
# Kept separate from run.sh so the assertions can be exercised offline against a hand-built
# branch: a scorer that is only reachable through a paid model run is a scorer nobody tests.
```

In `run.sh`, where the block used to be:

```bash
# shellcheck source=score.sh
. "$HARNESS_DIR/score.sh"
```

Make it executable (`chmod +x evals/harness/score.sh`) and add it to `SCRIPTS` in `Makefile:7-9`,
to the `shellcheck` invocation at `Makefile:64-68`, and to the CI list in
`.github/workflows/validate.yml`.

- [ ] **Step 2: Verify the extraction changed nothing**

```bash
make validate && evals/harness/run.sh --help
```

Expected: `✓ shellcheck clean` including `score.sh`; `--help` prints the usage block.

- [ ] **Step 3: Write the failing offline scorer test**

Append to `evals/harness/selftest.sh`, before its final summary block:

```bash
# --------------------------------------------------------------------------- #
printf '\nthe scorer holds the branch to the design'"'"'s declared file scope\n'
S="$WORK/scope"
rm -rf "$S"; mkdir -p "$S/specs/SBX-9/" "$S/pkg"
git -C "$S" init -q -b master
git -C "$S" config user.email selftest@localhost
git -C "$S" config user.name selftest
git -C "$S" commit -q --allow-empty -m "baseline"
SBASE="$(git -C "$S" rev-parse HEAD)"
{
    echo "---"; echo "ticket: SBX-9"; echo "spec: specs/SBX-9/spec.md"
    echo "files:"; echo "  - pkg/in.go"; echo "---"
} > "$S/specs/SBX-9/design.md"
echo "package pkg" > "$S/pkg/in.go"
echo "package pkg" > "$S/pkg/out.go"
git -C "$S" add -A
git -C "$S" commit -q -m "feat: one declared file and one undeclared"
printf '%s\n' '{"assert":{"scope_from_design":true,"files_committed":["specs/SBX-9/design.md"]}}' \
    > "$S/scenario.json"

( . "$HARNESS_DIR/score.sh"
  score "$S" "$S/scenario.json" SBX-9 "$SBASE" >/dev/null 2>&1
  [ "$A_FAIL" -ge 1 ] ) \
    && ok "undeclared file fails the scope assertion" \
    || bad "scorer" "pkg/out.go left the declared scope and nothing flagged it"

git -C "$S" rm -q pkg/out.go
git -C "$S" commit -q -m "fix: drop the undeclared file"
( . "$HARNESS_DIR/score.sh"
  score "$S" "$S/scenario.json" SBX-9 "$SBASE" >/dev/null 2>&1
  [ "$A_FAIL" -eq 0 ] ) \
    && ok "a diff inside the declared scope passes" \
    || bad "scorer" "a conforming branch was scored as a failure"
```

Run it:

```bash
make selftest
```

Expected: FAIL on both new cases — `scope_from_design` is not implemented yet, so nothing is
asserted and `A_FAIL` stays 0 for the first case.

- [ ] **Step 4: Implement the two assertion keys**

In `evals/harness/score.sh`, inside `score()`, after the `files_changed` loop:

```bash
    # files_committed: an artefact that was never committed vanishes with the worktree.
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        if git -C "$sandbox" ls-tree -r --name-only HEAD 2>/dev/null | grep -qx "$f"; then
            assert_ok "committed: $f"
        else
            assert_fail "committed: $f" "not in the branch tree"
        fi
    done < <(jq -r '.assert.files_committed // [] | .[]' "$scenario_json")

    # scope_from_design: the design's frontmatter files: list is the declared scope. Growth is
    # allowed but must be recorded there, so the check reads the design as the branch left it.
    if [ "$(jq -r '.assert.scope_from_design // false' "$scenario_json")" = "true" ]; then
        local design="$sandbox/specs/$ticket/design.md" declared stray f
        if [ ! -f "$design" ]; then
            assert_fail "design scope" "no specs/$ticket/design.md — the design phase produced nothing"
        else
            declared="$(awk '/^files:[[:space:]]*$/ {f=1; next}
                             f && /^[[:space:]]*-[[:space:]]/ {sub(/^[[:space:]]*-[[:space:]]*/, ""); print; next}
                             f {exit}' "$design")"
            stray=""
            while IFS= read -r f; do
                [ -n "$f" ] || continue
                case "$f" in specs/*) continue ;; esac
                printf '%s\n' "$declared" | grep -qxF "$f" || stray="$stray $f"
            done <<< "$names"
            if [ -z "$declared" ]; then
                assert_fail "design scope" "the design declares no files: — the scope check is vacuous"
            elif [ -n "$stray" ]; then
                assert_fail "design scope" "undeclared:$stray"
            else
                assert_ok "design scope: every changed file is declared"
            fi
        fi
    fi
```

- [ ] **Step 5: Run the selftest and the validator**

```bash
make selftest && make validate
```

Expected: both new scorer cases pass; `shellcheck clean`.

- [ ] **Step 6: Write the scenario spec**

Create `evals/harness/scenarios/go-design-scope/spec.md`. It must satisfy CI's scenario check:
`^status: approved`, `^ticket: SBX-3$`, and at least one `| UC-<n> |` row.

```markdown
---
ticket: SBX-3
title: Accept a deposit into a customer account
status: approved
stacks: [backend]
---

# SBX-3 — Accept a deposit into a customer account

## Problem

`Store.Deposit` exists and is unreachable: the ledger service exposes no way to add funds to an
account, so a deposit can only be made by restarting the process with different seed data.

## Scope

In:
- One endpoint that deposits an amount in minor units into an existing account.

Out:
- Any change to `Store.Deposit` itself, or to `internal/ledger/account.go` — the domain rule
  (amount must be positive) is already correct and is not in scope.
- Withdrawals, transfers, idempotency keys, authentication, the frontend.

## Context

- `services/ledger/internal/httpapi/server.go` — `Routes`, `writeJSON`, `writeError`.
- `services/ledger/internal/ledger/account.go` — `Store.Deposit`, `ErrNotFound`.
- `api/openapi/ledger.yaml` — contract, source of truth. Operation id must be `depositToAccount`.
- Existing tests: `services/ledger/internal/httpapi/server_test.go` has a `do()` helper.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | teller | `POST /v1/accounts/acc-1002/deposit` with `{"amount":2500}` | 200 with `{"id":"acc-1002","balance":2500,"currency":"EUR"}` — balance an integer in minor units | integration |
| UC-2 | teller | `POST /v1/accounts/acc-1002/deposit` with `{"amount":0}` | 400 with the shared error envelope, code `invalid_amount`, and the balance unchanged | integration |
| UC-3 | teller | `POST /v1/accounts/acc-9999/deposit` with `{"amount":100}` | 404 with the shared error envelope and code `account_not_found`; nothing else in the body | integration |

## Non-functional

- The balance is serialised as a JSON number with no decimal point. Never a float, never a
  formatted string.
```

- [ ] **Step 7: Write the scenario assertions**

Create `evals/harness/scenarios/go-design-scope/scenario.json` exactly:

```json
{
  "name": "go-design-scope",
  "ticket": "SBX-3",
  "description": "A design phase ahead of the build. Exercises /sdlc:design as a queue phase: the design must be committed, declare its file scope, and the implementation must stay inside it — including keeping out of internal/ledger/account.go, which the spec puts out of scope.",
  "phases": "design implement qa",
  "assert": {
    "commands": ["make verify"],
    "uc_ids": ["UC-1", "UC-2", "UC-3"],
    "test_paths": ["services/ledger"],
    "diff_contains": ["/v1/accounts/\\{id\\}/deposit", "depositToAccount"],
    "diff_absent": ["float64\\(.*Balance"],
    "files_changed": ["api/openapi/ledger.yaml"],
    "files_committed": ["specs/SBX-3/design.md"],
    "scope_from_design": true,
    "min_test_funcs": 7,
    "no_skips": true,
    "qa_verdict": "PASS"
  }
}
```

- [ ] **Step 8: Verify the scenario is well-formed**

```bash
make validate
make sandbox && ls /tmp/aisdlc-sandbox/specs
grep -q '^status: approved' evals/harness/scenarios/go-design-scope/spec.md && echo ok
```

Expected: `✓ evals/harness/scenarios/go-design-scope/scenario.json`; the sandbox lists `SBX-3`
beside `SBX-1` and `SBX-2` (`make sandbox` copies every scenario spec, so no Makefile change is
needed).

- [ ] **Step 9: Commit**

```bash
git add evals/harness Makefile .github/workflows/validate.yml
git commit -m "test(evals): score the design's declared file scope, offline-testable (SDLC-001-a)"
```

---

## Task 6: `/sdlc:arch`

**Files:**
- Create: `plugins/sdlc/commands/arch.md`
- Modify: `Makefile:10`
- Modify: `plugins/sdlc/templates/CLAUDE.md` (router table)
- Modify: `plugins/sdlc/hooks/session-start`

**Interfaces:**
- Consumes: `program-design` skill and `references/arch-template.md` (Task 1).
- Produces: `specs/<EPIC>/arch.md` with `slices:` in the frontmatter — the file Task 7 reads.
  Writes no spec and never appears in `ALL_PHASES`.

- [ ] **Step 1: Register and watch validation fail**

```bash
sed -i 's/^COMMANDS := .*/COMMANDS := init spec arch mockup design implement qa ship/' Makefile
make validate
```

Expected: FAIL — `✗ commands/arch.md MISSING`.

- [ ] **Step 2: Write the command**

Create `plugins/sdlc/commands/arch.md`, 95–130 lines. Frontmatter exactly:

```yaml
---
description: Decompose an epic before any spec exists — writes specs/<EPIC>/arch.md with the system context, the component boundaries and their contracts, the decisions and their ADRs, and an ordered table of independently shippable slices. Use when work spans more than one component or would produce more than 3 use cases, or when sibling specs keep re-inventing each other's interfaces.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, WebFetch, Agent
---
```

Body:

- Opening: `$ARGUMENTS` is an epic id or a description (derive `LOCAL-<slug>` the way
  `spec.md:17-18` does, and say which id you chose). **Read `.claude/sdlc.md` first** — specs
  directory, tracker, contract directory, ADR location. **Load the `program-design` skill.** State
  the boundary in two lines: this command decides *which slices exist and what they expose*; it
  never writes a spec and never writes code.
- `## Phase 0: Is this an epic? [HARD STOP]` — size the work first. Refuse in one line —
  `one spec is one task is one pull request — run /sdlc:spec <TICKET>` — and write nothing when
  the work fits one pull request: 3 or fewer use cases and one stack. Over that threshold,
  continue. Thresholds are numbers, not judgement.
- `## Phase 1: Gather the source` — the tracker rules from `spec.md:31-46`, by reference, not
  restated: follow `.claude/sdlc.md`, never invent ticket content, an unreachable tracker is a
  stop.
- `## Phase 2: Map what exists` — the components this epic touches and the files that own them;
  the contracts already exposed; the recorded decisions that constrain the change. In subagent
  mode, one `Explore` agent per component. Output a 3–5 bullet grounding summary.
- `## Phase 3: Write the architecture` — `<specs dir>/<EPIC>/arch.md` from the template.
  Rules: every component row names the files that own it; every boundary row names its consumers;
  every slice row names a ticket id, what it delivers, what it depends on, and its observable
  proof; the first slice is the walking skeleton that proves the path end to end; a slice that
  cannot ship alone is not a slice — merge it; ≤ 120 lines and ≤ 6 slices, or the epic splits.
- `## Phase 4: Record the decisions` — for every row in the Decisions table that is
  hard to reverse (schema shape, contract break, tenancy, money, IAM), write one ADR at the
  location `.claude/sdlc.md` names, `status: proposed`, linking back to `specs/<EPIC>/arch.md`,
  and cite the file in the table. When the profile says `none`, write no file, keep the table as
  the record, and say so in the report — exactly one line, never a suggestion to create an ADR
  directory.
- `## Phase 5: Hand off` — commit the arch (`docs(arch): component boundaries and slices for
  <EPIC>`), then print the report: slice count, the ADRs written, the open questions blocking
  approval, and `Next:` with one `/sdlc:spec <EPIC>-<letter>` line per slice **in dependency
  order**. Never write those specs here, and never flip anything to `approved`.
- `## Not to be confused with` — `/sdlc:spec` (one slice's observable criteria; this decides what
  the slices are); `/sdlc:design` (the level below: signatures inside one ticket); an ADR (a
  single decision's record, which this command produces but is not).

- [ ] **Step 3: Router row and session announcement**

`plugins/sdlc/templates/CLAUDE.md`, above the `Turn a ticket into a spec` row:

```markdown
| Plan an epic that spans components or slices | run `/sdlc:arch <EPIC>` |
```

`plugins/sdlc/hooks/session-start`, above the `/${NAME}:spec` line:

```
  /${NAME}:arch <EPIC>      → specs/<EPIC>/arch.md — component boundaries and slice order
```

- [ ] **Step 4: Verify**

```bash
make validate
wc -l plugins/sdlc/templates/CLAUDE.md
grep -c '^|' plugins/sdlc/templates/CLAUDE.md      # router rows: header + separator + ≤ 12
plugins/sdlc/hooks/session-start | jq -r '.additional_context' | grep arch
grep -n 'ALL_PHASES' plugins/sdlc/bin/aisdlc       # must not contain arch
```

- [ ] **Step 5: Commit**

```bash
git add Makefile plugins/sdlc/commands/arch.md plugins/sdlc/templates/CLAUDE.md plugins/sdlc/hooks/session-start
git commit -m "feat(commands): add /sdlc:arch, epic decomposition ahead of the spec (SDLC-001-b)"
```

---

## Task 7: `/sdlc:spec` consumes the architecture

**Files:**
- Modify: `plugins/sdlc/commands/spec.md` — Phase 2 (lines 50–62), Phase 3 (66–86),
  Phase 5 report (102–127)

**Interfaces:**
- Consumes: `specs/<EPIC>/arch.md` written by Task 6 — frontmatter `slices:`, sections
  `## Component boundaries`, `## Out of scope (epic-wide)`.
- Produces: nothing new; existing behaviour is unchanged when no arch exists.

- [ ] **Step 1: Read the epic's architecture when there is one**

In `spec.md` Phase 2, as the first bullet: if the ticket id has an epic prefix (`EPIC-7-a` →
`EPIC-7`) and `<specs dir>/<EPIC>/arch.md` exists, read it first. Its component boundaries are
given, not up for renegotiation: cite the rows this slice touches in `Context`, and copy the
epic-wide `Out of scope` entries into this spec's `Out:` list. If there is no arch, proceed
exactly as today.

- [ ] **Step 2: Name the architecture step when the work is too big for one spec**

In Phase 3, beside the existing split instruction (`spec.md:84-86`), add the threshold: when the
spec would carry more than 3 use cases or touch more than one stack, say so in the report and put
`/sdlc:arch <EPIC>` as step 1 of `Next`, above the approval step — because deciding the slices
after approving a spec means re-approving it. The existing `-a`/`-b` split remains what happens
once the arch exists.

- [ ] **Step 3: Verify**

```bash
make validate
grep -n 'arch.md\|/sdlc:arch' plugins/sdlc/commands/spec.md
wc -l plugins/sdlc/commands/spec.md
```

Expected: at least three references; the file stays under ~160 lines.

- [ ] **Step 4: Commit**

```bash
git add plugins/sdlc/commands/spec.md
git commit -m "feat(commands): ground a slice's spec in its epic architecture (SDLC-001-b, SDLC-002)"
```

---

## Task 8: `/sdlc:skillify`

**Files:**
- Create: `plugins/sdlc/commands/skillify.md`
- Modify: `Makefile:10`
- Modify: `plugins/sdlc/templates/CLAUDE.md`
- Modify: `plugins/sdlc/hooks/session-start`

**Interfaces:**
- Consumes: `specs/<TICKET>/qa-report.md` including its `## Skillify candidates` section
  (Task 4), `specs/<TICKET>/BLOCKED.md`, and the `task-router` skill's tier rules.
- Produces: edits to `.claude/rules/<stack>.md`, `.claude/playbooks/<task>.md` and `CLAUDE.md`,
  each added line carrying `<TICKET>` and the finding number so the trace is greppable in both
  directions.

- [ ] **Step 1: Register and watch validation fail**

```bash
sed -i 's/^COMMANDS := .*/COMMANDS := init spec arch mockup design implement qa ship skillify/' Makefile
make validate
```

Expected: FAIL — `✗ commands/skillify.md MISSING`.

- [ ] **Step 2: Write the command**

Create `plugins/sdlc/commands/skillify.md`, 110–150 lines. Frontmatter exactly:

```yaml
---
description: Turn a QA finding, a BLOCKED reason, or a review comment into a permanent repo instruction — classifies each finding, proposes the tier-correct diff into .claude/rules/, .claude/playbooks/ or CLAUDE.md, and commits it with the finding it came from cited inline. Use after a GAPS verdict, after a review that found the same thing twice, or when the same mistake keeps arriving in different branches.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
---
```

Body:

- Opening: `$ARGUMENTS` is the ticket id, or empty to sweep every committed report. **Read
  `.claude/sdlc.md` first.** **Load the `task-router` skill** — it owns the three tiers, their
  budgets, and the harvesting table. The principle in one line: work done once is work done
  again; an instruction is the only artefact that makes the next task cheaper.
- The interactive-session note, mirroring `init.md:25-33`: writing under `.claude/` needs an
  approval the runtime will not grant an unattended run, and the queue's own permission set
  denies `Write(.claude/**)` (`bin/aisdlc:139-140`). In a headless session, say so in one line,
  write nothing, and exit — this command is not a queue phase and never will be. `--yes` skips
  this command's own review gate, not that approval.
- `## Phase 1: Collect the evidence [HARD STOP]` — first action: read
  `specs/<TICKET>/qa-report.md`; then `BLOCKED.md` if present; then, when `gh` is available,
  `gh pr view --json comments` for the branch. No report and no blocked file → print
  `nothing to skillify for <TICKET> — no qa-report.md and no BLOCKED.md` and stop. Never
  reconstruct findings from the diff: a finding nobody wrote down is an opinion.
- `## Phase 2: Classify every finding` — one table row per finding, and the rule that no finding
  is silently dropped:

```
| finding | evidence | cause | destination |
|---------|----------|-------|-------------|
| 2 | ABC-123 qa-report.md:31 · internal/httpapi/errors.go:44 | the rule file implies the envelope, never states it | rule: .claude/rules/golang.md |
```

  Destinations, and nothing else: `rule` (a stack convention violated in a directory) ·
  `playbook` (a task type done in the wrong order) · `invariant` (true for every task, no
  exception — be strict, the list is short by design) · `one-off` (a defect in this change only).
  Two hard rules: a `one-off` is reported with its reason and written nowhere; and before
  proposing anything, grep the other tiers for the instruction — if it is already stated
  somewhere, the defect is that the file was not loaded, not that the text is missing, so report
  the duplicate with the file that already says it and propose no second copy.
- `## Phase 3: Check for recurrence` — `grep -l "<the finding's shape>" specs/*/qa-report.md`. A
  finding that appears for two or more tickets is a harness defect, not a repo convention: say so
  and name the `evals/harness/scenarios/` entry that would catch it, per the `harness-eval`
  skill.
- `## Phase 4: Propose [GATE]` — print the exact diff per destination file, the line count each
  file will have afterwards against its budget, and stop:

```
⏸ SKILLIFY REVIEW
Reply 'yes' to write these, or say which to drop.
```

  Write nothing before the reply. `--yes` prints `✓ auto-approved (--yes)` and continues.
- `## Phase 5: Write` — one file at a time, confirming each landed. Every added block carries its
  provenance on one line, in the destination's comment syntax:
  `<!-- ABC-123 finding 2: the error envelope was re-invented in a new handler -->`.
  Rules: a rule file stays ≤ 70 lines and keeps its verification block last; a new playbook is
  ≤ 70 lines and gets exactly one router row in `CLAUDE.md`, which stays ≤ 90 lines and ≤ 12
  rows; an instruction is an exact command or an example, never an intention; nothing is added to
  a second tier. Over budget means split the file, never soften the text.
- `## Phase 6: Close the loop` — amend `qa-report.md`'s `## Skillify candidates` section so each
  skillified finding names the file that now prevents it, then commit both together:

```bash
git add .claude/ CLAUDE.md specs/<TICKET>/qa-report.md
git commit -m "docs(rules): harvest <n> finding(s) from <TICKET> into repo instructions"
git status --porcelain     # must print nothing
```

  Then report: what was written, what was refused as a one-off and why, what recurred, and the
  one-line reminder that the next task loads these automatically.
- `## Not to be confused with` — fixing the finding (that is the branch's job; this makes the
  next branch not need it); `/sdlc:init` (writes the hierarchy from scratch, once); an
  organisation policy overlay (`docs/overlay-contract.md` — this writes *this repo's* rules,
  never a shared policy tier).

- [ ] **Step 3: Router row and session announcement**

`plugins/sdlc/templates/CLAUDE.md`, after the `Write or fix tests` row:

```markdown
| Turn a review or QA finding into a repo rule | run `/sdlc:skillify <TICKET>` |
```

`plugins/sdlc/hooks/session-start`, after the `aisdlc add <TICKET>` line:

```
  /${NAME}:skillify <TICKET> → turn its findings into .claude/rules — never do one-off work
```

- [ ] **Step 4: Verify**

```bash
make validate
wc -l plugins/sdlc/templates/CLAUDE.md plugins/sdlc/commands/skillify.md
grep -n 'ALL_PHASES' plugins/sdlc/bin/aisdlc      # must not contain skillify
plugins/sdlc/hooks/session-start | jq -r '.additional_context' | grep skillify
```

- [ ] **Step 5: Commit**

```bash
git add Makefile plugins/sdlc/commands/skillify.md plugins/sdlc/templates/CLAUDE.md plugins/sdlc/hooks/session-start
git commit -m "feat(commands): add /sdlc:skillify — findings become repo instructions (SDLC-001-c)"
```

---

## Task 9: The harvesting section in `task-router`

**Files:**
- Modify: `plugins/sdlc/skills/task-router/SKILL.md` (currently 85 lines; the new section goes
  after `## When to add what`)
- Modify: `plugins/sdlc/skills/task-router/agents/eval-set.json`

**Interfaces:**
- Consumes: the destinations and provenance format from Task 8 — the two must agree exactly.
- Produces: the knowledge `/sdlc:skillify` loads. No new skill, because this skill already owns
  the tiers and a second one on the same subject is the duplication it forbids.

- [ ] **Step 1: Add the section**

Insert `## Harvesting an instruction from a finding`, 14–20 lines, after `## When to add what`:

- The rule, first: a finding fixed only in its branch is a finding you will pay for again. Ask
  where the instruction should have been, not whether the code is now correct.
- A table mapping the evidence to the tier — the same four destinations `/sdlc:skillify` uses:

```
| The finding says | Destination |
|------------------|-------------|
| Code in one directory broke a convention the rest of that directory follows | `.claude/rules/<stack>.md` |
| The steps were right and the order was wrong | `.claude/playbooks/<task>.md` + one router row |
| It would have been wrong in every task, on every stack | A root invariant |
| It was wrong once, for a reason specific to this change | Nowhere — a rule from a one-off makes every future task worse |
```

- Provenance: every harvested block carries the ticket and the finding number in a comment, so
  `grep -rl <TICKET> .claude/` answers "what did this branch teach us" and the rule answers "why
  is this here" without a commit archaeology session.
- Recurrence: the same finding under two tickets is a harness defect — fix the instruction *and*
  add the eval scenario (`harness-eval`), because an instruction with no scenario regresses
  silently.
- Budgets are not negotiable at harvest time: over budget means split the file. A rule nobody
  finishes reading is not enforcement.

- [ ] **Step 2: Extend the trigger set**

Add to `plugins/sdlc/skills/task-router/agents/eval-set.json`:

```json
  {"query": "The reviewer found the same envelope mistake in two branches — where should the rule live?", "should_trigger": true, "note": "harvesting a finding into the right tier"},
  {"query": "Fix the nil pointer in this handler", "should_trigger": false, "note": "fixing a defect, not placing an instruction"}
```

- [ ] **Step 3: Verify**

```bash
make validate && make eval-dry
wc -l plugins/sdlc/skills/task-router/SKILL.md      # ≤ 105
```

- [ ] **Step 4: Commit**

```bash
git add plugins/sdlc/skills/task-router
git commit -m "docs(skills): task-router gains the finding-to-instruction table (SDLC-001-c)"
```

---

## Task 10: Rule↔finding traceability in the QA report

**Files:**
- Modify: `plugins/sdlc/agents/auto-qa.md` (the `## Skillify candidates` section from Task 4)
- Modify: `plugins/sdlc/commands/qa.md` (Phase 3 report rules)

**Interfaces:**
- Consumes: the provenance format from Tasks 8 and 9.
- Produces: `qa-report.md` candidates carrying a finding number, so a harvested rule can cite it
  and `grep` closes the loop in both directions.

- [ ] **Step 1: Number the candidates and name the tier**

In `auto-qa.md`, tighten the `## Skillify candidates` section to a format that can be cited:

```markdown
## Skillify candidates
| finding | the instruction that would have prevented it | tier |
|---------|----------------------------------------------|------|
| 2 | state the shared error envelope explicitly, with an example | rule |
| none | — | — |
```

Add the rule: a candidate names a *finding number from this report*, so the harvested instruction
can cite `<TICKET> finding <n>` and both directions are greppable. `auto-qa` proposes and never
writes an instruction file — its only write stays the report.

- [ ] **Step 2: Make it a report requirement**

In `qa.md` Phase 3, add to the report contents: the `## Skillify candidates` section is required
and `none` is a valid value; a candidate with no finding number is a defect in the report.

- [ ] **Step 3: Verify**

```bash
make validate
grep -n 'Skillify candidates' plugins/sdlc/agents/auto-qa.md plugins/sdlc/commands/qa.md
```

- [ ] **Step 4: Commit**

```bash
git add plugins/sdlc/agents/auto-qa.md plugins/sdlc/commands/qa.md
git commit -m "docs(agents): make skillify candidates citable from the QA report (SDLC-002)"
```

---

## Task 11: Documentation, manifest, version

**Files:**
- Modify: `README.md` (the loop block ~67-80, the command table 101-108, the skills table 112-118)
- Modify: `docs/ai-sdlc.md` (the loop table 18-35, a new leverage subsection, the failure-mode
  table, the metrics table)
- Modify: `docs/overlay-contract.md` (the "Generic work still to land here" list, items 5 and 8)
- Modify: `.claude-plugin/marketplace.json:14`
- Modify: `plugins/sdlc/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` versions
  via `make bump-minor`

- [ ] **Step 1: README**

- The loop block gains the two new steps in order:
  `/sdlc:arch EPIC-7` above the spec line, and after the approval line,
  `aisdlc run` now reading `design → implement → qa → ship`. Add one line under the queue block:
  `/sdlc:skillify ABC-123 → the findings become .claude/rules/, so the next task starts smarter`.
- The command table gains three rows, one line each, in pipeline order (`arch` after `init`,
  `design` after `mockup`, `skillify` last).
- The skills table gains `program-design`.
- In "Why it holds together", add a fourth bullet: **The design is an artefact, not a phase of
  thinking.** `design.md` declares the files the build may touch; QA compares the diff against
  that list, so scope growth is recorded rather than discovered in review.
- Update the "five things" opening count if the enumeration changes — do not leave "five" in
  front of six items.

- [ ] **Step 2: `docs/ai-sdlc.md`**

- The loop table gains rows for `/sdlc:arch` (agent proposes, human owns → `specs/<EPIC>/arch.md`),
  `/sdlc:design` (agent, unattended → `specs/<TICKET>/design.md`), and `/sdlc:skillify` (agent
  proposes, human approves → `.claude/rules/`).
- A new subsection under "Where the leverage actually is", 8–12 lines: **Design before the build,
  as an artefact.** A model optimising for green takes the shortest path to green — a swallowed
  exception, a widened type, a helper in the nearest file — because nothing said where the change
  belonged. The design phase costs one document and makes the file scope mechanical.
  **State the cost honestly:** the measured `$0.59` baseline was three phases; the four-phase
  number is unmeasured until `make harness-eval MODEL=haiku` is run, and this document must
  carry the new table rather than an estimate.
- The failure-mode table gains two rows: *agents drift into unrelated code* → the design declared
  no file scope, or QA is not comparing against it; *the same finding in every branch* →
  nothing was skillified, so the instruction hierarchy is still day-one.
- The metrics table gains one row: *rules harvested per merged PR* — whether the workforce is
  compounding or repeating.

- [ ] **Step 3: `docs/overlay-contract.md`**

Mark the two roadmap items this epic lands, in place, with what actually shipped: item 5 (the
file-scope check after verification) is now the design's `files:` list, checked by QA and scored
by `assert.scope_from_design`; item 8 (the artefact chain ahead of the spec) is now `/sdlc:arch`
and `/sdlc:design`, both committed — the intent-capture half remains open. Do not delete the
items; a roadmap that erases its history cannot be audited.

- [ ] **Step 4: Manifest and version**

`.claude-plugin/marketplace.json:14` — the plugin description's pipeline string becomes
`arch → spec → mockup → design → implement → qa → ship`.

```bash
make bump-minor      # 0.1.0 → 0.2.0, both manifests
```

- [ ] **Step 5: Full verification**

```bash
make validate && make selftest && make eval-dry
grep -rn 'implement → :qa → :ship\|implement qa ship' README.md docs plugins/sdlc/bin/aisdlc
```

Expected: three green runs, and the grep finds no stale three-phase pipeline string outside a
deliberately historical sentence.

- [ ] **Step 6: Commit**

```bash
git add README.md docs .claude-plugin/marketplace.json plugins/sdlc/.claude-plugin/plugin.json
git commit -m "docs: four-phase planning and the skillify loop; bump 0.2.0 (SDLC-001, SDLC-002)"
```

---

## Task 12: Measure it on a cheap model

**Files:** none — this task produces a number and, if the number is bad, a finding.

This is the acceptance gate for the epic, and it costs real money. The harness's own rule applies:
a scenario that fails here is a defect in an instruction file we own, never a reason to raise the
model tier.

- [ ] **Step 1: Run the new scenario on Haiku**

```bash
make harness-eval MODEL=haiku SCENARIO=go-design-scope KEEP=1
```

Expected: `PASS` with every assertion scored, including `committed: specs/SBX-3/design.md` and
`design scope: every changed file is declared`.

- [ ] **Step 2: Run the whole matrix**

```bash
make harness-eval MODEL=haiku
make harness-eval MODEL=sonnet
```

Acceptance bar, unchanged from `harness-eval`: Sonnet passes every scenario, Haiku passes all but
one.

- [ ] **Step 3: Record the real numbers**

Put the per-phase turns, cost and wall clock for `design → implement → qa` into
`docs/ai-sdlc.md`'s measured-baseline table, replacing the three-phase table, and state the
delta against `$0.59` plainly — including if the design phase costs more than it saves.

- [ ] **Step 4: Diagnose any failure before changing anything**

Work the `harness-eval` symptom table. Specifically: a design the implementation ignored means
`implement.md` Phase 1 is not imperative enough; a vacuous `files:` list means the design
command's Phase 3 self-check is too weak; an undeclared file with a plausible reason means the
amendment rule needs an example, not a prohibition.

- [ ] **Step 5: Commit the measurement**

```bash
git add docs/ai-sdlc.md
git commit -m "docs: measured four-phase baseline on haiku and sonnet (SDLC-001)"
```

---

## Task 13: The architecture-test profile field and the per-stack tool table

Implements `specs/SDLC-004/spec.md` UC-7, UC-8, UC-9 and its non-functional tool table.

**Files:**
- Modify: `plugins/sdlc/templates/sdlc.md` — § "Test conventions"
- Modify: `plugins/sdlc/commands/init.md` — Phase 1 ("Verification commands", "Test conventions"),
  Phase 2 item 4, Phase 3's `.claude/sdlc.md` bullet
- Modify: `plugins/sdlc/skills/dense-testing/SKILL.md` — § "Density floors", § "Non-negotiable"

**Interfaces:**
- Produces: the profile field `Architecture tests:` — tool, rule file, command, or `none` — read
  by Tasks 14 and 15; and the density-floor row they enforce.

- [ ] **Step 1: Add the profile field**

In `plugins/sdlc/templates/sdlc.md`, under § "Test conventions":

```markdown
- **Architecture tests:** `none`
  <!-- the tool that enforces dependency direction between components, its rule file, and its
       command — e.g. `deptrac`, `deptrac.yaml`, `vendor/bin/deptrac analyse --no-progress`.
       One default per stack: Java/Kotlin → ArchUnit · PHP → Deptrac · Python → import-linter ·
       TypeScript/JavaScript → dependency-cruiser · Go → depguard inside golangci-lint ·
       C# → NetArchTest. Anything else → none, and the step is skipped entirely. -->
```

The command must join the stack's row in the verification table, not live beside it: a check the
verify command does not run is a check that does not exist.

- [ ] **Step 2: Detect it in `/sdlc:init`**

Phase 1 "Test conventions" gains one question: does this repo already enforce dependency
direction — `deptrac.yaml`, `.dependency-cruiser.js`, `importlinter` in `setup.cfg`/
`pyproject.toml`, an `ArchUnit` test class, `depguard` in `.golangci.yml`? Phase 2 item 4 shows the
answer with the other `none` values. Phase 3 writes it into `.claude/sdlc.md`. When there is none,
the proposal names the one tool that fits the stack as a **recommendation** and writes no rule
file — `/sdlc:init` does not adopt tools on the repo's behalf.

- [ ] **Step 3: Add the density floor**

In `dense-testing`, one row in the § "Density floors" table:

```markdown
| Declared architecture rule (a boundary in `design.md`) | 1 architecture test carrying its rule id |
```

and one clause in § "Non-negotiable", beside "never weaken an assertion": **never relax an
architecture rule to get green** — deleting a rule, widening an allowed-layer list, or adding a
path exception is the same act as loosening an assertion, and it is reported as a contradiction
for a human to decide.

- [ ] **Step 4: Verify**

```bash
make validate
wc -l plugins/sdlc/templates/sdlc.md plugins/sdlc/skills/dense-testing/SKILL.md
grep -n 'Architecture tests' plugins/sdlc/templates/sdlc.md plugins/sdlc/commands/init.md
```

Expected: validate green; `dense-testing` stays under ~125 lines; the field appears in both files.

- [ ] **Step 5: Commit**

```bash
git add plugins/sdlc/templates/sdlc.md plugins/sdlc/commands/init.md plugins/sdlc/skills/dense-testing/SKILL.md
git commit -m "feat(skills): require one architecture test per declared boundary (SDLC-004)"
```

---

## Task 14: `## Architecture rules` in the design

Implements `specs/SDLC-004/spec.md` UC-1 and UC-2.

**Files:**
- Modify: `plugins/sdlc/skills/program-design/references/design-template.md` (Task 1)
- Modify: `plugins/sdlc/skills/program-design/SKILL.md` — § "The design format", § "Sizing"
- Modify: `plugins/sdlc/commands/design.md` — Phase 1, Phase 2, Phase 3 self-check

**Interfaces:**
- Consumes: the profile field from Task 13; `arch.md` § "Component boundaries" when the ticket
  belongs to an epic.
- Produces: the `## Architecture rules` table, whose `rule id` column is what Tasks 15 and 16
  match tests against. Rule ids are `AR-<n>`, stable within a ticket, never renumbered — the same
  convention and the same reason as `UC-<n>`.

- [ ] **Step 1: Extend the design template**

Insert into `references/design-template.md`, between `## Call graph` and
`## Contract and data changes`:

````markdown
## Architecture rules

Dependency directions this change must not break. Omit the section when `.claude/sdlc.md` says
`Architecture tests: none`.

| rule | rule (as a dependency direction) | tool | test |
|------|----------------------------------|------|------|
| AR-1 | `internal/ledger` must not import `internal/httpapi` | depguard | `TestArch_AR1_DomainDoesNotImportTransport` |
````

- [ ] **Step 2: State the rules in the skill**

In `program-design`'s § "The design format", add the two rules that keep the section honest:
every row is a **direction between components**, never a style preference — "no business logic in
controllers" is not a rule a tool can check, "`App\Http` must not be imported by `App\Domain`" is;
and every row names the test that will prove it, because a rule with no test is a comment. In
§ "Sizing", cap it at 5 rules: more than five boundaries in one ticket means the epic's `arch.md`
is doing the deciding, not this design.

- [ ] **Step 3: Wire it into `/sdlc:design`**

Phase 1 reads the profile field and the epic's `arch.md` boundaries. Phase 2 writes the section,
or omits it when the profile says `none` and says so in the report. Phase 3's self-check gains two
lines: every `AR-<n>` names a real tool from the profile, and no rule duplicates one the project's
rule file already enforces.

- [ ] **Step 4: Verify**

```bash
make validate
grep -n 'Architecture rules\|AR-' plugins/sdlc/skills/program-design/references/design-template.md plugins/sdlc/commands/design.md
wc -l plugins/sdlc/skills/program-design/SKILL.md          # still ≤ 105
```

- [ ] **Step 5: Commit**

```bash
git add plugins/sdlc/skills/program-design plugins/sdlc/commands/design.md
git commit -m "feat(commands): design declares architecture rules as testable directions (SDLC-004)"
```

---

## Task 15: `implement` writes the architecture tests; `qa` checks them

Implements `specs/SDLC-004/spec.md` UC-3, UC-4, UC-5, UC-6.

**Files:**
- Modify: `plugins/sdlc/commands/implement.md` — Phase 1, Phase 2 slice loop, Phase 3 self-check,
  Phase 4 stop list
- Modify: `plugins/sdlc/commands/qa.md` — Phase 2 rules, Phase 3 report
- Modify: `plugins/sdlc/agents/auto-qa.md` — gap taxonomy, `## Design conformance` table

**Interfaces:**
- Consumes: `## Architecture rules` (Task 14), the profile's arch-test command (Task 13).
- Produces: two rows in the `## Design conformance` table — `architecture rules tested` and
  `architecture rules relaxed` — which Task 16's scenario asserts on.

- [ ] **Step 1: Make the arch test part of the slice loop**

In `implement.md` Phase 2, inside the per-slice sequence, after writing the UC test: when the
slice introduces a component named in an `AR-<n>` row, add that rule to the project's
architecture-test rule file or test suite **before** the code, with the rule id in the test name,
and confirm it fails for the right reason if the rule is not yet satisfied. Phase 1 adds the
arch-test command to the verification matrix when the profile names one. Phase 3's self-check
gains: every `AR-<n>` in the design has a test carrying its id, greppable the same way UC ids are
(`grep -rho 'AR-[0-9]\+'`).

- [ ] **Step 2: Make relaxing a rule a hard stop**

Phase 4's stop list gains one entry: an architecture rule that cannot be satisfied without
widening it. Widening the rule file is the arch-test equivalent of deleting a test, so it is a
contradiction to report — `BLOCKED.md` — not a cleanup task. State it in those words, because the
shortest path to green is exactly the path this is closing.

- [ ] **Step 3: Teach QA to check it**

`auto-qa`'s gap taxonomy gains two rows: an `AR-<n>` with no test carrying its id (**blocking**);
and an arch rule file weakened in the diff — a deleted rule, a widened allow list, a new path
exception — reported with both sides quoted, **blocking**, exactly as a weakened assertion is.
The `## Design conformance` table gains:

```markdown
| architecture rules tested | 2/2 |
| architecture rules relaxed | 1 — `deptrac.yaml:14` allows `Domain → Http` as of this diff |
```

`qa.md` Phase 2 gains the matching rule: a failing new arch test is a **finding, not a task** —
the same rule that already governs a failing new unit test.

- [ ] **Step 4: Verify**

```bash
make validate && make selftest
grep -n 'AR-' plugins/sdlc/commands/implement.md plugins/sdlc/commands/qa.md plugins/sdlc/agents/auto-qa.md
```

- [ ] **Step 5: Commit**

```bash
git add plugins/sdlc/commands/implement.md plugins/sdlc/commands/qa.md plugins/sdlc/agents/auto-qa.md
git commit -m "feat(commands): architecture rules are tested, never relaxed (SDLC-004)"
```

---

## Task 16: Score it — the Go boundary in the sandbox

**Files:**
- Modify: `evals/fixtures/sandbox/.golangci.yml` (create if absent) — a `depguard` rule forbidding
  `internal/httpapi` imports from `internal/ledger`
- Modify: `evals/fixtures/sandbox/CLAUDE.md` and `evals/fixtures/sandbox/.claude/rules/golang.md`
  — name the arch-test command in the verification block
- Modify: `evals/harness/scenarios/go-design-scope/spec.md` and `scenario.json` (Task 5)
- Modify: `evals/harness/score.sh` — one new assertion key

**Interfaces:**
- Produces: `assert.arch_rules_tested: true` — every `AR-<n>` in the branch's `design.md` has a
  test or rule-file entry carrying its id, mirroring the existing `uc_ids` traceability check.

- [ ] **Step 1: Give the fixture a boundary worth enforcing**

The sandbox already has the right shape: `services/ledger/internal/ledger` is the domain and
`internal/httpapi` is the transport. Add the `depguard` rule that forbids the domain importing
the transport, and put its command in the fixture's verify path so `make verify` runs it. Run
`cd evals/fixtures/sandbox && make verify` — it must stay green on the untouched baseline, or the
rule is wrong.

- [ ] **Step 2: Extend the scenario**

`go-design-scope`'s spec gains one line in `Out:` — the deposit handler must not move query
construction into `internal/ledger` — and `scenario.json` gains `"arch_rules_tested": true` beside
`"scope_from_design": true`.

- [ ] **Step 3: Implement the assertion — test first**

Extend the offline scorer case from Task 5, step 3: a `design.md` carrying an `AR-1` row with no
matching `AR-1` anywhere under the test paths fails; adding the test makes it pass. Run
`make selftest`, watch it fail, then implement the key in `score.sh` next to the `uc_ids` loop —
`grep -rhoE 'AR-?[0-9]+'` over `test_paths` plus the arch rule file named in the design's row.

- [ ] **Step 4: Verify**

```bash
make selftest && make validate
cd evals/fixtures/sandbox && make verify
```

- [ ] **Step 5: Commit**

```bash
git add evals
git commit -m "test(evals): score architecture-rule traceability in the sandbox (SDLC-004)"
```

---

## Self-Review

**Spec coverage.**

| Spec | Requirement | Task |
|---|---|---|
| `SDLC-001-a` | UC-1, UC-2 (design command, refusals) | 2 |
| `SDLC-001-a` | UC-3, UC-4, UC-5 (default phases, logs, artefact, commit) | 3 |
| `SDLC-001-a` | UC-6 (scope amendment), UC-8 (no design → unchanged) | 4 |
| `SDLC-001-a` | UC-7 (design conformance in the report) | 4, 5 |
| `SDLC-001-a` | non-functional: registration, caps, cost measurement | 1, 12 |
| `SDLC-001-b` | UC-1, UC-2, UC-3 (arch artefact, slice rows, hand-off) | 6 |
| `SDLC-001-b` | UC-4, UC-5 (spec consumes arch; unchanged without one) | 7 |
| `SDLC-001-b` | UC-6 (an arch is not queueable) | 6, step 4 grep |
| `SDLC-001-c` | UC-1…UC-7, UC-9 (classify, gate, budgets, duplicates, one-offs, recurrence, headless) | 8 |
| `SDLC-001-c` | UC-8 (report section) | 4, 10 |
| `SDLC-001-c` | non-functional: `task-router` section and triggers | 9 |
| `SDLC-002` | UC-1, UC-2 (threshold both ways) | 7, 6 |
| `SDLC-002` | UC-3, UC-4 (ADRs, and `none`) | 6 |
| `SDLC-002` | UC-5 (build order as slices) | 1 |
| `SDLC-002` | UC-6, UC-7 (slice-ordered commits, stop on red) | 4 |
| `SDLC-002` | UC-8, UC-9 (traceability both directions) | 8, 10 |
| `SDLC-004` | UC-7, UC-8, UC-9 (profile field, detection, density floor) | 13 |
| `SDLC-004` | UC-1, UC-2 (`## Architecture rules`, and `none`) | 14 |
| `SDLC-004` | UC-3, UC-4, UC-5, UC-6 (tests written, rule never relaxed, QA gaps) | 15 |
| `SDLC-004` | non-functional: one tool per stack, run by the verify command | 13, 16 |

**Placeholder scan.** No step says "add error handling", "TBD", or "similar to Task N". Every
JSON, shell and template block is literal. Instruction-file steps state the frontmatter verbatim,
the section list in order, and each section's non-negotiable sentences — the prose in between is
the writer's, constrained by the house-style line in Global Constraints.

**Type consistency.** `design.md` frontmatter is `ticket` / `spec` / `files:` in Tasks 1, 3, 4, 5
and in `stub-claude`. The phase name is `design` in `ALL_PHASES`, the command file name, the log
name, and the scenario's `phases` string. The scorer keys are `assert.files_committed` and
`assert.scope_from_design` in Task 5 and in the scenario. `score()` keeps the signature
`score <sandbox> <scenario_json> <ticket> <base>` used by both `run.sh` and `selftest.sh`. The
report sections are `## Design conformance` and `## Skillify candidates` in Tasks 4, 8 and 10.
Architecture rule ids are `AR-<n>` in Tasks 14, 15 and 16, greppable exactly like `UC-<n>`, and
the scorer key is `assert.arch_rules_tested`.
`COMMANDS` ends the plan as `init spec arch mockup design implement qa ship skillify`; `SKILLS`
as `spec-authoring task-router dense-testing harness-eval program-design`.

**Ordering.** Tasks 1–5 are `SDLC-001-a` and leave the pipeline working on their own; 6–7 are
`SDLC-001-b`; 8–10 are `SDLC-001-c`; 13–16 are `SDLC-004` and depend on Tasks 1, 4 and 5; 11
documents all of it; 12 measures it — run 12 last, after 16, so the measured baseline includes
the architecture tests. Tasks 2, 6 and 8 each edit `Makefile:10`, `templates/CLAUDE.md` and
`hooks/session-start`, and Tasks 4, 15 both edit `implement.md`/`qa.md`/`auto-qa.md` — execute
them sequentially, not in parallel.
