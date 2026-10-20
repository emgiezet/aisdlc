---
paths:
  - "plugins/*/hooks/**"
  - "plugins/*/bin/**"
  - "plugins/slop-guard/lib/**"
  - "plugins/slop-guard/scripts/**"
  - "plugins/*/tests/**"
  - "evals/harness/**"
---

# Bash — hooks, CLIs, libraries, tests

## Conventions observed here

- `#!/usr/bin/env bash`, then `set -uo pipefail`. **No `-e`** in hooks and CLIs: a hook that dies
  mid-way emits no decision, so every failure is handled and turned into one.
- Hooks read one JSON payload on stdin via `hook_input`/`hook_field` (`plugins/slop-guard/lib/hook.sh`)
  and print exactly one decision through `hook_deny`, `hook_ask`, `hook_allow` or `hook_context`.
  Nothing else goes to stdout; diagnostics go to stderr.
- JSON is built with `jq -n --arg/--argjson`, never by string concatenation. The local `jq` is
  `jaq 2.3.0`; stay inside the jq subset both understand.
- `hooks/` and `plugins/slop-guard/lib/` run on users' Linux and macOS machines: GNU-then-BSD
  fallbacks (`stat`, `mv -h`), locks by `mkdir`, not `flock` (`lib/tools.sh`). Dev-side
  `scripts/` may use bash 4 features.
- `local` for every function variable; quote every expansion; `[ ]` tests; `printf` over `echo`.
- Scratch space from `mktemp -d`; state under `${CLAUDE_PLUGIN_DATA}` (Grok: `GROK_PLUGIN_DATA`).
- `scripts/gen-skills` and the hooks use bash + jq + POSIX awk/sed only — no python, no network.
  awk has no `\b`; use explicit character classes.
- Under `pipefail`, `printf … | grep -q` can exit 141 (SIGPIPE) — use a herestring
  `grep -q … <<<"$x"`.
- Tests: `ok "<what holds>"` / `bad "<case>" "<why>"`, sourced by the plugin's `run-tests` with
  a `# shellcheck source=` line; payloads from `tests/hook-contract/*.json`.
- A new executable is `chmod +x` and listed in `SCRIPTS :=` in the `Makefile` (sdlc) or covered
  by the `validate-slopguard` globs.

## Verification

```bash
bash -n <changed files>
docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -S warning <changed files>
plugins/slop-guard/tests/run-tests
plugins/sdlc/tests/run-tests
make selftest                     # when bin/aisdlc or evals/harness changed
CI= make validate
```
