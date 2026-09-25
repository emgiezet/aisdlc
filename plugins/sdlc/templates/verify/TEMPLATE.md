# Verification map: {app}

Copy to `.claude/verify/{app}.md` and set **Verification map** in `.claude/sdlc.md` to that path.
Written by `/sdlc:verify-map`, read cold by whoever has to prove the app works — usually
`/sdlc:qa`. `none` in the profile means runtime behaviour is verified by tests alone and QA says
so in one line.

Rules for this file:

- Every command here is the real one for this repo, already executed. No examples, no
  placeholders left, no step nobody has run.
- Drive the app the way a user does. Test-only endpoints, internal setters and fixtures that
  bypass the feature are not verification.
- Evidence outlives cleanup. Cleanup kills what this run started, by recorded pid or container
  id — never `pkill` by name.
- One feature file per user-facing feature, in `features/`, indexed by `features/README.md`.

## Surface

{HTTP API | CLI/TUI | web UI | desktop | library — the primary one, then the rest in one line}

## Launch

{the exact command; or: `/sdlc:test-env`, then read `base_url` from `.aisdlc/test-env/env.json`}

Ready when: {the log line, the port answering, the prompt returned}
Isolation: {can two instances coexist — the port/data-dir knobs, or "no: never double-drive"}

## Doctor

{one read-only check: process up, port ours, build current, auth valid}

Returns: exit 0 when this instance is worth driving; the reason on stderr when it is not.

## Drive

{the harness recipe with this repo's real routes, selectors or prompts — HTTP calls, the browser
descriptor's operations, or a PTY/tmux session per invocation for a CLI}

## Evidence

{what proves a feature worked: response bodies, exit codes, rows, screenshots, log lines}

Path: `specs/<TICKET>/qa/` when a ticket is in play, otherwise
`.aisdlc/verify/evidence/<utc-timestamp>/`.

## Cleanup

{how to stop exactly what was started; what scratch state is removed}

A signal that was sent is not a process that stopped: poll until the pid or container is gone
(a graceful shutdown can take seconds and keep the port) and say so if it never goes. Evidence
is not removed here.

## Helpers

{each script this map ships: path, what it does, and the invocation — executable, or it is not a
helper}
