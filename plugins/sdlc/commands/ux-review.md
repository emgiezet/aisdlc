---
description: Walk a PR's UI changes against the project's design system and post findings as a single PR comment — each finding tagged with a screenshot path and the violated design-system rule. Use after /sdlc:ship, before /sdlc:merge, when the PR touches UI.
allowed-tools: Bash, Read, Grep, Glob, SlashCommand, Agent
---

# /sdlc:ux-review

Verifies that UI changes shipped in a PR follow the project's design system. Findings are
structured so a developer knows exactly what to fix and when to consider it done.

`$ARGUMENTS` is the PR number. Read `.claude/sdlc.md` for the **Browser descriptor** and
**Tracker descriptor**.

---

## Phase 1: Preflight [HARD STOPS]

**First action:** check that `.claude/rules/design-system.md` exists. If it does not, print
`no design-system.md — run /sdlc:ux-setup first` and stop. Do not search the repository for
a substitute; the absence is definitive.

Then stop if:

- `Browser descriptor:` is `none` → `browser: none — cannot walk UI without a browser`
- **get-pr** returns no PR for the given number → `PR #<n> not found`
- The PR diff touches no UI files (`.html`, `.css`, `.jsx`, `.tsx`, `.vue`, `.svelte`) →
  print `no UI changes in PR #<n>` and stop

Run the browser's **boot-check**. Exit non-zero → print the install hint and stop.

---

## Phase 2: Read the design system

Read `.claude/rules/design-system.md` completely. Note every numbered rule or named guideline
so you can reference it precisely as `[RULE: <line>]`. Do not summarise — you will quote exact
lines in findings.

---

## Phase 3: Walk the PR's UI [REQUIRED]

Retrieve the diff of UI files via **get-pr-diff**. For each screen or component that changed:

1. Determine the URL where it can be seen. If the app is not running, run `/sdlc:test-env`.
   If test-env fails, record `Cannot reach: <screen>` as a finding and continue.
2. **open** / **goto** the screen.
3. **screenshot** `specs/ux-review/pr-<n>/<screen>.png` as baseline evidence.
4. Compare what you see against every design-system rule that applies to this screen.
5. For each deviation, record a finding (see Phase 4 format).
6. **screenshot** `specs/ux-review/pr-<n>/<screen>-finding-<m>.png` when the finding is visual.

Selectors must come from the live DOM. Never invent ids.

---

## Phase 4: Compile findings

Each finding follows this format exactly:

```
### Finding <n>: <one-line title>
[SCREENSHOT: specs/ux-review/pr-<n>/<screen>.png]
[RULE: <line number in design-system.md>] — <quoted rule text>

**Observed:** <what the PR shows>
**Expected:** <what the design system requires>
**Done when:** <single observable criterion for resolution>
```

Severity: `blocker` (violates an explicit rule) or `suggestion` (deviation from convention).
A `suggestion` never blocks merge; a `blocker` does.

If no findings, write: `No design-system violations found.`

---

## Phase 5: Post the comment [REQUIRED]

Write the full findings list to a temp file, then **comment-pr** once with it. One comment,
not one per finding. Do not **label-pr** anything — label transitions belong to `/sdlc:review`.

```
## UX Review — PR #<n>

Reviewed against `.claude/rules/design-system.md` (<line count> rules).
Screens walked: <list>.

<findings or "No design-system violations found.">

---
<n> blocker(s) · <m> suggestion(s)
```

---

## Phase 6: Report

```
## UX review complete — PR #<n>
Blockers: <n> · Suggestions: <m>
Comment: posted

PR: #<n> (<url>)
```

---

## Not to be confused with

- **`/sdlc:review`** — code quality and spec coverage. This command checks visual design only.
- **`/sdlc:ux-setup`** — writes the initial `.claude/rules/design-system.md`. Run it first if
  this command refuses.
- **Accessibility audits** — not in scope here. A passing ux-review says nothing about
  keyboard navigation, screen readers, or colour contrast unless the design system addresses them.
