# Playbook — Tests

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
Load the `dense-testing` skill — it holds the density floors and the rules this playbook enforces.

## Where tests live

| Suite | Runner | Convention |
|---|---|---|
| slop-guard | `plugins/slop-guard/tests/run-tests` | `*_test.sh` sourced by the runner; `ok "<what holds>"` / `bad "<case>" "<why>"` |
| sdlc hooks | `plugins/sdlc/tests/run-tests` | same shape; mirrors the slop-guard runner exactly |
| omp adapters | `node --test plugins/*/tests/omp_adapter_test.mjs` | `node:test`; also wrapped by `omp_adapter_test.sh` |
| real linters | `plugins/slop-guard/tests/tool-integration` | `tests/integration/*.sh` + `tests/fixtures/<lang>/{bad,good}/`; needs `doctor --install --all` |
| queue runner | `make selftest` → `evals/harness/selftest.sh` | stub `claude`/`omp`/`gh`, no API calls |
| catalogue | `plugins/slop-guard/tests/catalog_test.sh` | schema, mappings, budgets, gen-skills idempotency |

A new `*_test.sh` is sourced from its plugin's `run-tests` with a `# shellcheck source=` line —
a file nobody sources never runs. The omp `.mjs` suites already run inside `run-tests`.

## Sequence

1. **Find the gap before writing anything.** Which `UC-<n>` in `specs/<TICKET>/spec.md` has no
   case carrying its id? Which decision boundary in the diff (deny vs allow, phase stops vs
   continues) has no case? That list is the work.
2. **Drive the shipped path.** Pipe a payload into the real hook, run the real `aisdlc` against
   a stub — never call an internal function when the entry point is reachable.
3. **Both sides of every boundary.** The input that must be denied and the nearest input that
   must pass; each failure the runner can hit and the state it leaves.
4. **Assert on observable output** — the JSON decision, the exit code, the status file, the
   report line. Name the case after the behaviour, with `UC-<n>` when working from a spec.
5. **Isolate.** Scratch state under `mktemp -d`, `CLAUDE_PLUGIN_DATA`/`CLAUDE_PROJECT_DIR`
   pointed at it; no network (`file://` assets only); no dependency on test order.
6. **Run the whole suite**, not the new file — the runners source everything anyway.

## Non-negotiable

- Never delete a test, mark it skipped, or loosen an assertion to make the suite green. If a test
  contradicts the spec, stop and report the contradiction — deciding which is wrong is a human call.
- A changed decision moves an expectation; it never removes the case.
- A flaky test is a defect: fix the race or the fixture, never retry around it.

The sdlc `guard` Stop hook blocks a session that removed tests or added skips; `run_verify`
blocks the same in the queue.

## Verify

The verification block from the `.claude/rules/` file for each stack touched. Report the pass
count before and after for each suite you ran, and the skip count — which must be zero.

## Done when

Every `UC-<n>` and every boundary in the diff has a case, nothing was skipped or weakened, and
every touched suite is green.
