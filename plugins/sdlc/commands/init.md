---
description: Set this repository up for the AI SDLC pipeline — survey the stacks, directories, CI commands and conventions, then generate a CLAUDE.md task router, task-scoped playbooks, path-scoped rules, and the .claude/sdlc.md project profile. Run once per repository, before the first spec. Use also to refresh the setup after the repo's shape changes.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
---

# /sdlc:init

The rest of the pipeline assumes three things exist: a **router** that sends each task to one
playbook, **rules** that attach by path, and a **profile** recording what this repo actually has.
This command produces them by reading *this* repository — not by copying someone else's
conventions, which is the failure mode that makes generic harnesses useless.

## Arguments

`$ARGUMENTS` may contain a hint about what this repo is, if the code makes it ambiguous, and may
contain the flags `--yes` and `--discovery`.

**Check for `--yes` before you start, and decide now which mode you are in:**

- **`--yes` present** → skip the Phase 2 review gate. Print the proposal, state that it was
  auto-approved, and **continue straight into Phase 3 and Phase 4 in the same run.** Stopping after
  the proposal in this mode is a failed run: it produced advice and no files.
- **`--yes` absent** → stop at the Phase 2 gate and wait for a reply.
- **`--discovery` present** → also write the `## Definition of Ready` block into `.claude/sdlc.md`
  (three lines: problem and who has it, observable expected outcome, no blocking open question).
  On an existing profile, replace only that block. Nothing else changes.

Either way you still have to read what came out. An unreviewed router quietly misroutes every task
that follows.

**This command needs an interactive session.** Writing under `.claude/` requires approval that
Claude Code will not grant to an unattended run — deliberately, because agent configuration is
exactly what you do not want rewritten silently. `--yes` skips *this command's* review gate, not
that approval. In a fully headless run, expect the files outside `.claude/` to land and the
playbooks and rules to be refused; Phase 4 will tell you so rather than claiming success.

**Load the `task-router` skill** — it holds the three-tier model, the line budgets this command
must respect, and the rules for writing a router row that a weak model matches correctly.

The templates to start from live in this plugin's `templates/` directory: `CLAUDE.md`,
`playbooks/*.md`, `sdlc.md`, `trackers/*.md` and `browsers/*.md`. Read them, then **rewrite** the
first three for this repo — copying them with the placeholders still in is a failure, not a partial
success. The tracker and browser descriptors are copied **verbatim**: they are executable
integration files, and a local edit belongs in the copy, later.

---

## Phase 1: Survey

Gather facts. Do not write anything yet. In subagent mode, dispatch up to three `Explore` agents in
parallel — one for stacks and layout, one for CI and test conventions, one for contracts,
decisions and existing agent configuration.

**Stacks and layout.** Which languages, where. Manifest files (`go.mod`, `package.json`,
`pyproject.toml`, `Cargo.toml`, `composer.json`, `*.csproj`, `Gemfile`, …), top-level directories,
and what each one holds. Note which directories are vendored or generated — those become
out-of-bounds entries.

**Verification commands.** Follow the discovery order in the `dense-testing` skill's
`references/ci-matrix.md`: CI workflow files first, then the build tool's targets, then pre-commit
config. Extract the **exact** commands with their flags. Check each tool is actually installed and
say which are missing. If a single target runs everything, note it.

**Test conventions.** File naming, location (beside the source or a separate tree), framework per
stack, whether integration tests need a service running, whether there is an end-to-end runner.
Count the existing tests — the number goes in the profile as a baseline.

**Task types.** This is the judgement call that matters most. Read the recent history
(`git log --oneline -100` and the directories those commits touched) and ask: what kinds of change
does this repo actually receive? A library gets "add a public function" and "fix a bug", not "add
an endpoint". Do not propose a row for work this repo has never done.

**Integrations.** Issue tracker, in this order: a GitHub remote **and** an authenticated `gh` →
`github`; an Atlassian MCP server reachable → `jira-mcp` for ticket reads plus `github` or `local`
for PRs; neither → `local`. Never `none` when the repo has commits — `local` costs nothing and
makes the post-ship commands work offline. Browser provider: a `playwright.config.*` → `playwright`;
an `agent-browser` binary on `PATH` → `agent-browser`; otherwise `none`, and say in one line what
installing one would enable. Contract directory (OpenAPI, protobuf, GraphQL schema) or none.
Recorded decisions (an `adr/` directory, a decisions file) or none. A skill holding domain
vocabulary or none.

**Existing configuration.** An existing `CLAUDE.md`, `AGENTS.md`, `.claude/rules/`, or
`.cursor/rules`. **Read them.** Whatever conventions they already encode are inputs, not obstacles.

Report the survey as a compact summary. Flag every fact you could not establish.

---

## Phase 2: Propose the router [GATE]

Present, for approval, before writing anything:

1. **The router table** — one row per task type from the survey, in the developer's words, each
   pointing at exactly one playbook. Under 12 rows. Say which template each playbook derives from,
   and which rows are new playbooks you would write from scratch.
2. **The rules files** — one per stack, with the verification block you discovered.
3. **The invariants** — six to eight, drawn from what this repo evidently already believes (its
   commit message style, its branch protection, its error conventions). Do not invent rules nobody
   here follows.
4. **The profile answers** — tracker kind and descriptor, browser descriptor, contracts, decisions,
   glossary. Show the `none` values explicitly; they are the ones most worth correcting. The specs
   directory is not one of these: it is where the pipeline writes, it defaults to `specs/`, and it
   is never `none`.
5. **What you will not create** and why — a playbook for work this repo does not do is noise that
   makes the router worse.

**Interactive mode** — stop here:

```
⏸ SETUP REVIEW
Reply 'yes' to write these files, or describe what to change.
```

**Write nothing before the reply.** A wrong router is worse than no router: it sends every future
task to the wrong instructions, and nobody notices for weeks.

**Non-interactive mode (`--yes`)** — print `✓ auto-approved (--yes)` and continue immediately to
Phase 3. Do not stop, do not ask, do not end the turn here.

---

## Phase 3: Write

Write the files **one at a time, in this order**, and confirm each one landed before starting the
next. Do not batch them into a plan and announce them as done — a listed file is not a written file,
and writes under `.claude/` can be refused by the runtime.

For each: if it does not exist, write it. If it exists, **show the diff and ask** — never overwrite
silently. `CLAUDE.md` is merged, not replaced: keep the project's own sections, insert the Task
Router near the top, and leave the rest alone.

- `CLAUDE.md` — from `templates/CLAUDE.md`. ≤ 90 lines. No stack conventions here; they belong in
  the rules files.
- `.claude/playbooks/<name>.md` — one per router row, from the matching template, rewritten with
  this repo's real directories, real layering, and real verification commands. ≤ 70 lines each.
  Delete template steps that do not apply here rather than leaving a hedge.
- `.claude/rules/<stack>.md` — `paths:` frontmatter, this stack's conventions as observed in the
  code, and a copy-pasteable verification block at the end. ≤ 70 lines each.
- `.claude/sdlc.md` — from `templates/sdlc.md`, every field answered, `none` where that is the
  truth. **Tracker descriptor** and **Browser descriptor** are paths or `none`, never a kind name.
- `.claude/trackers/<kind>.md` — copied byte-for-byte from `templates/trackers/<kind>.md`; the
  same for `.claude/browsers/<provider>.md` when a provider was chosen. Then run the descriptor's
  **auth-check**; a failure goes in the report, not under the rug.
- `.aisdlc/config.json` — runner defaults: `{"model", "budget", "base", "workers", "label",
  "specs_dir"}`. Pick `base` from the actual default branch.
- `specs/.gitkeep` and `specs/briefs/.gitkeep` — so both directories exist before the first artefact.
- `.gitignore` — append `.aisdlc/` if absent (the runner's state and, under `local`, the tracker's
  files live there and are never committed).
- Labels (`github` only): **ensure-labels** with the profile's PR label, the four pipeline labels
  and the claim label. Six labels, created once, never renamed.

Two rules that keep the result honest: every instruction you write must be one a weak model can
follow without inference — an exact command, not an intention — and nothing goes in two tiers,
because a duplicated instruction that drifts is worse than a missing one.

---

## Phase 4: Verify and hand over

1. **List what actually exists on disk.** `ls CLAUDE.md .claude/playbooks/ .claude/rules/
   .claude/sdlc.md .claude/trackers/ .aisdlc/config.json specs/ specs/briefs/`. Count the playbooks
   against the number of router rows. **If any file is missing, this run failed** — say which files
   are missing and why (a refused write, a tool error), and do not describe the setup as ready. A
   router pointing at playbooks that do not exist is worse than no router: every task follows a
   dangling reference.
2. **Run the verification commands you recorded.** If one fails on a clean checkout, the profile is
   wrong or the repo is red — say which, and do not paper over it.
3. **Check the budgets** — report the line count of every file you wrote against its limit.
4. **Check the routing works.** State which single row a sample task from this repo would match. If
   two rows both plausibly match it, the wording is wrong: fix it now.

Report the outcome as `COMPLETE` only when step 1 finds every file. Otherwise report `INCOMPLETE`
with the exact list of what is missing and the one command the developer should run to finish it.

```
## Set up for AI SDLC
CLAUDE.md (<n> lines) · <n> playbooks · <n> rules files · .claude/sdlc.md · tracker <kind> · browser <provider> · .aisdlc/config.json

## Verification
<each command and its real result>

## Could not determine
<every gap, with what to do about it — do not leave these implied>

## Next
1. Read CLAUDE.md and the playbooks. They are yours now; correct anything that reads wrong.
2. git add CLAUDE.md .claude/ specs/ && git commit
3. Write your first spec:  /sdlc:spec <a small, real ticket>
4. Run it while watching:  /sdlc:implement <TICKET> then /sdlc:qa <TICKET>
5. Only then queue anything: aisdlc add <TICKET>

The first spec you drive by hand teaches you more about this setup than the first ten queued tasks.
```

---

## Not to be confused with

- **`/sdlc:spec`** — writes one spec. This command sets up the repo so specs can be executed.
- **Editing `CLAUDE.md` by hand** — always fine, and expected. This command produces a starting
  point calibrated to the repo; keeping it correct as the repo changes is ordinary maintenance. The
  `task-router` skill covers how.
