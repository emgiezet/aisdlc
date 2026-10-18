# Playbook — Command, agent, template or descriptor

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
Load the `task-router` skill for line budgets and how a weak model reads a row, and
`pipeline-contracts` before touching operations, verdict tokens, labels or the claim lock.

Everything here is an instruction a cheap model executes unattended in someone else's repo.
An instruction that needs inference is a bug, the same as a wrong branch in code.

## Sequence

1. **Copy the nearest sibling.** A new command starts from the command whose shape it shares
   (`decompose.md` for a planning command, `review.md` for one that claims a PR). Frontmatter:
   `description:` with a "Use when/after" sentence, `allowed-tools:` naming only what it runs.
   An agent (`plugins/sdlc/agents/*.md`) carries `name`, `description`, `tools`, `model`.
2. **Name operations, never tools.** Tracker and browser access go through descriptor operations
   (**claim**, **get-pr**, **review-pr** …). A command that calls `gh` or a browser directly is
   wrong even when it works. A new operation goes into `templates/trackers/{TEMPLATE,github,local}.md`
   — all three — and its row in `pipeline-contracts` under `## Operations`.
3. **Exact commands, exact tokens.** Every step a run must take is a command with its flags, or a
   named token from `pipeline-contracts` `## Verdict tokens`. A new token is added there, once.
4. **Link, do not restate.** Severity scale → `code-review`; UC format → `spec-authoring`;
   density → `dense-testing`. Copying their text creates a second source that drifts.
5. **Register a new command** in every place a user or the harness finds it:
   - `Makefile` `COMMANDS :=` (drives the required-file and 220-line checks)
   - `README.md` — the command count on line 5 and the command table
   - `docs/ai-sdlc.md` — where it sits in the loop
   - `plugins/sdlc/hooks/session-start` — the long banner, when the command is user-facing
   - `plugins/sdlc/templates/CLAUDE.md` — a router row only if users route tasks to it
6. **A template or descriptor change reaches existing repos only through `/sdlc:update`.** When
   you add a field, an operation or a config key, check `commands/update.md` re-syncs it.
7. **Templates stay project-agnostic.** Placeholders as `<NAME>`, never an example company.

## Test requirements

Instruction files have no unit tests; the gates are structural plus one live run:

- `CI= make validate` — required files, budgets, descriptor TODO check, frontmatter.
- A changed descriptor operation: exercise it against the `local` tracker through
  `make selftest`, which drives the queue with a stub `claude` and `local` descriptors.
- A changed command: run it once headless on the cheapest model and read what it did —
  `claude -p "/sdlc:<cmd> <args>" --plugin-dir plugins/sdlc --model haiku --max-budget-usd 1`.
  A step the model skipped or improvised is an instruction to rewrite.

## Verify

The verification block in `.claude/rules/instructions.md`, plus `make selftest` when a
descriptor or the queue's phase prompts changed.

## Done when

Sibling-shaped, operations and tokens named from `pipeline-contracts`, registered everywhere in
step 5, within budget, `CI= make validate` green, and one live run read end to end.
