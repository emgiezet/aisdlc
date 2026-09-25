---
description: Split an oversized spec, brief or epic into ordered, independently shippable slices that each fit one pull request — estimates the change surface against the repo's change budget, picks a slicing seam, writes specs/<TICKET>-a…/spec.md plus a decomposition plan, and leaves every slice as draft for a human to approve. Runs automatically from /sdlc:spec when the estimate is over budget; use directly on a big ticket, a stalled branch, or any change nobody can review in one sitting.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
---

# /sdlc:decompose

A plan may be large. A pull request may not. This command is the step between the two: it turns
one oversized intention into a sequence of changes that can each be implemented, reviewed,
merged and reverted on their own.

`$ARGUMENTS` is a ticket id, or a path to a spec, brief or architecture document.

Read `.claude/sdlc.md` for `Specs live in:` and the `## Change budget` section. The budget is
three numbers plus a ceiling; the defaults, when the profile says nothing, are 400 added lines,
15 files, 3 modules, and a hard ceiling of 3000 added lines.

---

## Phase 0: Estimate, then decide [GATE]

Estimate the change surface from the source document and the repository — never from intuition:

| Signal | How to measure it |
|---|---|
| Files | every path named in `## Context` and `In:`, plus their call sites: `grep -rl <symbol>` per symbol the UCs touch |
| Modules | distinct first-two-path-segments across those files |
| Added lines | per UC: the handler or component, its tests, and its contract entry. Compare against sibling changes: `git log --format=%H -20 -- <dir>` then `git show --numstat` for the three most similar commits |
| Fan-out | files changed per UC. Many files × few lines each is shotgun surgery, whatever the total |

Print the estimate. Then:

- **Under budget and no fan-out** → print `NOT NEEDED — <added>/<files>/<modules> within budget`
  and stop. Nothing is written. This makes the command safe to call automatically.
- **Over any budget number, or shotgun fan-out** → continue.
- **Cannot estimate** — the document names no paths and the repo has no comparable change →
  `BLOCKED`, saying which fact is missing. Do not invent slices from a title.

---

## Phase 1: Pick the seam [REQUIRED]

Slice along the axis that keeps every intermediate state shippable. In order of preference:

| Seam | Use when | Slice shape |
|---|---|---|
| **Walking skeleton** | the change adds a new path end to end | slice `-a` is the thinnest working path (one UC, real data, real response); later slices widen it |
| **Vertical by use case** | UCs are independent | one slice per UC group that shares a file set; each ships behaviour a user can see |
| **Seam first** | the change would touch many callers (shotgun surgery) | slice `-a` introduces the shared abstraction with *no behaviour change* and no caller moved; each later slice moves one caller group |
| **Expand / contract** | a data or contract shape changes | `-a` adds the new shape and dual-writes, `-b` migrates readers, `-c` removes the old shape |
| **Mechanical split** | a rename, codemod or generated update rides along | the codemod is its own slice, marked `mechanical: true`, with its own wider `Change budget:` — a 300-file rename is reviewable by pattern, a 300-file rename mixed with logic is not |

Never slice by layer ("all the models", then "all the controllers"): each of those slices ships
nothing, and the third one carries every risk the first two deferred.

---

## Phase 2: Write the slices [REQUIRED]

For each slice, write `<specs>/<TICKET>-<a|b|c…>/spec.md` in the `spec-authoring` format, with:

- **Frontmatter** — `ticket: <TICKET>-a`, `status: draft`, `stacks:`, and `depends-on: <TICKET>-a`
  when the slice cannot ship first.
- **UC ids that never move.** A use case keeps the id it had in the source spec: `UC-3` stays
  `UC-3` in whichever slice implements it. Ids are the traceability chain into test names and
  QA reports; renumbering them per slice breaks it. A UC that splits becomes `UC-3a`, `UC-3b`.
- **`## Scope`** with a `Change budget:` line: `Change budget: <n> added lines, <n> files,
  <n> modules`. This is what `scope-check` enforces on that slice's branch.
- **`Out:`** naming the other slices explicitly — "the caller migration, which is `<TICKET>-c`".
  That is what stops slice `-b` from quietly doing the whole job.
- **One observable outcome.** If a slice's only value is "prepares the next slice", it is a
  seam slice and must say what proves it is correct: the existing suite still green, and the new
  abstraction covered by its own tests.

Slices are ordered so the product works after each one. A slice that leaves the build red, a
feature half-migrated with no flag, or a dead abstraction with no user is not a slice.

---

## Phase 3: Write the plan and retire the source [REQUIRED]

Write `<specs>/<TICKET>/decomposition.md`:

```markdown
# Decomposition — <TICKET>

Estimate: <added> added lines · <files> files · <modules> modules (budget <a>/<f>/<m>)
Seam: <walking skeleton | vertical | seam first | expand/contract | mechanical>

| Slice | Outcome a user or operator can see | UCs | Budget | Depends on |
|---|---|---|---|---|
| `<TICKET>-a` | … | UC-1, UC-2 | 180 lines | — |
| `<TICKET>-b` | … | UC-3 | 220 lines | `-a` |

Order: -a → -b → -c. Each merges on its own; none waits for the next.
Not sliced out: <what stayed together, and why splitting it would break a state>
```

When the source document was a spec, set its frontmatter to `status: superseded` and add one
line pointing at the decomposition. The queue refuses anything that is not `approved`, so a
superseded spec cannot be run by accident. Never delete it: it is the record of what was asked.

Commit:

```bash
git add <specs>/<TICKET> <specs>/<TICKET>-*
git commit -m "docs(spec): decompose <TICKET> into <n> slices"
```

---

## Phase 4: Report

```
## Decomposition — <TICKET>
Verdict: DECOMPOSED (<n> slices) | NOT NEEDED | BLOCKED
Estimate: <added>/<files>/<modules> vs budget <a>/<f>/<m>
Seam: <name>
Slices: <TICKET>-a (<n> lines, UC-1 UC-2) → <TICKET>-b (…) → …

## Next
A human approves each slice in order: flip `status: approved` on <TICKET>-a first.
Then: aisdlc add <TICKET>-a && aisdlc add <TICKET>-b
```

| Verdict | Means |
|---|---|
| `DECOMPOSED` | slices written, each under budget, each independently shippable |
| `NOT NEEDED` | the estimate fits the budget; nothing written |
| `BLOCKED` | the change could not be estimated, or no seam keeps intermediate states shippable. Say which, and what the smallest first slice would need |

---

## Rules that do not bend

- **Every slice ships.** Independently implementable, reviewable, mergeable and revertible.
- **UC ids are never renumbered** across slices.
- **A slice never exceeds its own declared budget**; `scope-check` reads that line and refuses
  the branch that breaks it.
- **Mechanical and behavioural changes never share a slice.** That mix is what makes a large
  diff unreviewable — the reviewer cannot tell the pattern from the exception.
- **No slice is named "refactor"** without an observable consequence. Refactoring rides inside
  the slice that needs it, or becomes a seam slice with its own tests.

---

## Not to be confused with

- **`/sdlc:backlog`** — turns a brief into tracker epics and stories. This command turns one
  approved-sized intention into shippable code slices, and writes specs, not issues.
- **`/sdlc:spec`** — writes one spec. It calls this command when its own estimate is over
  budget, and then writes the slices instead.
- **`/sdlc:arch-review`** — grades a planned architecture against availability and traffic
  numbers. It runs before the change is sliced; this runs on the slicing itself.
