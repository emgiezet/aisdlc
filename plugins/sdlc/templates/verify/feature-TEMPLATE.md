# Feature: {name}

One user-facing feature, described from the user's side. Copy to
`.claude/verify/features/{slug}.md` and add it to `features/README.md`. Keep the four headings —
`/sdlc:verify-map` audits against them.

{one sentence: what a user gets from this feature}

## Sub-features

- {the distinct things this feature does, each separately observable}

## How to get to it (user POV)

{the route, menu path, command or URL a user takes — the real entry point, not an internal call}

## Driving it

{the exact commands or harness operations that exercise it, and the observable end state that
proves it worked: status code and body, rendered text, exit code, the row written}

## Gotchas

{prerequisites — auth, seed data, entitlement, OS; the states that look like success and are
not; anything that made a previous run lie}
