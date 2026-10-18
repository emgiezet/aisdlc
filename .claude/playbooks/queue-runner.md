# Playbook — Queue runner `bin/aisdlc` and the eval harness

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
`plugins/sdlc/bin/aisdlc` runs approved specs unattended on someone else's machine and money.
A bug here ships untested code or spends a budget nobody watched.

## Map

- Subcommands are `cmd_<name>()` (`add`, `run`, `status`, `inbox`, `logs`, `retry`, `cancel`,
  `clean`, `scope_check`); dispatch is at the bottom of the file.
- Phases: `ALL_PHASES` (spec tasks) and `ISSUE_PHASES` (bug issues). Each phase is a fresh
  headless run in its own worktree; phases hand over through files in `specs/<TICKET>/`.
- `run_verify` is the deterministic gate before ship: repo `verify` commands, UC traceability,
  no deleted/skipped tests. Unconfigured is FAIL, never skip.
- Defaults `BUILTIN_*`; precedence: CLI flag > `.aisdlc/config.json` > env (`AISDLC_*`) > built-in,
  resolved by `resolve_default`. State lives in `.aisdlc/` (gitignored); queue pops are `flock`ed.
- `evals/harness/`: `selftest.sh` with `stub-claude`, `stub-omp`, `stub-gh` (no API, no cost);
  `run.sh` + `scenarios/*/` drive real models (`make harness-eval`, costs money).

## Sequence

1. **Reproduce in selftest first.** Every runner behaviour has, or gets, a case in
   `evals/harness/selftest.sh` driven by a stub. Teach the stub the new output shape
   (`stub-claude` prints what a phase would print) rather than mocking inside `aisdlc`.
2. **Fail closed.** A missing input, an unreachable tracker, a gate with nothing configured or an
   unparseable phase output stops the task with the reason in its log and status — never a
   silent default that lets the next phase run. (Runner settings such as `workers` do fall back
   to `BUILTIN_*`; gates do not.)
3. **Never touch the user's checkout.** All work happens in the task worktree; a failed or
   changes-requested task keeps its worktree for inspection, never deleted on the error path.
4. **New config key:** a `BUILTIN_*` default, `resolve_default` wiring, the `aisdlc help` text, the
   `.aisdlc/config.json` key list in `commands/init.md`, and `commands/update.md` so existing
   repos receive it.
5. **Spend is bounded.** Under `billing: api`, every headless call carries `--max-budget-usd`;
   under `subscription` it is omitted and `cost_usd` recorded as `null`, never `0`.
6. **Document** the behaviour in `docs/ai-sdlc.md` (Queue configuration / Failure modes) and the
   README queue section.

## Test requirements

- `make selftest` — one case per new branch: the success path, each failure that stops the task,
  and the state left behind (status, log line, kept worktree).
- A phase-prompt change: one real run on the cheapest model against a scenario,
  `make harness-eval MODEL=haiku SCENARIO=<name>` — only with the user's go-ahead, it spends money.
- `cd evals/fixtures/sandbox && make verify` stays green; scenario specs stay `status: approved`.

## Verify

The verification block in `.claude/rules/bash.md`, which includes `make selftest`.

## Done when

The behaviour has a selftest case that failed before and passes now, every failure path stops
with a reason, config keys are wired through init/update/help, the docs say what changed, and
selftest plus `CI= make validate` are green.
