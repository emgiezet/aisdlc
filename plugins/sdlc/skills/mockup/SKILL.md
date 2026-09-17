---
name: mockup
description: >
  Use when a spec contains UI use cases and you need a clickable single-file mockup to validate
  the design with stakeholders before any production code is written.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# mockup

Validation before implementation. Reading a spec back to a stakeholder proves nothing — they
agree with the words and disagree with the screen. A clickable mockup surfaces the
misunderstanding while changing it is still free.

The invocation input is the ticket id. Read `.claude/sdlc.md` for the specs directory, then
`<specs dir>/<TICKET>/spec.md`. No spec → stop and point at the `spec` skill for <TICKET>. Works on a
`draft` spec — that is the point.

---

## Phase 1: Extract the UI surface

From the use-case table, take every row whose result is something a person sees: rendered text,
screen state, navigation, an error message. Ignore rows that are purely server-side.

List the screens and states you are going to build, and say which `UC-<n>` each covers. Include
the unglamorous ones — empty, loading, permission denied, validation failure. Those are where
expectations diverge most and where mockups usually stay silent.

If no use case has a visible result, say so and stop: this ticket has nothing to mock up.

---

## Phase 2: Build it

Write `<specs dir>/<TICKET>/mockup/index.html` — **one self-contained file**:

- React 18 UMD + Babel standalone + a utility CSS framework, all from CDN `<script>` tags. No
  bundler, no install, no dev server. It must open by double-clicking the file.
- All data hardcoded in a `FIXTURES` const at the top of the script, using values that look like
  this product's real data — plausible identifiers, realistic amounts and names — never
  `foo`/`bar`. Wrong-looking data derails the review into a discussion about the data.
- Clickable: state via `useState`, real navigation between screens, forms that validate and show
  the spec's error messages. No dead buttons — a control that does nothing must be visibly
  disabled.
- A state switcher pinned at the top: buttons to jump to each screen and to force the empty /
  loading / error / denied states, each labelled with the `UC-<n>` it demonstrates.
- If the project has a component library, mirror its visual language (spacing, button shapes,
  colour roles) so the mockup reads as this product rather than a generic template.

Constraints: no network calls, no external images, no router library, no state library. If the
reviewer's environment has no internet, note it — the fallback is `React.createElement` without
Babel, which drops the JSX but keeps the file self-contained.

Keep it under ~400 lines. A mockup that needs more is a spec that needs splitting.

---

## Phase 3: Hand it over

```
## Mockup ready
<specs dir>/<TICKET>/mockup/index.html — <n> screens covering UC-<…>

## Open it
<absolute path>   (double-click, or: xdg-open <path> / open <path>)

## Ask, in this order
1. <the riskiest assumption you had to make, phrased as a question about the screen>
2. <the second>
3. "What is missing that you expected to see?"

## Then
- Changes to the flow → update the spec with the `spec` skill, re-run this command.
- Flow confirmed → flip the spec to status: approved. Claude: `aisdlc add <TICKET>`. Codex: `$implement <TICKET>`. Grok: `/implement <TICKET>`.
```

The mockup is disposable code, but commit it with the spec: it is the record of what was actually
approved, and the UI playbook treats it as the visual contract during implementation.

---

## Not to be confused with

- **Production frontend work** — that is the `implement` skill following the UI playbook, with the
  project's real conventions and real tests. This command deliberately produces throwaway code in
  one file and must never be copied into the application.
- **The `spec` skill** — writes the spec this command reads. Run it first.
