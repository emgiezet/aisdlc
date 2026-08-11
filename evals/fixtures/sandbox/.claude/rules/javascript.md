---
paths:
  - frontend/**
---
# Frontend Standards (sandbox)

## Stack: ES modules, no dependencies, tested with `node:test`.

## Style
- Named exports only. One concern per file.
- JSDoc comment on every exported function.
- 2-space indentation, single quotes, semicolons.

## Rules
- Amounts arrive as integer minor units. Reject anything else with a thrown `Error` — never
  coerce silently, never do float arithmetic on money beyond the final display divide.
- Formatting functions are pure: no I/O, no dates, no locale lookups from the environment.
- Throw `Error` with a message naming the offending value.

## Testing
- Tests live beside the module as `<name>.test.mjs`, using `node:test` and
  `node:assert/strict`.
- One `test()` per behaviour, including every rejection path.
- Test names carry the spec use case id when implementing a spec: `'UC-2: rejects …'`.

## Verification (run after EVERY change)
- `npm run lint` (node --check)
- `npm test`
