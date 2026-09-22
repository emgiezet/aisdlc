---
description: Explore the running application's DOM and write one E2E test per UI use case in the spec, using real locators read from the page — never invented ids. Use after /sdlc:test-env, when the spec has UI UCs and a configured End-to-end runner.
allowed-tools: Bash, Read, Write, Glob, Grep
---

# /sdlc:integration-tests

Writes browser-based end-to-end tests that prove UI use cases work against the real running
application. Locators come from the DOM — no `data-testid` values are invented.

`$ARGUMENTS` is the ticket id. Read `.claude/sdlc.md` for `End-to-end runner:`, `Browser
descriptor:`, and the verification table.

---

## Phase 1: Preflight [HARD STOPS]

**First action:** check that `.aisdlc/test-env/env.json` exists. If it does not, print
`no env.json — run /sdlc:test-env first` and stop. Do not attempt to start the application.

Also stop if:

- `specs/<TICKET>/spec.md` does not exist → `no spec at specs/<TICKET>/spec.md`
- The spec contains no UC row with `e2e` in the `test` column → `no e2e UCs in spec — nothing to write`
- `End-to-end runner:` in `.claude/sdlc.md` is `none` → `no e2e runner configured`

Read the browser descriptor. Run **boot-check**; exit non-zero → print the install hint and stop.

---

## Phase 2: Explore the DOM [REQUIRED]

For each UI UC in the spec, navigate to its starting point in the running app and read the
actual locators from the page. Use only what the DOM provides:

```bash
base_url=$(jq -r '.base_url' .aisdlc/test-env/env.json)
```

**open** `${base_url}` → **goto** the UC's entry URL → read the DOM. Prefer `role=`, `text=`,
`placeholder=`, `data-testid=` selectors in that order. If none are stable, use a CSS path.
Never invent an id that does not exist in the live page.

Record the real selectors for each step of the UC flow. Perform the full interaction:
**click** interactive elements, **fill** form fields, **assert-text** the expected result.

---

## Phase 3: Write the tests [REQUIRED]

Write one test per UI UC, named with the UC id and the ticket:

| Runner | File location | Test name pattern |
|---|---|---|
| Playwright | `e2e/<TICKET>/` or beside source per project convention | `test('UC-<n> <title>', ...)` |
| Cypress | `cypress/e2e/<TICKET>/` | `it('UC-<n> <title>', ...)` |
| Other | project convention | must contain `UC-<n>` |

Rules:

- Each test uses only selectors read from the DOM in Phase 2.
- Fixtures (users, data) are created at test runtime, not assumed to exist.
- A test that cannot use a real locator writes a skip with an explicit comment explaining why.
- Never delete or weaken an existing test to accommodate a new one.

---

## Phase 4: Run the suite [REQUIRED]

Run the E2E suite. Capture full output, including counts, skips, and trace paths.

---

## Phase 5: Diagnose failures

For each failed test, diagnose the cause from the artefacts (screenshots, traces, network log):

| Category | Evidence | Action |
|---|---|---|
| `app bug` | Assertion fails; screenshot shows wrong content | Record; caller fixes the implementation |
| `test bug` | Assertion fails; manual check in browser passes | Fix the locator or interaction; rerun |
| `env` | Connection refused; timeout; no response | Verify test-env is still up; restart if not |

---

## Phase 6: Report

```
## Integration tests — <TICKET>
Runner: <End-to-end runner> · Base URL: <base_url>

| UC | test | result | diagnosis |
|----|------|--------|-----------|
| UC-1 | test name | ✅ pass | — |
| UC-2 | test name | ❌ fail | app bug: <reason> |

<exact suite output with counts and skip counts>
```

Chain markers apply only if this was invoked from a PR-producing command:

```
PR: #<n> (<url>)
```

---

## Not to be confused with

- **`/sdlc:test-env`** — boots the application. This command writes and runs tests against it.
- **`auto-qa` browser pass** — in `/sdlc:qa`, takes a screenshot per UC as evidence. This command
  writes permanent regression tests in the project's own runner.
- **The profile's unit/integration test suite** — tests that do not require a live browser.
  Both belong on the branch; they are not substitutes for each other.
