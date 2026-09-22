# Browser provider: agent-browser

A single native `agent-browser` binary with its own Chrome for Testing — no Node dependency in the
target repository. Chosen by `/sdlc:init` when the binary is on `PATH`, or when no Playwright
config exists and the user picks it.

## Prerequisites

`agent-browser` on `PATH`; first **boot-check** downloads Chrome for Testing when missing and
prints the install command otherwise.

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
