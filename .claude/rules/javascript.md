---
paths:
  - "plugins/*/extensions/**"
  - "**/*.mjs"
---

# JavaScript — omp host adapters

## Conventions observed here

- ES modules (`.mjs`), Node built-ins only (`node:child_process`, `node:path`, `node:url`,
  `node:test`). No npm dependencies — `package.json` carries the omp manifest, not a dep tree.
- An adapter **bridges** to the shell hooks; it never re-implements a decision. It spawns the
  hook script, passes the payload on stdin, and maps the script's result to the omp event.
- The header comment lists every `hooks.json` binding and its omp equivalent, and states what
  omp cannot do (e.g. `turn_end` cannot block, so Stop is advisory). Update it with the code.
- Spawn failures, missing scripts and timeouts are reported as such (`rc = -1`), never treated
  as a successful allow without saying so.
- Tests use `node:test` in `plugins/*/tests/omp_adapter_test.mjs`, driving the real hook scripts.
- Eval fixture code under `evals/fixtures/sandbox/` is not an adapter; its own `CLAUDE.md` governs it.

## Verification

```bash
node --check plugins/sdlc/extensions/omp.mjs plugins/slop-guard/extensions/omp.mjs
node --test plugins/sdlc/tests/omp_adapter_test.mjs plugins/slop-guard/tests/omp_adapter_test.mjs
CI= make validate
```
