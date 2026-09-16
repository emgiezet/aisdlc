# Specification: AISDLC Technical Planning & Architecture Loop

**Ticket ID:** SDLC-002  
**Status:** draft  
**Author:** AI SDLC Architect (Grounded in Dex Horthy & Garry Tan Findings)  
**Target Component:** `aisdlc` plugin (`plugins/sdlc/`)  

---

## 1. Overview & Context

Recent research on software factories (Dex Horthy, HumanLayer [20, 22, 28, 29]) highlights that relying solely on automated test loops (*harness engineering*) leads to severe "code rot" and architectural degradation over time. Coding models trained on binary pass/fail test benchmarks optimize for passing tests by injecting bad architectural workarounds (e.g., spurious `try-catch` blocks, unsafe type casts, shotgun surgery) [33]. This creates long-term technical debt and turns pull request reviews into an exhausting burden [21, 38].

To prevent this decay, AISDLC adopts a 4-phase technical planning framework prior to code generation:
1. **Product Review:** `/sdlc:spec` (use-case table) and `/sdlc:mockup` (UI mockup) [44, 46].
2. **System Architecture:** `/sdlc:arch` — macro-level component contracts, data models, and Architectural Decision Records (ADRs) [36].
3. **Program Design:** `/sdlc:design` — micro-level type definitions, method signatures, call graphs, and ordered vertical slices [36, 37].
4. **Vertical Slice Execution:** Iterative, sequential implementation and test verification per slice within `/sdlc:implement` [37].

Additionally, following Garry Tan's organizational principles (*"Never do one-off work — skillify it"* [14, 15]), AISDLC incorporates **`/sdlc:skillify`**, which distills QA findings and code review audits from `qa-report.md` into permanent repository rules in `.claude/rules/` [4, 14, 42]. The Task Router acts as the "Librarian", automatically routing these learned rules into context for future tasks [4, 12, 40].

---

## 2. Requirements & Use Cases

| UC ID | Title | Description | Acceptance Criteria (Observable & Testable) |
| :--- | :--- | :--- | :--- |
| **UC-1** | System Architecture Generation (`/sdlc:arch`) | Generate macro architecture documentation for tickets tagged as large or multi-component (`scale: large` or >3 use cases). | Executing `/sdlc:arch <TICKET>` reads `specs/<TICKET>/spec.md` and generates `specs/<TICKET>/architecture.md` containing: (a) Component Contracts & Boundaries, (b) Data Models & Schema Changes, (c) External/Internal API Interfaces, and (d) Architectural Decision Records (ADR) with trade-offs. |
| **UC-2** | Program Design & Call Graph Generation (`/sdlc:design`) | Create granular technical design, method signatures, call graphs, and vertical slice execution plans. | Executing `/sdlc:design <TICKET>` reads `spec.md` and `architecture.md` (if present) and outputs `specs/<TICKET>/design.md` containing: (a) Class/Module Interfaces & Method Signatures, (b) Data flow & Call Graphs, and (c) Ordered Vertical Slices (Slice 1, Slice 2, ...) with specific test assertions for each. |
| **UC-3** | Mandatory Technical Plan Loading in `/sdlc:implement` | Enforce reading of `architecture.md` and `design.md` during implementation. | When `/sdlc:implement <TICKET>` starts, the task router checks for `specs/<TICKET>/design.md`. If present, it loads `design.md` and `architecture.md` into the agent context before generating any code or tests. If missing for a `scale: large` ticket, execution halts with a requirement error. |
| **UC-4** | Sequential Vertical Slice Execution | Execute implementation in discrete, verified steps rather than a single monolithic leap. | During `/sdlc:implement`, the agent implements vertical slices sequentially according to `design.md`. For each slice (Slice 1..N), it writes unit/integration code, runs tests, and updates the checkpoint checklist in `design.md` before proceeding to the next slice. |
| **UC-5** | Post-QA Rule Distillation (`/sdlc:skillify`) | Extract architectural anti-patterns and QA findings into permanent repository rules. | Executing `/sdlc:skillify <TICKET>` parses `specs/<TICKET>/qa-report.md`. If findings contain status `GAPS` or architectural flags (e.g., bad try-catch workarounds, missing assertions), it distills them into a markdown rule under `.claude/rules/<topic>.md`. |
| **UC-6** | Task Router Context Integration ("Librarian") | Automatically inject skillified rules into future agent tasks based on file paths and domain matching. | Running `/sdlc:init` or invoking the Task Router matches target modified file paths against `.claude/rules/*.md`. The router attaches matching rules to the context of `/sdlc:implement` and `/sdlc:qa` sessions. |

---

## 3. Negative & Edge Cases

| Case ID | Scenario | Expected Behavior |
| :--- | :--- | :--- |
| **NEG-1** | Missing Spec Approval for `/sdlc:arch` or `/sdlc:design` | Invoking `/sdlc:arch` or `/sdlc:design` on a ticket with `spec.md` in `status: draft` halts with: `ERROR: Ticket spec.md must be status: approved before architecture/design planning.` |
| **NEG-2** | Monolithic Code Generation Bypass | If an agent attempts to implement all vertical slices in one commit without running intermediate test checks, the PreToolUse hook blocks completion and prompts: `BLOCKED: Vertical Slice execution requires test verification per slice.` |
| **NEG-3** | Duplicate Rule Generation in `/sdlc:skillify` | If a rule file for the target anti-pattern already exists in `.claude/rules/`, `/sdlc:skillify` appends the new example and countermeasure to the existing file rather than creating a duplicate file. |
| **NEG-4** | Clean QA Report Execution | Running `/sdlc:skillify` on a ticket with `qa-report.md` having `PASS` and zero architectural gaps outputs `INFO: No architectural gaps in qa-report.md. No new rules added.` |

---

## 4. Architecture & Complete Lifecycle Workflow

```
1. /sdlc:spec TICKET-101      → specs/TICKET-101/spec.md (Use Cases UC-1..N, status: draft)
2. /sdlc:mockup TICKET-101    → specs/TICKET-101/mockup.html (Validation with stakeholders)
   ↓ (Human approves spec: status: approved)
3. /sdlc:arch TICKET-101      → specs/TICKET-101/architecture.md (Contracts, ADRs, Data Models)
4. /sdlc:design TICKET-101    → specs/TICKET-101/design.md (Signatures, Call Graphs, Vertical Slices)
   ↓ (Human reviews technical plan or auto-queues)
5. /sdlc:implement TICKET-101 → Sequential implementation per Vertical Slice + dense tests
6. /sdlc:qa TICKET-101        → specs/TICKET-101/qa-report.md (Independent verification: PASS/GAPS)
7. /sdlc:skillify TICKET-101  → Distills QA gaps into .claude/rules/<topic>.md
8. /sdlc:ship TICKET-101      → Draft Pull Request with QA verdict & risk profile
```

---

## 5. Verification & Testing Strategy

1. **Self-Test assertions (`make selftest`):**
   - Verify that `/sdlc:arch`, `/sdlc:design`, and `/sdlc:skillify` commands parse arguments and execute template population cleanly [49].
   - Verify that `design.md` schema includes call graph and vertical slice checklist structures.
2. **Harness Evaluation (`harness-eval`):**
   - Run a benchmark scenario on Haiku model (`aisdlc run --model haiku`) [41, 47, 49].
   - Measure code maintainability metrics: 0 spurious try-catch blocks, 100% adherence to call graph interfaces, and complete execution of vertical slice checkpoints.
