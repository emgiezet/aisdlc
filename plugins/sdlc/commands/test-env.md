---
description: Discover, generate, and boot a local test environment for integration and browser-based QA — detects how the application starts, writes POSIX up/down scripts, verifies the app is reachable, and caches the session so a second call within the same session returns immediately. Use before /sdlc:integration-tests or the browser pass in /sdlc:qa.
allowed-tools: Bash, Read, Write, Glob
---

# /sdlc:test-env

Prepares the running application that browser-based QA and integration tests need. Its output,
`.aisdlc/test-env/env.json`, is what `/sdlc:integration-tests` and the `auto-qa` browser pass
read to reach the app.

`$ARGUMENTS` is optionally `--down`. Read `.claude/sdlc.md` for `Integration tests need:`,
`Browser descriptor:`, and `End-to-end runner:`.

---

## Phase 1: Warm reuse [GATE]

**First action:** if `.aisdlc/test-env/env.json` exists, read `base_url` and probe the port:

```bash
port=$(jq -r '.base_url' .aisdlc/test-env/env.json | grep -oE ':[0-9]+' | tr -d ':')
nc -z 127.0.0.1 "${port:-0}" 2>/dev/null
```

Exit 0 from `nc` → print `warm` and stop. The environment is already up; do not boot again.

---

## Phase 2: Shutdown (`--down`)

If `--down` was passed:

```bash
bash .aisdlc/test-env/down.sh
rm -f .aisdlc/test-env/env.json
```

Print `environment stopped` and stop. Nothing else is touched.

---

## Phase 3: Discovery

Determine how to start the application. Use the first row whose check succeeds:

| Priority | Source | Check |
|---|---|---|
| 1 | Profile `Integration tests need:` | `.claude/sdlc.md` key ≠ `none` |
| 2 | Docker Compose | `docker-compose.yml` or `compose.yml` in repo root |
| 3 | Makefile target | `grep -Em1 '^(run\|dev\|start\|serve):' Makefile` matches |
| 4 | `package.json` scripts | `jq -e '.scripts | to_entries[] | select(.key | test("^(start|dev|run|serve)$"))' package.json` |
| 5 | None | Cannot boot → UC-2 path |

**UC-2 path:** write `.aisdlc/test-env/up.sh` as a template and stop:

```sh
#!/bin/sh
set -eu
# FILL: start your application (e.g. docker compose up -d, go run ./cmd/api, npm start)

# FILL: export BASE_URL as the root URL of the running application (e.g. http://localhost:8080)
export BASE_URL=http://localhost:8080

# FILL: export HEALTH_URL as a URL that returns HTTP 200 when the app is ready
export HEALTH_URL=${BASE_URL}/health
```

Print `cannot boot: no compose, Makefile target, or profile command found` and stop with exit 1.

---

## Phase 4: Generate scripts [REQUIRED]

Write `.aisdlc/test-env/up.sh` — a POSIX shell script that starts the app in the background,
writes `env.json`, and exits. It must:

- Start the discovered provider (profile command, `docker compose up -d`, `make <target>`, or
  `npm run <script>`).
- Set `BASE_URL` to the app's root and `HEALTH_URL` to a reachable health endpoint
  (`${BASE_URL}/health`, or `${BASE_URL}` if no `/health` route exists).
- Record PID or container name in `PID_OR_CONTAINER`.
- Write `.aisdlc/test-env/env.json`:
  ```json
  {"base_url":"<BASE_URL>","health_url":"<HEALTH_URL>","started_at":"<ISO-8601>",
   "provider":"<detected>","pid_or_container":"<PID_OR_CONTAINER>"}
  ```

Write `.aisdlc/test-env/down.sh` — stops the process or container identified in `env.json`.

Both scripts are POSIX (`/bin/sh`), require no root, and run on Linux, macOS, and WSL2.

---

## Phase 5: Boot and health check [HARD STOP on timeout]

```bash
bash .aisdlc/test-env/up.sh
```

Read `Browser descriptor:` from `.claude/sdlc.md`. If it is not `none`, open the descriptor and
run **boot-check**; if it exits non-zero, print the install hint and continue (the environment
is up; the browser is the caller's problem).

Then poll `health_url` for HTTP 200 with a 60-second deadline:

```bash
deadline=$(($(date +%s) + 60))
until curl -fsS "$HEALTH_URL" >/dev/null 2>&1 || [ "$(date +%s)" -ge "$deadline" ]; do
    sleep 2
done
curl -fsS "$HEALTH_URL" >/dev/null 2>&1 || { echo "health check failed after 60 s"; exit 1; }
```

Print:

```
Environment ready
  provider:   <detected>
  base_url:   <BASE_URL>
  health_url: <HEALTH_URL>
  started_at: <ISO-8601>
```

---

## Not to be confused with

- **`/sdlc:integration-tests`** — uses the running environment to explore the DOM and write E2E
  tests. Requires `env.json` that this command produces.
- **The profile's verification matrix** — runs unit and integration tests that do not need a live
  browser. This command is only for UI-driven scenarios.
