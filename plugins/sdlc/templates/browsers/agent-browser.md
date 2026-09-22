# Browser provider: agent-browser

A single native `agent-browser` binary with its own Chrome for Testing — no Node dependency in the
target repository. Chosen by `/sdlc:init` when the binary is on `PATH`, or when no Playwright
config exists and the user picks it.

## Prerequisites

`agent-browser` on `PATH`; first **boot-check** downloads Chrome for Testing when missing and
prints the install command otherwise.

## Operations

### boot-check
agent-browser --version
Returns: exit 0 when binary is present and functional; exit 1 — install with `npm install -g agent-browser` or download the release binary from the project's GitHub releases page

### open
agent-browser open {base-url}
Returns: browser session opened at {base-url}

### goto
agent-browser goto {url}
Returns: page navigated to {url}

### click
agent-browser click {selector}
Returns: element at {selector} clicked

### fill
agent-browser fill {selector} {text}
Returns: field {selector} filled with {text}

### assert-text
agent-browser get-text {selector}
# Capture the output and compare to {text}; exit 1 with actual text if it does not include {text}
Returns: exit 0 when element text includes {text}; exit 1 with actual text

### screenshot
agent-browser screenshot --path {path}
Returns: PNG written to {path}

### close
agent-browser close
Returns: browser session closed
