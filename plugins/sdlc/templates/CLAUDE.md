# Project: <NAME>

<One or two sentences: what this system is and who uses it. Then the stacks, concretely —
"Go services, TypeScript frontend, PostgreSQL", not "modern web stack".>

## Task Router

Find the row matching your task and read **only** the files it names. Do not preload other
playbooks or rules — loading everything degrades instruction following and burns context you
will need for the code.

| Your task | Read |
|-----------|------|
| <task, in the words a developer would use> | `.claude/playbooks/<name>.md` |
| <one row per task type this repo actually has> | `.claude/playbooks/<name>.md` |
| Write or fix tests, chase coverage | `.claude/playbooks/testing.md` |
| Deliver an approved spec end-to-end | invoke the `implement` skill for the ticket |
| Turn a ticket into a spec | invoke the `spec` skill for the ticket |
| Anything else | this file plus the `.claude/rules/` file for the paths you touch |

`.claude/rules/*.md` are **path-scoped** — load the applicable file(s) for the paths you touch.
Claude and Grok attach them automatically; on Codex, open them explicitly. Playbooks are **task-scoped**: this table is the only way
in. Keep this table under 12 rows; past that the rows stop being distinguishable and the wrong
one gets picked, which is worse than picking none.

## Layout

- `<dir>/` — <what lives here>
- `specs/<TICKET>/` — agent-facing specs: `spec.md`, `qa-report.md`, `mockup/`
- `.claude/sdlc.md` — this project's AI SDLC profile (tracker, contracts, verify commands)

## Invariants

<Six to eight rules that hold for every task, no exceptions. Delete what does not apply; do
not pad. Each one should be a rule someone has actually broken.>

1. Conventional commits: `type(scope): description`.
2. Never commit to <default branch>. Never commit secrets, `.env` files, or credentials.
3. All new functionality requires tests. Never delete, skip, or weaken a test to get green.
4. <the contract rule, if this project has contracts — otherwise delete>
5. <the money/precision rule, the tenancy rule, the audit rule — whatever bites here>
6. Run the verification commands for every stack you touched before calling a task done. They
   live in the `.claude/rules/` file for that stack.

## Commands

<The handful a newcomer needs: how to run the tests, the linters, the app locally.>
