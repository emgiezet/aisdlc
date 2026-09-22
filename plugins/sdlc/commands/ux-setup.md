---
description: Write the repo's design contract as a path-scoped rule at .claude/rules/design-system.md — tokens, components, spacing, and copy rules with file:line sources. Use once per repository before /sdlc:ux-review, or when the design system changes.
allowed-tools: Read, Write, Grep, Glob, Bash
---

# /sdlc:ux-setup

One rule file that `/sdlc:ux-review` and any UI-touching agent reads automatically via its
`paths:` frontmatter. It is a tier-3 rule (task-router skill): path-scoped to the UI
directories, ≤ 70 lines, ending in a copy-pasteable verification block.

**Never touches `CLAUDE.md`.** The router table is not yours; the rule file is.

Read `.claude/sdlc.md` for the profile. No profile → proceed with detection only.

---

## Phase 1: Survey the design system

Scan the repo for:

1. **Token file** — look for `tokens`, `theme`, `design-system`, `variables`,
   `tailwind.config.*`, or CSS custom-properties (`--`) in `src/`, `styles/`, or the
   frontend root. Note each token with `file:line`.
2. **Component catalogue** — look for `components/`, `ui/`, or Storybook stories.
   Note each public component name with `file:line`.
3. **Spacing or sizing scale** — note values with `file:line`.
4. **Copy or tone guidelines** — look for `copy.md`, `content.md`, `writing.md`, or inline
   brand-voice comments. Note each rule with `file:line`.

Report what you found and what was absent before writing anything.

---

## Phase 2: Identify the UI directories

List the directories that contain UI source files (not tests, not generated output, not
`node_modules`). These become the `paths:` frontmatter.

---

## Phase 3: Write the rule [REQUIRED]

**Design system found:**

Write `.claude/rules/design-system.md` (≤ 70 lines):

```markdown
---
paths:
  - <ui-dir-1>/**
  - <ui-dir-2>/**
---

# Design system

## Tokens
- <token-name>: <value> (`<file>:<line>`)

## Components
- `<ComponentName>` — <one-line purpose> (`<file>:<line>`)

## Spacing
<scale or key values with file:line>

## Copy rules
- <rule> (`<file>:<line>`)

## Verify
<command to run the visual regression or Storybook suite, or "none">
```

**No design system found:**

Write `.claude/rules/design-system.md`:

```markdown
---
paths:
  - <ui-dir>/**
---

# Design system: none

No design token file or component catalogue was found in this repository.
```

Print one line: `no design system found — rule stubbed with "none"`

---

## Phase 4: Report

```
## Design rule written
.claude/rules/design-system.md (<n> lines)
Paths: <ui-dir list>
Tokens: <n> · Components: <n> · Spacing: <found|none> · Copy rules: <n>
```

---

## Not to be confused with

- **`/sdlc:ux-review`** — uses this file to review a PR's UI. Run setup first.
- **`/sdlc:ux-shape`** — decides the direction for one flow. Separate artefact.
- **`CLAUDE.md`** — the task router. This command does not touch it.
