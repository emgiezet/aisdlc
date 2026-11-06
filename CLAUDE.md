# Project: aisdlc

The source of two Claude Code plugins shipped through one marketplace: **sdlc** (slash commands,
knowledge skills, agents, templates and the `aisdlc` queue runner that turn an approved spec into
a reviewed PR) and **slop-guard** (hooks that allow, ask or deny an agent's commands and writes,
plus generated anti-pattern skills). Bash for every hook and CLI, Markdown for every instruction
file, YAML/JSON for catalogues and manifests, a little Node for the omp adapters.

## Task Router

Find the row matching your task and read **only** the files it names. Do not preload other
playbooks or rules — loading everything degrades instruction following and burns context you
will need for the code.

| Your task | Read |
|-----------|------|
| Add or change an `/sdlc:` command, an agent, a playbook template or a tracker/browser descriptor | `.claude/playbooks/instruction-file.md` |
| Add or change a knowledge skill under `plugins/sdlc/skills/` | `.claude/playbooks/sdlc-skill.md` |
| Add or change a slop-guard rule, anti-pattern catalogue or linter config | `.claude/playbooks/slopguard-rule.md` |
| Change what a hook allows, asks or denies (guard, slop-guard pre-/stop/session-start, policies) | `.claude/playbooks/hook.md` |
| Change the queue runner `bin/aisdlc` (including `pull`/`loop`) or the eval harness under `evals/` | `.claude/playbooks/queue-runner.md` |
| Release, versioning, plugin manifests, CI workflows | `.claude/playbooks/release-ci.md` |
| Write or fix tests | `.claude/playbooks/testing.md` |
| Deliver an approved spec end-to-end | run `/sdlc:implement <TICKET>` |
| Turn a ticket into a spec (it calls `/sdlc:decompose` when over budget) | run `/sdlc:spec <TICKET>` |
| Review a pull request | run `/sdlc:review <pr#>` |
| Finish a stalled or unreviewed PR | run `/sdlc:autopilot <pr#>` |
| Anything else | this file plus the `.claude/rules/` file for the paths you touch |

`.claude/rules/*.md` are **path-scoped** — they attach automatically to the files you edit, so
you never need to open them from here. Playbooks are **task-scoped**: this table is the only way
in. Keep this table under 12 rows; past that the rows stop being distinguishable and the wrong
one gets picked, which is worse than picking none.

## Layout

- `plugins/sdlc/` — `commands/`, `skills/`, `agents/`, `templates/` (shipped into user repos),
  `hooks/` (`guard`, `session-start`), `bin/aisdlc` (queue runner), `extensions/omp.mjs`, `tests/`
- `plugins/slop-guard/` — `hooks/`, `lib/`, `bin/slopguard`, `rules/` (`catalog.yaml`, policies,
  mappings), `skills/` (mostly **generated** by `scripts/gen-skills`), `configs/`, `tools/`, `tests/`
- `.claude-plugin/`, `.omp-plugin/`, `.grok-plugin/`, `.agents/plugins/` — one marketplace per host
- `evals/harness/` — selftest, stubs, scenarios; `evals/fixtures/sandbox/` — eval fixture, own `CLAUDE.md`
- `docs/` — `ai-sdlc.md` (user guide), `slop-guard-spec.md`, `plans/`, `research/`
- `specs/<TICKET>/` — agent-facing specs: `spec.md`, `qa-report.md`, `qa/`, `mockup/`
- `specs/briefs/` — discovery artefacts that precede a spec
- `.claude/sdlc.md` — this project's AI SDLC profile; `.claude/trackers/` — the tracker descriptor

## Invariants

1. Conventional commits `type(scope): description`, scopes `sdlc`, `slopguard`, `aisdlc`.
   `chore(release): vX.Y.Z` is reserved for the squash commit of a version PR.
2. Never commit to `main`; branch, PR, squash merge. Never force-push. Never edit a `version`
   field by hand — run `make bump-*` on the release branch and validate its PR before merging.
3. All new behaviour needs tests. Never delete, skip or weaken a test to get green; a retired
   test goes in `.claude/retired-tests` with a reason, and only a human adds that line.
4. One rule lives in one file — a skill or command links its neighbour, never restates it. The
   `Makefile` owns the COMMANDS/SKILLS/SCRIPTS lists; both marketplace skill arrays stay identical.
5. Generated files are regenerated, never hand-edited: `plugins/slop-guard/skills/*-antipatterns/`
   and `agent-discipline/` come from `rules/catalog.yaml` via `plugins/slop-guard/scripts/gen-skills`.
6. The framework stays project-agnostic (CI greps for leaked project names). Rule text is written
   from scratch — never copied from Semgrep, SonarSource or OWASP; cite CWE by number and URL.
7. Budgets are enforced by `make validate`: command ≤ 220 lines, playbook template ≤ 70,
   descriptor ≤ 120, `templates/CLAUDE.md` ≤ 90, generated `SKILL.md` ≤ 150 lines / 3000 tokens.
8. Run the verification commands for every stack you touched before calling a task done. They
   live in the `.claude/rules/` file for that stack; `CI= make validate` runs them all.

## Commands

- `CI= make validate` — everything CI's validate job checks (empty `CI` skips `--strict` configs)
- `plugins/slop-guard/tests/run-tests` · `plugins/sdlc/tests/run-tests` — the bash suites
- `make selftest` — queue runner against a stub `claude`, no API calls
- `make eval-dry` — skill trigger sets; `make help` — the rest
- shellcheck is not installed here: `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -S warning <files>`
