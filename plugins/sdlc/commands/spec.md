---
description: Turn a ticket, URL, file, or description into an agent-executable spec at specs/<TICKET>/spec.md — a use-case table with observable acceptance criteria, grounded in the codebase. The artefact that /sdlc:implement, /sdlc:qa and the aisdlc queue consume. Use to write, refresh, or readiness-check a spec before queueing unattended work.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, WebFetch, Agent
---

# /sdlc:spec

Produces the one artefact that makes unattended execution possible. `/sdlc:implement` runs with
no human gates, so **this spec is the only approval point** — whatever it leaves unsaid, the
agent will invent.

`$ARGUMENTS` contains the ticket reference. Detect its format:

- Matches the project's ticket id pattern (default `[A-Z]+-[0-9]+`, e.g. `ABC-123`) → **ticket**
- `http(s)://…` → **URL** · starts with `/` or `./` → **file path** · else → **free text**

For free text, derive the id `LOCAL-<slug>` from the first few words (e.g.
`LOCAL-account-balance-endpoint`) and say which id you chose.

**Read `.claude/sdlc.md` first** — it names this repo's specs directory, tracker, contract
directory, ADR location, and glossary skill. No profile → detect what you can, and state each
assumption you had to make. Missing `/sdlc:init` is worth one line of advice, not a refusal.

**Load the `spec-authoring` skill** — it holds the section layout, the use-case rules, the sizing
limits, and the review checklist this command applies.

**When the ticket touches an API surface**, also load `rest-api-design` for an HTTP/REST change
or `graphql-api-design` for a schema change. The use-case table then names the exact path,
method, status code, or field nullability instead of leaving the agent to pick one.

---

## Phase 1: Gather the source

Follow the tracker recorded in the profile:

- **`jira-mcp`** — check availability with `getAccessibleAtlassianResources`. If it fails, note
  "tracker unreachable — paste the ticket body or pass it as text" and stop until you have the
  content. Then `getJiraIssue` for summary, description, acceptance criteria and links, plus
  `getConfluencePage` for linked pages.
- **`github`** — `gh issue view <n> --json title,body,labels,comments`. Read the comments: the
  real acceptance criteria are often buried in the discussion, not the description.
- **`none`** — the argument is the source.

**URL / file / free text** always work regardless of tracker, and override it.

Never invent ticket content. An unreachable tracker is a stop, not a prompt to guess.

If the profile names a domain glossary skill, load it — the spec must use the team's vocabulary
rather than a paraphrase of it.

If the profile's `Briefs live in:` directory (default `specs/briefs/`) contains a file whose
slug or ticket id matches `$ARGUMENTS`, read it before writing anything. Use its Problem section
as the seed for the spec's Problem, its Non-goals as the seed for `Out:`, and its Decisions as
the seed for the Context section's recorded decisions. Evidence-tagged claims carry their tag
into the spec unchanged; `[ASSUMPTION]` items become open questions.

---

## Phase 2: Ground it in the codebase

A spec that cannot name the files it touches is not ready to run unattended.

- If a fresh codebase map exists (some projects keep one under `.codebase-map/`), read the
  relevant parts instead of scanning blind.
- Otherwise grep the key domain terms; in subagent mode dispatch one `Explore` agent to find the
  touched modules, the nearest sibling implementation, and the test command.
- Resolve, using the profile: which contract operations are involved (skip if the profile says
  there is no contract directory), which recorded decisions constrain the change (skip if no
  ADRs), and which stacks are in scope.

Output a 3–5 bullet grounding summary before writing anything.

---

## Phase 3: Write the spec

Write `<specs dir>/<TICKET>/spec.md` following the `spec-authoring` template; `mkdir -p` its
directory first. Frontmatter starts at `status: draft` — **you never set `approved`, a human
does.**

While writing:

- Every acceptance criterion becomes one `UC-<n>` row with an observable result. Convert prose
  into rows; do not copy the prose in.
- Add the negative cases the ticket forgot: each validation rule, each permission boundary, each
  not-found path. Mark them as added so the reviewer can see what you inferred.
- Fill `Out:` scope aggressively — name the adjacent modules and the refactors that must not
  happen. This is the cheapest defect prevention in the whole pipeline.
- Point `Context` at files, symbols, and contract operation ids. Never describe code in prose.
- **If the spec is already tracked in git, preserve existing `UC-<n>` ids** — they are referenced
  by test names and past QA reports. Append new rows; never renumber.

**Declare the change budget.** End `## Scope` with one line —
`Change budget: <n> added lines, <n> files, <n> modules` — estimated the way
`/sdlc:decompose` Phase 0 describes: paths named in Context plus their call sites, compared
against the three most similar past commits (`git log` then `git show --numstat`). This line is
not decoration: `scope-check` enforces it on the branch before ship.

**Then size the spec [GATE].** If the estimate breaks any budget number in `.claude/sdlc.md`
(defaults: 400 added lines, 15 files, 3 modules), or the change spreads thinly across more
modules than the budget allows, **run `/sdlc:decompose <TICKET>` and write its slices instead
of this one spec.** Same for more than ~8 use cases or more than two stacks. Report what the
estimate was and which seam the decomposition used. One spec is one queue task is one pull
request; a spec nobody can review is not a spec that got approved faster.

---

## Phase 4: Close the open questions

List every ambiguity you had to guess at as an `Open questions` checkbox.

- **Interactive session:** work the list one question at a time, recommending an answer and
  checking the codebase instead of asking whenever you can. Move each resolved answer into the
  relevant section and delete the checkbox. If a hard-to-reverse decision with a real trade-off
  surfaces and the profile names an ADR location, record it there.
- **Headless session** (invoked by the queue): leave the checkboxes in place. The spec stays
  `draft` and the queue will refuse it — which is the correct outcome, not a failure.

---

## Phase 5: Readiness report

Run the `spec-authoring` review checklist and report:

```
## Spec written
<specs dir>/<TICKET>/spec.md — <n> use cases, stacks: <…>, status: draft

## Inferred (not in the source)
<bullets: use cases and scope decisions you added — the reviewer must confirm these>

## Assumed about this repo
<only when there is no .claude/sdlc.md: what you detected and what you guessed>

## Open questions blocking approval
<list, or "none">

## Next
1. Review the spec, especially the Out: scope and the inferred use cases.
2. UI in scope? → /sdlc:mockup <TICKET> and validate with the business first.
3. Flip status: approved in the frontmatter, commit the spec.
4. Queue it: aisdlc add <TICKET>
```

Never offer to approve the spec yourself, and never continue into implementation from here.

---

## Not to be confused with

- **`/sdlc:implement`** — consumes the approved spec and builds it, unattended. This command only
  writes the contract.
- **`/sdlc:init`** — sets up the repo's router, playbooks and profile. Run it once, before your
  first spec.
- Any planning or decomposition workflow your project already has. If a ticket needs to become
  several independently shippable slices, decompose it first and run this command per slice —
  one spec is one queue task is one pull request.
- **`/sdlc:decompose`** — the sizing escape hatch this command calls when its estimate is over
  budget. Use it directly on a ticket you already know is too big; it writes one spec per
  shippable slice, and each one comes back through this command's rules.
