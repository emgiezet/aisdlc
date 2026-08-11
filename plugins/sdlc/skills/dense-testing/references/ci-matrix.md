# CI verification matrix

Single source of truth for how any command discovers the commands to verify a change with.
Referenced by `/sdlc:implement`, `/sdlc:qa`, and the `auto-qa` agent. The goal: what you run
locally is exactly what CI runs, so a clean local run means no CI surprises.

If `.claude/sdlc.md` already records a verification table for this repo, use it and skip
discovery — it was resolved once, on purpose. Rediscover only when it looks stale (a command it
names no longer exists).

## Discovery order

Scan for CI configuration, first hit wins per stack:

1. `.github/workflows/*.yml` — job steps running lint, test, type-check, format tools
2. `.gitlab-ci.yml` — same
3. `Jenkinsfile` — same
4. `Makefile` — targets named `lint`, `test`, `check`, `validate`, `format`, `typecheck`
5. `.pre-commit-config.yaml` — hook ids
6. `.claude/rules/<stack>.md` — the "Verification (run after EVERY change)" block

Extract the **exact commands**, including flags. `go test -race ./...` and `go test ./...`
are not interchangeable; neither are `pint` and `pint --test`.

## Matrix shape

Build one row per stack the change touches — never for stacks it does not. The rows below are
examples of the *shape*, not a closed list: a repo in Rust, Ruby, Elixir or C# gets a row on the
same terms, discovered the same way.

| Stack | Linters / formatters | Type / static analysis | Tests |
|-------|----------------------|------------------------|-------|
| Go | `golangci-lint run` | `go vet ./...` | `go test -race ./...` |
| PHP / Laravel | `./vendor/bin/pint --test` | `./vendor/bin/phpstan analyse -l 8` | `php artisan test` |
| TypeScript / React | `npm run lint` | `npm run type-check` | `npm run test` |
| Python | `ruff check .`, `black --check .` | `mypy .` | `pytest` |

Fallbacks when no CI config exists — use these verbatim:

- **Go:** `golangci-lint run` → `go vet ./...` → `go build ./...` → `go test -race ./...`
- **PHP/Laravel:** `./vendor/bin/pint --test` → `./vendor/bin/phpstan analyse -l 8` → `php artisan test`
- **TypeScript/React:** `npm run lint` → `npm run type-check` → `npm run test` → `npm run build`
- **Python:** `ruff check .` → `mypy .` → `pytest`

Add, when the change touches them: `go test -tags=integration ./...` (repository code),
Playwright e2e (multi-screen spec flows), `terraform fmt -check && terraform validate && terraform plan`
(infrastructure — plan only, never apply).

If a tool named in CI is not installed locally, say so explicitly and note the command as
unverified. Never silently substitute a different tool or drop the row.

## Execution order and auto-fix

Run in order: formatters and linters → type / static analysis → tests. Cheap failures first.

Per command:

```
PASS → next command

FAIL → classify:
  Formatter        → re-run it in write mode (pint, black, gofmt, prettier), then re-run the check
  Linter / type    → one targeted fix, re-run that command
  Test             → one targeted fix, re-run the full suite (not just the failing test)

  PASS → next command
  FAIL → stop. Do not attempt a second fix.
```

The one-fix limit is deliberate: a second speculative fix on the same failure is where agents
start rewriting unrelated code. On stopping, report which command failed, the exact output,
the fix attempted, and why it did not work.

**Never** make a command pass by weakening what it checks — no `--no-verify`, no lint-disable
comment for a real defect, no deleted or skipped test, no lowered static-analysis level. See
the `dense-testing` non-negotiables.

Every command in the matrix must pass before the change is considered done.
