---
description: Generate and maintain the repository's verification map — a committed descriptor saying how to launch, health-check, drive and observe the real application, plus one file per user-facing feature with a drive recipe proven by running it. Creates the map when absent, audits it against source and one live pass when present. Use before QA has to invent how to exercise the app, or when the map has drifted from the product.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
---

# /sdlc:verify-map

A test suite proves the code does what its tests say. This command produces the other proof: a
scripted way to drive the *running* application the way a user does. The output is written for
the next agent — one that has never seen the app, reads the file cold, mid-task, and has to
produce evidence in three commands.

`$ARGUMENTS` is optionally `--dry-run` (report what would change, write nothing).

Read `.claude/sdlc.md` for `Verification map:`, `Integration tests need:`, `End-to-end runner:`,
`Browser descriptor:` and the verification table. This command never asks a question: every
answer comes from the repository, or the run ends `BLOCKED` naming the one fact it could not
observe.

---

## Phase 0: Mode [GATE]

| Condition | Mode |
|---|---|
| `Verification map:` is `none` and `.claude/verify/` has no descriptor | **create** |
| the descriptor exists | **audit** |
| the profile names a path that does not exist | `BLOCKED` — profile points at a missing map |

---

## Phase 1: Interview the repository (create mode) [REQUIRED]

Answer all five from the codebase. A guess here becomes a wrong instruction every later agent
follows.

| Question | Where the answer is |
|---|---|
| **Surface** — what does a user touch: HTTP API, CLI/TUI, web UI, desktop, library? | entrypoints (`cmd/`, `bin/`, `main.*`), route tables, `package.json` `bin`, README quickstart |
| **Launch** — how does it start locally? | `Integration tests need:`, `.aisdlc/test-env/up.sh`, compose files, Makefile targets, package scripts |
| **Drive** — how can an agent interact programmatically? | existing harnesses first: Playwright/Cypress specs, expect scripts, `curl`-able routes, a debug port. Only then a generic recipe: browser descriptor for UI, PTY/tmux for CLI, plain HTTP for services |
| **Observe** — what evidence can be captured? | response bodies, exit codes, logs, DB rows, screenshots, files written |
| **Isolate** — can two instances run side by side? | port and data-dir configuration. If they cannot, the map says so: refusing to double-drive a shared instance beats corrupting it |

If the checkout does not build or start as it is, stop and report that precisely. A map written
against a broken base teaches wrong steps.

---

## Phase 2: Write the descriptor (create mode) [REQUIRED]

Copy `templates/verify/TEMPLATE.md` from this plugin to `.claude/verify/<app>.md` and replace
every placeholder with what Phase 1 observed. No section may keep its example text.

- **Launch** — the exact command, and how to tell it is ready. When `/sdlc:test-env` can boot
  this repo, Launch delegates to it and reads `base_url` from `.aisdlc/test-env/env.json`
  instead of restating the boot sequence. For a short-lived CLI, launch is "build once, then a
  fresh isolated session per drive".
- **Doctor** — one read-only check answering *is this instance worth driving*: process up, port
  owned by us, build current, auth valid.
- **Drive** — real commands and real selectors from this repo, never examples. Stable handles
  (route paths, ARIA labels, `data-testid`, prompt strings) over coordinates and tab order.
- **Evidence** — what to capture, and the path it lands in: `specs/<TICKET>/qa/` when a ticket
  is in play, `.aisdlc/verify/evidence/<utc-timestamp>/` otherwise.
- **Cleanup** — tear down only what this run started, by recorded pid or container id. Never
  `pkill` by name. A sent signal is not a stopped process: poll until it is gone, because a
  graceful shutdown holds the port for seconds and the next run then boots onto a busy port.
  Evidence survives cleanup; scratch state does not.
- **Helpers** — any script the map ships is executable and its invocation appears in the body.

Then seed the feature map: `.claude/verify/features/README.md` as the index plus one file per
user-facing feature, from `templates/verify/feature-TEMPLATE.md`. Three to five features to
start, taken from routes, commands, menus or docs — not every function. Each file keeps the
four headings: `Sub-features`, `How to get to it (user POV)`, `Driving it`, `Gotchas`.

Finally set `Verification map:` in `.claude/sdlc.md` to the descriptor path.

---

## Phase 3: Prove it before handing it over [HARD STOP]

Run the map's own instructions end to end, once: **launch → doctor → drive one mapped feature →
capture evidence → cleanup**, then confirm two things: the evidence still exists at the path the
map names, and the process the launch started is gone.

A generated map that was never executed is a draft, not a deliverable: if this phase cannot
complete, fix the map and repeat, and if it still fails, the verdict is `BLOCKED` and the
descriptor says at the top which step failed. Run cleanup after every failed attempt too, so a
broken iteration does not strand processes and ports.

---

## Phase 4: Audit (audit mode) [REQUIRED]

Edit scope for this whole phase: the map directory only — its descriptor, `features/`, and the
scripts it owns. Product code is never edited here.

1. **Index hygiene** — read `features/README.md`, glob its siblings, fix missing, extra,
   duplicate and dead entries.
2. **Source wave** — one read-only subagent per feature file, dispatched together. Each answers
   "how does this feature work today, from source", cites paths, flags likely drift, and returns
   one live-verification recipe. Children never drive the app and never write files.
3. **Reconcile** — every feature file has a returned summary. Merge recipes into as few app
   states as practical. Spot-check cited drift; do not re-prove clean claims. Sweep recent churn
   (`git log --since=<last map commit> --name-only`) for user-facing surfaces missing from the
   map; a concrete source path is required before calling one missing.
4. **Live pass** — required even when source looks clean. Drive every mapped feature at least
   once, holding three invariants: doctor before the first drive and again after any failed one;
   evidence captured so far survives every cleanup, checked at its path, not assumed; nothing a
   drive started outlives it. A feature that cannot be reached is recorded as
   `unreachable: <concrete prerequisite>` with the route attempted — and if the map omitted that
   prerequisite, that omission is drift.
5. **Triage each finding**

| What you found | Class | Action |
|---|---|---|
| Description or route no longer matches the app | doc drift | fix the feature file |
| Behaviour works but the recipe cannot drive it | harness gap | fix the recipe, then re-drive it live |
| The app itself is broken | product gap | record it in the report; never paper over it in the map |

---

## Phase 5: Commit and report [REQUIRED]

```bash
git add .claude/verify .claude/sdlc.md
git commit -m "chore(verify): <created|updated> the verification map"
git status --porcelain     # must print nothing
```

Under `--dry-run`, skip the commit and print the same report with `would` in place of every
past tense.

```
## Verification map — <app>
Verdict: CREATED | UPDATED | CLEAN | BLOCKED
Descriptor: .claude/verify/<app>.md · Features: <n> (<n> drove clean, <n> unreachable)
Proof: <feature> driven at <evidence path>
Product gaps: <n> (recorded, not fixed)

## Next
CREATED/UPDATED → /sdlc:qa <TICKET> now drives the mapped features instead of improvising
BLOCKED → <the one fact or broken step that stopped it>
```

| Verdict | Means |
|---|---|
| `CREATED` | the map did not exist; it does now, and one feature was driven with it |
| `UPDATED` | drift found and corrected, every correction re-proven live |
| `CLEAN` | every feature covered from source and driven live; nothing worth changing |
| `BLOCKED` | coverage could not finish, or a needed fact could not be observed. Say which |

---

## Rules that do not bend

- **Real user path only.** Drive what a user drives. Internal setters, test-only endpoints and
  seeded fixtures that bypass the feature prove nothing about the feature.
- **The action and the result.** Capture the interaction and the state it produced, plus the
  side effects — rows written, files created, messages sent — not only the final screen.
- **Mocks live at production boundaries.** A mock is acceptable only where the running system
  already isolates that dependency.
- **A named dry-run is not an observed dry-run.** If the map's recipe uses one, prove what it
  skips by watching files, network and git refs.
- **No test is deleted, skipped or weakened by this command**, and it never edits product code.

---

## Not to be confused with

- **`/sdlc:test-env`** — boots the app and writes `env.json`. It answers *is it running*. This
  command answers *how do I drive it and what proves the feature works*, and reuses test-env for
  the boot rather than duplicating it.
- **`/sdlc:integration-tests`** — writes permanent E2E tests in the project's own runner, for UI
  use cases, when one is configured. The map is the layer beneath: it works for an API or a CLI,
  with no runner at all, and it is what tells the test author where the feature lives.
- **`/sdlc:qa`** — judges one ticket against its spec and owns the verdict. It consumes this map;
  it does not maintain it.
