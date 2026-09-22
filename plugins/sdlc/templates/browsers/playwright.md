# Browser provider: playwright

Playwright through the repository's own Node toolchain. Chosen by `/sdlc:init` when a
`playwright.config.*` exists. Operations drive one persistent headless Chromium via a small helper
the provider generates at `.aisdlc/browser/pw.mjs` on first **open**.

## Prerequisites

Node ≥ 18, `@playwright/test` in the repo (or `npx playwright` resolvable), browsers installed
(`npx playwright install chromium`).

## Operations

### boot-check
TODO: SDLC-009
### open
TODO: SDLC-009
### goto
TODO: SDLC-009
### click
TODO: SDLC-009
### fill
TODO: SDLC-009
### assert-text
TODO: SDLC-009
### screenshot
TODO: SDLC-009
### close
TODO: SDLC-009
