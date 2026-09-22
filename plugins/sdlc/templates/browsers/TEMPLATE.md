# Browser provider: {name}

Copy to `.claude/browsers/{name}.md` and set **Browser descriptor** in `.claude/sdlc.md` to that
path. QA and integration-test commands name operations in bold (**screenshot**); this file says how
each runs. `none` in the profile means every browser step is skipped with one line.

Rules for a provider:

- One `### <operation>` per heading, body = the exact command with `{param}` placeholders, then
  `Returns:` one line.
- **boot-check** installs nothing silently: it exits non-zero with the one install command to run.
- Selectors are the page's own: `role=`, `text=`, `data-testid=`, CSS. Never invent ids.
- **screenshot** writes a PNG at exactly `{path}`; callers pass `specs/<TICKET>/qa/UC-<n>.png`.
- A provider owns one browser session at a time; **open** replaces any previous one.

## Prerequisites

{runtime, binary, how it is installed, minimum version}

## Operations

### boot-check                       → exit 0 when the provider can launch a headless browser
### open        {base-url} {viewport} → session started at the URL
### goto        {url}
### click       {selector}
### fill        {selector} {text}
### assert-text {selector} {text}    → exit 1 with the actual text when it differs
### screenshot  {path}
### close
