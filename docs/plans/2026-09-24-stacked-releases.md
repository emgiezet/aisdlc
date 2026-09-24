# Stacked Releases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a stack of small pull requests the unit of merge and release, so a human signs off on one page instead of holding N large diffs in their head.

**Architecture:** Two gates replace the single merge decision. Gate A (`/sdlc:stack`) merges a chain of small PRs bottom-up, restacking after each squash-merge; every merge auto-deploys to staging. Gate B (`/sdlc:release-check`) treats everything on staging since the last promotion as one release set, applies the promotion rules, and emits a one-page brief plus `READY` or `HOLD`. The deploy target is pluggable through a new descriptor kind, exactly as trackers and browsers already are.

**Tech Stack:** Markdown instruction files (skills, commands, descriptors), `bash` + `jq` (`plugins/sdlc/bin/aisdlc`, `evals/harness/*`), GNU Make for the required-file and budget gates, GitHub Actions for CI.

**Spec:** No separate spec document. The requirements were fixed in the 2026-09-24 session and are restated verbatim under *Context and decisions* below; that section is the spec this plan argues from.

## Global Constraints

Copied from the repo's enforced gates. Every task's requirements implicitly include this section.

- **`Makefile:19–28` whitelists are the only registration.** Nothing is auto-discovered. A file on disk missing from its list passes silently; a name in a list with no file is a hard failure (`Makefile:121–146`).
- **Skill frontmatter:** must open with `---` on line 1 and the `description` must contain the literal words `Use when`, case-insensitive. `.github/workflows/validate.yml:29–33` fails the build otherwise.
- **Every skill needs `agents/eval-set.json`:** a JSON array of `{query, should_trigger, note}` with **at least one** `should_trigger: false` (`validate.yml:34–41`, `Makefile:128–129`).
- **Line budgets:** command ≤ 220 (`Makefile:158–162`), descriptor ≤ 120 (`Makefile:163–167`), playbook ≤ 70, `templates/CLAUDE.md` ≤ 90. New skills: 110–140 lines, matching `dense-testing` (118) and `architecture-review` (102).
- **Two marketplace manifests carry a `skills` array**, and they must stay identical: `.claude-plugin/marketplace.json` and `.omp-plugin/marketplace.json`. `.agents/plugins/` and `.grok-plugin/` carry none. This is a known trap — the previous plan asserted only one manifest listed skills and was wrong.
- **No version bump.** CI only checks `plugins/sdlc/.claude-plugin/plugin.json` `version` against the marketplace entries; adding skills or commands does not disturb them.
- **Framework stays project-agnostic** (`validate.yml:57–63`): no customer or employer names anywhere in the repo.
- **Commands never call `gh` directly.** They name a bold operation and the descriptor says how it runs (`pipeline-contracts:14–16`). Adding a capability means adding an operation, not a CLI call in a command.
- **House style for skills:** YAML frontmatter with exactly `name:` and `description: >`, `# Title` H1, a 2–3 sentence framing paragraph naming the failure mode, then `##` sections only (no H3), heavy on pipe tables, imperative voice, a `## Non-negotiable` numbered list and a `## Review checklist` of `- [ ]` lines.
- **Duplication ban** (`task-router:28–31`): a rule lives in exactly one file. Other files name the rule and point at it.

---

## Context and decisions

Fixed in session; do not re-litigate.

1. **Deployment is auto-deploy on merge to main, and the target is configurable.** Merging is therefore a deploy, not just a code decision.
2. **Staging sits between merge and production.** Merge auto-deploys to staging; production is a separate, deliberate promotion. This is the practice the harness should encode, not just describe.
3. **The pain is cognitive, not mechanical.** Too many PRs, each too large to responsibly own at the gate. Every artefact here is judged by how much it *removes* from the human's head at the decision point.
4. **The answer is PR stacking:** many small changes, each individually reviewable, merged and released as one set.

Two repo facts that shape the implementation, both verified:

- `create-pr` already accepts `{base}` (`templates/trackers/github.md:53`) and the queue already accepts `--base` (`bin/aisdlc:541`), so a stack is *expressible* today. But `update-pr` only sets title and body (`github.md:56`) — **there is no way to retarget a PR**, which is the one operation a stack cannot live without.
- `merge-pr` is `gh pr merge --squash --delete-branch` (`github.md:72`). A squash-merge rewrites the parent's commits, so after the bottom PR merges, its children are based on commits that no longer exist. Retargeting alone produces a diff full of the parent's changes. **The child must be rebased onto the new base, not merely retargeted.** This is the hard part of the feature and the reason `/sdlc:stack` exists as a command rather than as advice in a skill.

The harness already slices work into stack-shaped pieces and then forgets: `commands/spec.md:94` splits into `<TICKET>-a`, `<TICKET>-b`, and `spec-authoring:72–76` requires each slice to be independently shippable and ordered walking-skeleton-first. Nothing connects those slices into a chain.

### Out of scope

- Any third-party stacking tool (Graphite, `spr`, `git-town`). The descriptor pattern is the extension point; a tool would be a second, drifting path.
- Merge queues, trains, or auto-merge-on-green. A human still decides.
- New pipeline labels. `pipeline-contracts:104` states no priority, risk or QA-gate labels exist; keeping that true avoids touching `ensure-labels` and every tracker descriptor. Stack state lives in the release brief and in the PR base chain, both already readable.
- Changes to `/sdlc:implement`, `/sdlc:qa` or the queue's phase list.

---

## File structure

| Path | Responsibility |
|---|---|
| `plugins/sdlc/skills/pr-stacking/SKILL.md` | How to slice work into a stack, the base chain, size budget per PR, bottom-up merge order, the restack-after-squash rule, when not to stack. |
| `plugins/sdlc/skills/pr-stacking/agents/eval-set.json` | Trigger set, 5 positive / 3 negative. |
| `plugins/sdlc/skills/release-readiness/SKILL.md` | Gate B: what makes a release set promotable staging→prod — migration ordering, config precedence, flag defaults, rollback, and the sign-off compression rule. |
| `plugins/sdlc/skills/release-readiness/references/release-brief.md` | The one-page brief template the human signs. |
| `plugins/sdlc/skills/release-readiness/agents/eval-set.json` | Trigger set, 5 positive / 3 negative. |
| `plugins/sdlc/templates/deployers/TEMPLATE.md` | The deploy-target descriptor contract: operations, parameters, returns. |
| `plugins/sdlc/templates/deployers/github-actions.md` | A working provider for the default stack. |
| `plugins/sdlc/commands/stack.md` | Gate A: inspect a stack, gate each PR, merge bottom-up with a restack between each. |
| `plugins/sdlc/commands/release-check.md` | Gate B: diff staging↔prod, apply `release-readiness`, write the brief, emit `READY`/`HOLD`. |
| `plugins/sdlc/skills/pipeline-contracts/SKILL.md` | Gains the **retarget-pr** operation, the Deployer descriptor row and its operations, and two verdict tokens. |
| `plugins/sdlc/templates/trackers/{TEMPLATE,github,local}.md` | Gain **retarget-pr**. |
| `plugins/sdlc/templates/sdlc.md` | Gains a `## Deployment` section. |
| `Makefile`, both marketplace manifests, `README.md`, `plugins/sdlc/hooks/session-start` | Registration. |

Task order is dependency order: T1 gives the stack its missing operation, T2 and T3 write the knowledge, T4 makes the deploy target pluggable, T5 and T6 spend all of it, T7 proves the whole thing runs.

---

### Task 1: The `retarget-pr` operation

Without this a stack cannot survive its first merge. Doing it first means every later task can name the operation.

**Files:**
- Modify: `plugins/sdlc/skills/pipeline-contracts/SKILL.md:36` (Pull requests operation row)
- Modify: `plugins/sdlc/templates/trackers/TEMPLATE.md` (operation list, after `### update-pr`)
- Modify: `plugins/sdlc/templates/trackers/github.md:55–58` (after the `update-pr` body)
- Modify: `plugins/sdlc/templates/trackers/local.md:70–71` (after the `update-pr` body)

**Interfaces:**
- Produces: **retarget-pr** `{n} {base}` — sets the PR's base branch, returns the new base. Consumed by `commands/stack.md` (T5).

- [ ] **Step 1: Prove the operation is absent everywhere**

```bash
grep -rn 'retarget-pr' plugins/sdlc/ | wc -l
```

Expected: `0`.

- [ ] **Step 2: Add the operation to the shared vocabulary**

In `plugins/sdlc/skills/pipeline-contracts/SKILL.md`, insert **retarget-pr** directly after **update-pr** in the Pull requests row of the `## Operations` table. The row becomes, verbatim and complete — every existing operation kept in its existing order, nothing else touched, no reflow:

```
| Pull requests | **get-pr** **list-prs** **search-prs** **create-pr** **update-pr** **retarget-pr** **comment-pr** **label-pr** **unlabel-pr** **assign-pr** **review-pr** **merge-pr** **get-pr-diff** **get-pr-checks** **get-run-failed-logs** **checkout-pr** **rerun-check** **attach-image-evidence** |
```

- [ ] **Step 3: Add the parameter contract to the tracker TEMPLATE**

In `plugins/sdlc/templates/trackers/TEMPLATE.md`, in the `## Operations` list, directly below the `### update-pr` line, add:

```markdown
### retarget-pr     {n} {base} → the new base branch, read back from the PR
```

- [ ] **Step 4: Implement it for GitHub**

In `plugins/sdlc/templates/trackers/github.md`, directly after the `### update-pr` body and its two explanatory lines, add:

````markdown
### retarget-pr
`gh api -X PATCH repos/{owner}/{repo}/pulls/{n} -f 'base={base}' --jq '.base.ref'`
Returns: the base branch GitHub now reports. Not `gh pr edit --base`, for the same reason
`update-pr` avoids `gh pr edit`. A retarget on a PR whose head was rebased is only half the job:
the rebase is `/sdlc:stack`'s, and it happens first.
````

- [ ] **Step 5: Implement it for the local tracker**

`local.md:69` already stores `baseRefName` on every PR record, so this is a field update. Directly after the `### update-pr` body, add:

````markdown
### retarget-pr
`jq -c --argjson n {n} --arg base '{base}' 'if .number==$n then .baseRefName=$base else . end' $P > $P.tmp && mv $P.tmp $P; jq -r --argjson n {n} 'select(.number==$n).baseRefName' $P`
````

- [ ] **Step 6: Verify all four files agree**

```bash
grep -rln 'retarget-pr' plugins/sdlc/ | sort
```

Expected exactly these four, and nothing else:

```
plugins/sdlc/skills/pipeline-contracts/SKILL.md
plugins/sdlc/templates/trackers/TEMPLATE.md
plugins/sdlc/templates/trackers/github.md
plugins/sdlc/templates/trackers/local.md
```

Then confirm the descriptors stay inside their budget and everything still parses:

```bash
CI= make validate 2>&1 | tail -3
```

Expected: `All checks passed.` (Run `make validate` without `CI=` only if every slop-guard linter is installed; under `CI=true` the strict config check fails on absent third-party tools, which is unrelated to this work.)

- [ ] **Step 7: Commit**

```bash
git add plugins/sdlc/skills/pipeline-contracts/SKILL.md plugins/sdlc/templates/trackers/
git commit -m "feat(contracts): add retarget-pr — the operation a PR stack cannot live without"
```

---

### Task 2: The `pr-stacking` skill

**Files:**
- Create: `plugins/sdlc/skills/pr-stacking/SKILL.md`
- Create: `plugins/sdlc/skills/pr-stacking/agents/eval-set.json`
- Modify: `Makefile:24` (`SKILLS`)
- Modify: `.claude-plugin/marketplace.json` (skills array, alphabetical)
- Modify: `.omp-plugin/marketplace.json` (skills array, alphabetical)
- Modify: `README.md:5`, `README.md:35`, skills table after the `harness-eval` row
- Modify: `plugins/sdlc/hooks/session-start` (skill announcement list)

**Interfaces:**
- Consumes: **retarget-pr** from T1.
- Produces: the vocabulary `/sdlc:stack` (T5) applies — the terms *stack*, *base chain*, *bottom PR*, *restack*, and the size budget.

- [ ] **Step 1: Register the skill before it exists, and watch validate fail**

Append `pr-stacking` to the end of the `SKILLS :=` line in `Makefile:24`. Then:

```bash
CI= make validate 2>&1 | grep -A1 'pr-stacking'
```

Expected: `✗ skills/pr-stacking/SKILL.md MISSING` and a non-zero exit. This is the registration gate proving it works.

- [ ] **Step 2: Write the skill**

Create `plugins/sdlc/skills/pr-stacking/SKILL.md`, 110–140 lines. Frontmatter exactly:

```yaml
---
name: pr-stacking
description: >
  How to ship a chain of small pull requests instead of one large one — slicing the work, the
  base chain, the size budget that keeps a PR reviewable, merging bottom-up, and the restack
  every squash-merge forces on the children. Use when a change is too large to review in one
  PR, when splitting a spec into slices, when deciding what may merge now, or when a stacked
  PR's diff suddenly shows its parent's changes.
---
```

Sections, in this order, each carrying the stated load-bearing content:

1. `## Why a stack` — the failure this prevents: a reviewer who cannot hold the diff in their head approves it anyway, so review becomes a ritual and nobody can honestly own the merge. A stack trades one unreviewable PR for four reviewable ones. State the cost plainly too: N PRs means N merges, N deploys to staging, and a restack after each.
2. `## When not to stack` — a single-concern change under the size budget; a change whose slices cannot each keep the suite green; a hotfix. A stack of one is a PR. Stacking a change that does not decompose produces a chain where every PR is broken until the last, which is worse than a large PR because now the reviewer must also simulate the future.
3. `## Anatomy` — table `Term | Meaning`. Rows: *stack* (an ordered chain of PRs, each based on the one below); *bottom PR* (based on the default base ref, the only one that can merge first); *base chain* (`main ← a ← b ← c`); *restack* (rebasing the children after the parent's squash-merge rewrote its commits); *stack root spec* (the `<TICKET>` whose `-a`/`-b` slices are the stack members).
4. `## Building a stack from a spec` — the harness already splits: `/sdlc:spec` writes `<TICKET>-a`, `<TICKET>-b` when a spec exceeds ~8 use cases or two stacks (`spec-authoring` owns the split rules — name them, do not restate them). Each slice is queued with `--base` set to the previous slice's branch, so the PRs come out stacked:

   ```bash
   aisdlc add ABC-123-a --repo .                                  # base: origin/main
   aisdlc add ABC-123-b --repo . --base ai/ABC-123-a-<slug>
   ```

   The bottom slice is the walking skeleton. Ordering the stack any other way means the bottom PR is the one nobody can review without the others.
5. `## Size budget` — table `Signal | Budget | What to do when it's exceeded`. Rows: changed lines per PR (~400 excluding generated files and lock files → split at the seam the spec already names); files touched (~15); concerns per PR (exactly 1 — a PR that needs "and" in its title is two PRs); PRs per stack (~5 — beyond that, the stack itself is the thing nobody can hold, and the slices should ship as separate stacks over separate days); review time (if a reviewer cannot judge it in 20 minutes it is not reviewable, whatever the line count). State that generated files and lock files are excluded from the count but named in the PR body, because a 4,000-line lock diff is not a review burden and pretending it is corrupts the budget.
6. `## Merging a stack` — bottom-up, one at a time, never in parallel. The full sequence, and the reason each step exists:
   1. The bottom PR passes its own gates and merges (squash).
   2. Its branch is deleted; **its commits no longer exist** — the squash produced one new commit on main.
   3. Every child is now based on a deleted branch. Rebase each child onto the new base *before* retargeting it: `git rebase --onto origin/main <old-parent-branch> <child-branch>`.
   4. **retarget-pr** the next child to the default base ref, then force-push the rebased branch. This is the one place the harness force-pushes, and it is `/sdlc:stack`'s job, not a human's — `hooks/guard` blocks `--force` from agent sessions by design.
   5. Re-run CI on the retargeted child before merging it. A green check from before the rebase proves nothing about the code that exists now.

   State the failure mode explicitly: retargeting without rebasing makes the child's diff include everything the parent changed, the review becomes meaningless, and the merge reverts nothing but looks enormous.
7. `## Drift and conflicts` — a stack is a claim that nothing else will touch these files. Rebase the whole stack onto the base at least daily; a stack older than a few days is a merge conflict with a delivery date. When two stacks touch the same file, one of them is wrong about its boundaries — fix the slicing, do not resolve the same conflict five times.
8. `## Non-negotiable` — numbered "Never" list: never merge a stack out of order; never retarget a child without rebasing it first; never force-push a branch that is not a stack member being restacked; never let a stack member ship a broken suite on the promise that the next PR fixes it; never grow a stack past the point where its own reviewer cannot say what it does in one sentence.
9. `## Review checklist` — `- [ ]` list mirroring sections 4–7, one line each.

- [ ] **Step 3: Write the trigger set**

Create `plugins/sdlc/skills/pr-stacking/agents/eval-set.json` exactly:

```json
[
  {"query": "This PR is 2000 lines, how do I break it up?", "should_trigger": true, "note": "size budget and slicing are the core"},
  {"query": "I merged the bottom PR and now the next one shows all its changes", "should_trigger": true, "note": "the restack-after-squash trap, stated symptom-first"},
  {"query": "Can I merge these three PRs in any order?", "should_trigger": true, "note": "bottom-up merge order"},
  {"query": "Split ABC-123 into slices I can review one at a time", "should_trigger": true, "note": "building a stack from a split spec"},
  {"query": "What base branch should this second PR target?", "should_trigger": true, "note": "the base chain"},
  {"query": "Is this release safe to promote to production?", "should_trigger": false, "note": "release-readiness owns the promotion gate"},
  {"query": "How many tests does this endpoint need?", "should_trigger": false, "note": "dense-testing owns density floors"},
  {"query": "Write the use-case table for ABC-204", "should_trigger": false, "note": "spec-authoring owns spec format"}
]
```

- [ ] **Step 4: Run the gates that just failed**

```bash
CI= make validate 2>&1 | tail -3
make eval-dry | grep pr-stacking
wc -l plugins/sdlc/skills/pr-stacking/SKILL.md
```

Expected: `All checks passed.`, `✓ pr-stacking      trigger:5  no-trigger:3`, and a line count between 110 and 140.

- [ ] **Step 5: Register in both marketplaces**

Insert `"./skills/pr-stacking"` into the `sdlc` plugin's alphabetically-ordered `skills` array — after `"./skills/pipeline-contracts"` — in **both** `.claude-plugin/marketplace.json` and `.omp-plugin/marketplace.json`.

Verify the three lists agree; this cross-check exists in no test:

```bash
diff <(jq -r '.plugins[]|select(.name=="sdlc")|.skills[]' .claude-plugin/marketplace.json) \
     <(jq -r '.plugins[]|select(.name=="sdlc")|.skills[]' .omp-plugin/marketplace.json) \
  && diff <(jq -r '.plugins[]|select(.name=="sdlc")|.skills[]' .claude-plugin/marketplace.json | sed 's|^./skills/||' | sort) \
          <(grep '^SKILLS :=' Makefile | cut -d= -f2 | tr ' ' '\n' | grep -v '^$' | sort) \
  && echo "ok all three lists agree"
```

Expected: `ok all three lists agree`, no diff output.

- [ ] **Step 6: Announce it and document it**

In `plugins/sdlc/hooks/session-start`, append to the skill list (the block that currently ends with the `discovery` line), aligning the dash column with its neighbours:

```
- pr-stacking         — small PRs in a chain: base chain, size budget, bottom-up merge, restack
```

In `README.md`: line 5 `10 skills` → `11 skills`; line 35 `the ten knowledge skills` → `the eleven knowledge skills`; and one row at the end of the skills table:

```markdown
| `pr-stacking` | Slicing a large change into a reviewable chain, the base chain, the per-PR size budget, bottom-up merge order, and the restack every squash-merge forces. |
```

- [ ] **Step 7: Commit**

```bash
git add Makefile README.md .claude-plugin/marketplace.json .omp-plugin/marketplace.json \
        plugins/sdlc/hooks/session-start plugins/sdlc/skills/pr-stacking
git commit -m "feat(skills): add pr-stacking — small PRs in a chain, merged bottom-up"
```

---

### Task 3: The `release-readiness` skill

**Files:**
- Create: `plugins/sdlc/skills/release-readiness/SKILL.md`
- Create: `plugins/sdlc/skills/release-readiness/references/release-brief.md`
- Create: `plugins/sdlc/skills/release-readiness/agents/eval-set.json`
- Modify: `Makefile:24`, both marketplace manifests, `README.md:5`, `README.md:35`, skills table, `plugins/sdlc/hooks/session-start`

**Interfaces:**
- Produces: the verdict tokens `READY` and `HOLD`, the brief format, and the promotion gate table — all consumed by `commands/release-check.md` (T6).
- The brief template lives in `references/release-brief.md`, following `discovery/references/brief-template.md` and `architecture-review/references/targets-template.md`.

- [ ] **Step 1: Register first, watch it fail**

Append `release-readiness` to `Makefile:24`. Run `CI= make validate 2>&1 | grep -A1 'release-readiness'`. Expected: `✗ skills/release-readiness/SKILL.md MISSING`.

- [ ] **Step 2: Write the skill**

Create `plugins/sdlc/skills/release-readiness/SKILL.md`, 110–140 lines. Frontmatter exactly:

```yaml
---
name: release-readiness
description: >
  The gate between staging and production — what makes a set of merged changes promotable,
  migration and config ordering, feature-flag defaults, the rollback path, and the one-page
  brief a human can actually take responsibility for. Use when deciding what goes to
  production, whether a release set is safe to promote, what to prepare before a deploy, or
  when a release is too large to sign off with confidence.
---
```

Sections, in this order:

1. `## Two gates, not one` — table `Gate | Question | Blast radius | Who decides`. Rows: merge (is this safe *on staging* — cheap, revertible, auto-deployed) and promote (is this safe *for users* — the set, not the PR). Name the trap: when merge auto-deploys, teams apply the production bar at merge time and slow every PR down, or the staging bar at promote time and ship surprises. The bar belongs at the promotion, and the merge gate stays cheap.
2. `## The release set` — everything merged since the last promotion, which is *not* the same as the stack you just merged. Two commands: what the deploy target says is live (**current-release**) and what is on staging (**env-diff**). The set is the difference. A release set nobody enumerated is the most common cause of "we didn't know that was in there".
3. `## Promotion gate` — table `Check | HOLD reason`. Rows, each phrased as the exact line the command prints: every set member verified on staging, not merely deployed there; migrations applied on staging and reversible or expand-only; every new config key and secret already present in production; new behaviour behind a flag that defaults to off; no API or contract change that breaks a client still in flight (name `rest-api-design` / `graphql-api-design` for the breaking-change tables, do not restate them); a rollback path that has an owner and a command; the brief exists and names a signer.
4. `## Migration ordering` — expand/contract, stated as a sequence the set must respect: add the nullable column and write to both (ships first), backfill (ships separately), read from the new path (ships after the backfill completes), drop the old (a later release, never the same one). A destructive migration in the same set as the code that stopped using the column is a rollback that cannot roll back. State the rule: **a release is rollback-safe only if every migration in it is forward-compatible with the previous release's code.**
5. `## Config and secrets` — config lands in production *before* the code that reads it, always, and that ordering is the opposite of the code's dependency direction, which is why it is forgotten. A missing key discovered at promote time is a HOLD, not a quick fix, because it means nothing verified on staging proves anything about production.
6. `## Rollback` — table `Situation | Action`. Rows: bad code, no migration → redeploy the previous release; bad code, expand-only migration → redeploy previous, the column is harmless; bad code, destructive migration → forward-fix only, and this is why the gate forbids it; one bad PR in a good set → revert that PR and re-promote, never hand-edit production. State that "we'd roll back" without a tested command is not a rollback path.
7. `## The brief is the deliverable` — the compression rule, which is the point of this skill: **a human signs one page, not N diffs.** The brief states, for the whole set: what a user will notice, the blast radius, the migrations, the config, the flags, the rollback command, and what was verified on staging and how. If the set cannot be compressed to one page, the set is too large — promote a prefix of it instead. Template: [`references/release-brief.md`](references/release-brief.md).
8. `## Non-negotiable` — numbered "Never" list: never promote a set nobody enumerated; never ship a destructive migration in the same release as the code that stopped using the column; never promote with a config key missing in the target; never promote on a staging verification nobody performed; never sign a brief you did not read because the set was too big to read.
9. `## Review checklist` — `- [ ]` list mirroring sections 2–7.

- [ ] **Step 3: Write the brief template**

Create `plugins/sdlc/skills/release-readiness/references/release-brief.md` — the blank a command fills, ≤ 60 lines, every section present with a one-line instruction in angle brackets:

```markdown
# Release <YYYY-MM-DD> — <n> changes

**Set:** <first-sha>..<last-sha> · **Target:** <env> · **Signer:** <@who>

## What a user will notice
<one bullet per user-visible change, in the user's words, not the PR title. "Nothing" is a
valid and common answer — say it rather than padding.>

## Contents
| PR | Change | Risk | Verified on staging |
|---|---|---|---|
| #<n> | <one line> | low/medium/high | <what was checked, by whom> |

## Migrations
<one row per migration: expand or contract, reversible yes/no, applied on staging when. "None"
is a complete answer.>

## Config and secrets
<every new key, and confirmation it exists in the target already. "None" is a complete answer.>

## Flags
<every new flag and its default in the target.>

## Rollback
**Command:** <the exact command> · **Owner:** <@who> · **Tested:** <when, or "never">

## Not verified
<everything the staging run did not cover. An empty section here is a lie; write what you
could not check.>
```

- [ ] **Step 4: Write the trigger set**

Create `plugins/sdlc/skills/release-readiness/agents/eval-set.json` exactly:

```json
[
  {"query": "Is this safe to promote to production?", "should_trigger": true, "note": "the promotion gate is the core"},
  {"query": "What should I prepare before tomorrow's release?", "should_trigger": true, "note": "the prepare-to-release question, in the user's words"},
  {"query": "Can I ship this migration in the same release as the code that stops using the column?", "should_trigger": true, "note": "expand/contract ordering and rollback safety"},
  {"query": "Write the release notes for everything on staging", "should_trigger": true, "note": "the brief is the deliverable"},
  {"query": "How do we roll this back if it goes wrong?", "should_trigger": true, "note": "rollback table"},
  {"query": "How do I break this 2000-line PR into smaller ones?", "should_trigger": false, "note": "pr-stacking owns slicing and the size budget"},
  {"query": "What status code should this endpoint return?", "should_trigger": false, "note": "rest-api-design owns status codes"},
  {"query": "Set up a GitHub Actions workflow for this repo", "should_trigger": false, "note": "CI authoring, not release judgement"}
]
```

- [ ] **Step 5: Run the gates**

```bash
CI= make validate 2>&1 | tail -3
make eval-dry | grep release-readiness
wc -l plugins/sdlc/skills/release-readiness/SKILL.md plugins/sdlc/skills/release-readiness/references/release-brief.md
```

Expected: `All checks passed.`, `✓ release-readiness trigger:5  no-trigger:3`, SKILL.md 110–140 lines, template ≤ 60.

- [ ] **Step 6: Register and document**

Both marketplace manifests: insert `"./skills/release-readiness"` after `"./skills/pr-stacking"`. Re-run the three-list agreement check from Task 2 Step 5. `README.md`: `11 skills` → `12 skills`, `the eleven knowledge skills` → `the twelve knowledge skills`, plus:

```markdown
| `release-readiness` | The staging→production gate: enumerate the set, migration and config ordering, flag defaults, the rollback path, and the one-page brief a human signs. |
```

`plugins/sdlc/hooks/session-start`, after the `pr-stacking` line:

```
- release-readiness   — staging→prod gate: the set, migrations, config, flags, rollback, the brief
```

- [ ] **Step 7: Commit**

```bash
git add Makefile README.md .claude-plugin/marketplace.json .omp-plugin/marketplace.json \
        plugins/sdlc/hooks/session-start plugins/sdlc/skills/release-readiness
git commit -m "feat(skills): add release-readiness — the promotion gate and the one-page brief"
```

---

### Task 4: The deployer descriptor kind

**Files:**
- Create: `plugins/sdlc/templates/deployers/TEMPLATE.md`
- Create: `plugins/sdlc/templates/deployers/github-actions.md`
- Modify: `Makefile:28` (add `DEPLOYERS`), `Makefile:139–142` (required-file loop), `Makefile:163–167` (descriptor budget loop)
- Modify: `plugins/sdlc/templates/sdlc.md` (new `## Deployment` section after `## Browser`)
- Modify: `plugins/sdlc/skills/pipeline-contracts/SKILL.md:20–23` (descriptor table) and `:32–41` (operations table)
- Modify: `plugins/sdlc/commands/init.md` (the descriptor-copying paragraph at lines 40–44)

**Interfaces:**
- Produces: **deploy-status** `{env}`, **current-release** `{env}`, **env-diff** `{from-env} {to-env}`, **pending-migrations** `{env}`, **promote** `{ref} {env}`, **rollback** `{env} {ref}`. Consumed by `commands/release-check.md` (T6).
- Profile key: **Deployer descriptor**, resolving to `.claude/deployers/<provider>.md`, default `none`.

- [ ] **Step 1: Add the whitelist entry and watch it fail**

In `Makefile`, after the `BROWSERS :=` line (line 28), add:

```make
DEPLOYERS := TEMPLATE github-actions
```

Then add a required-file loop mirroring the browsers loop at `Makefile:139–142`:

```make
	@for d in $(DEPLOYERS); do \
		test -f plugins/sdlc/templates/deployers/$$d.md && echo "  ✓ templates/deployers/$$d.md" || \
		(echo "  ✗ templates/deployers/$$d.md MISSING" && exit 1); \
	done
```

and extend the descriptor budget loop at `Makefile:163` so it reads:

```make
	@for d in $(addprefix trackers/,$(TRACKERS)) $(addprefix browsers/,$(BROWSERS)) $(addprefix deployers/,$(DEPLOYERS)); do
```

Run:

```bash
CI= make validate 2>&1 | grep -A1 'deployers'
```

Expected: `✗ templates/deployers/TEMPLATE.md MISSING`.

- [ ] **Step 2: Write the descriptor contract**

Create `plugins/sdlc/templates/deployers/TEMPLATE.md`, ≤ 120 lines, structured exactly like `templates/trackers/TEMPLATE.md`: a `# Deploy target: {name}` heading, the copy-and-fill instruction, a rules list, `## Prerequisites`, `## Conventions`, `## Operations` with one `### <operation>` per line and a `Returns:` line each. The rules that matter, stated as rules:

- One `### <operation>` per heading; an empty heading strands every command that names it.
- Read-only operations must be safe to run at any time. **promote** and **rollback** are the only mutating ones, and both read back what they did before reporting success.
- **promote** never force-deploys and never skips the target's own checks. There is no `--force`; a refused promotion is a human's problem by design, exactly as `/sdlc:merge` has no force flag.
- Environments are named by the project, not by this file. `{env}` is whatever string the profile uses (`staging`, `prod`, `production`).
- `none` is a valid configuration: `/sdlc:release-check` then works from git history alone and says in one line which checks it could not perform.

Operations, with parameters and returns:

```markdown
### deploy-status        {env} → state (succeeded|failed|in-progress|unknown), ref, finished-at
### current-release      {env} → the ref (sha or tag) currently live in that environment
### env-diff             {from-env} {to-env} → one line per commit present in from but not to: sha, subject, PR number when derivable
### pending-migrations   {env} → one line per migration present in the code but not applied in that environment; empty output means none
### promote              {ref} {env} → the deployment id or run url, read back with deploy-status
### rollback             {env} {ref} → the deployment id or run url, read back with deploy-status
```

- [ ] **Step 3: Write the GitHub Actions provider**

Create `plugins/sdlc/templates/deployers/github-actions.md`, ≤ 120 lines, same section layout, with `{placeholder}` values wherever the answer is repo-specific — `/sdlc:init` fills these, exactly as it does for trackers. Bodies:

````markdown
### deploy-status
`gh run list --workflow {deploy-workflow} --branch {branch} --limit 1 --json conclusion,headSha,updatedAt --jq '.[0] | "\(.conclusion // "in-progress") \(.headSha) \(.updatedAt)"'`

### current-release
`gh api repos/{owner}/{repo}/deployments -X GET -f environment={env} --jq '.[0].sha'`
Returns: the sha GitHub records as most recently deployed to `{env}`. Projects that tag instead
of using the Deployments API replace this with `git describe --tags --abbrev=0 {env-tag-pattern}`.

### env-diff
`git fetch --quiet origin && git log --oneline --no-merges $(gh api repos/{owner}/{repo}/deployments -X GET -f environment={to-env} --jq '.[0].sha')..$(gh api repos/{owner}/{repo}/deployments -X GET -f environment={from-env} --jq '.[0].sha')`

### pending-migrations
`{the project's migration status command, e.g. migrate -database "$DATABASE_URL_{env}" status}`

### promote
`gh workflow run {promote-workflow} -f ref={ref} -f environment={env} && sleep 5 && gh run list --workflow {promote-workflow} --limit 1 --json databaseId,url --jq '.[0].url'`

### rollback
`gh workflow run {promote-workflow} -f ref={ref} -f environment={env} && sleep 5 && gh run list --workflow {promote-workflow} --limit 1 --json databaseId,url --jq '.[0].url'`
Rollback is a promotion of an older ref. A target whose deploy is not idempotent needs its own
body here, and that is a finding about the deploy pipeline, not about this file.
````

- [ ] **Step 4: Add the profile keys**

In `plugins/sdlc/templates/sdlc.md`, directly after the `## Browser` section, add:

```markdown
## Deployment

- **Deployer descriptor:** `none`
  <!-- .claude/deployers/github-actions.md | none. Copied from the plugin's templates/deployers/
       by /sdlc:init. Commands name operations (**current-release**); this file runs them.
       none → /sdlc:release-check works from git history and says what it could not check. -->
- **Environments:** `none`
  <!-- ordered, lowest first, e.g. staging, production. The last one is the promotion target. -->
- **Merge deploys to:** `none`
  <!-- the environment a merge to the default base ref reaches automatically, e.g. staging -->
- **Promotion:** `manual`
  <!-- manual | none. manual → /sdlc:release-check gates it and a human runs promote. -->
```

- [ ] **Step 5: Teach the vocabulary skill about it**

In `plugins/sdlc/skills/pipeline-contracts/SKILL.md`, add a third row to the `## Descriptors` table (lines 20–23):

```markdown
| **Deployer descriptor** | `.claude/deployers/<provider>.md` | `templates/deployers/{github-actions,TEMPLATE}.md` |
```

and a row to the `## Operations` table, after the Browser row:

```markdown
| Deploy | **deploy-status** **current-release** **env-diff** **pending-migrations** **promote** **rollback** |
```

Then extend the line under the operations table so it names all three TEMPLATEs:

```markdown
Parameters and returns: `templates/trackers/TEMPLATE.md`, `templates/browsers/TEMPLATE.md`,
`templates/deployers/TEMPLATE.md`.
```

- [ ] **Step 6: Teach `/sdlc:init` to copy it**

In `plugins/sdlc/commands/init.md`, the paragraph at lines 40–44 lists the templates to start from and states that tracker and browser descriptors are copied **verbatim**. Add `deployers/*.md` to that list and to the verbatim rule — the wording must keep the existing distinction that `CLAUDE.md`, `AGENTS.md` and the playbooks are *rewritten* while descriptors are *copied*.

- [ ] **Step 7: Verify**

```bash
CI= make validate 2>&1 | grep -E 'deployers|descriptor within'
CI= make validate 2>&1 | tail -3
```

Expected: `✓ templates/deployers/TEMPLATE.md`, `✓ templates/deployers/github-actions.md`, `✓ every descriptor within 120 lines`, `All checks passed.`

- [ ] **Step 8: Commit**

```bash
git add Makefile plugins/sdlc/templates/deployers plugins/sdlc/templates/sdlc.md \
        plugins/sdlc/skills/pipeline-contracts/SKILL.md plugins/sdlc/commands/init.md
git commit -m "feat(descriptors): add the deployer descriptor kind — configurable deploy target"
```

---

### Task 5: `/sdlc:stack`

**Files:**
- Create: `plugins/sdlc/commands/stack.md`
- Modify: `Makefile:19–23` (`COMMANDS`)
- Modify: `plugins/sdlc/commands/merge.md` (a cross-reference in `## Not to be confused with`)
- Modify: `plugins/sdlc/skills/pipeline-contracts/SKILL.md` (verdict tokens table — the `MERGED` row)
- Modify: `README.md:5` (command count) and the command table
- Modify: `plugins/sdlc/hooks/session-start` (command announcement)

**Interfaces:**
- Consumes: **retarget-pr** (T1), the `pr-stacking` skill (T2), and the existing **get-pr**, **list-prs**, **get-pr-checks**, **review-pr**, **merge-pr**, **comment-pr**, **claim**, **release** operations.
- Produces: the report block ending in the chain markers from `pipeline-contracts:43–55`.

- [ ] **Step 1: Register and watch it fail**

Append `stack` to the `COMMANDS :=` list in `Makefile` (the `review fix-pr review-prs autopilot continue merge merge-buddy …` line is the natural home — it groups post-PR commands). Run:

```bash
CI= make validate 2>&1 | grep -A1 'commands/stack'
```

Expected: `✗ commands/stack.md MISSING`.

- [ ] **Step 2: Write the command**

Create `plugins/sdlc/commands/stack.md`, ≤ 220 lines, following the structure of `commands/merge.md`: YAML frontmatter with `description:` and `allowed-tools:`, an `# /sdlc:stack` heading, an `$ARGUMENTS` line, then numbered `## Phase N: <name> [GATE|REQUIRED|HARD STOP]` sections and a final report block.

- Frontmatter `description:` must state what it does and carry a `Use …` sentence, matching its siblings. `allowed-tools: Bash, Read, Grep, Glob, SlashCommand`.
- `$ARGUMENTS` is `<TICKET|pr#> [--merge] [--restack]`. Default with neither flag: inspect and report, mutate nothing.
- **Interactive-only**, for the same reason `/sdlc:merge` is: this command merges to a branch that auto-deploys. Say so in the body and keep it out of `ALL_PHASES`.
- **Load the `pr-stacking` skill** in the same phrasing `/sdlc:merge` and `/sdlc:spec` use for skills. The rules are the skill's; this file is the sequence.

Phases:

1. **Discover the stack [HARD STOP].** From a ticket id: **search-prs** for open PRs whose head branch matches `ai/<TICKET>*`. From a PR number: **get-pr**, then walk the base chain up and down until both ends are reached. Order them bottom-first by base chain, not by number — PR numbers are creation order and lie about dependency. Print the chain and stop here unless `--merge` or `--restack` was passed. A chain with a cycle, a missing base, or two PRs sharing a base is a hard stop with one line naming the two PRs.
2. **Gate every member [GATE].** Apply `/sdlc:merge`'s four gates (label `merge-ready`, CI green, no conflicts, QA verdict) to **every** member before merging **any**. Print a per-PR table: `#n | gate | pass/fail`. Any failure → stop and print which member blocks the stack. Rationale, stated in the file: merging a prefix of a stack and discovering the third PR is not ready leaves the deploy target in a state nobody planned.
3. **Merge bottom-up [REQUIRED].** For each member in order: **review-pr** approve, **merge-pr** (squash), then before touching the next one — `git fetch`, rebase the next member onto the default base ref with `git rebase --onto <base> <merged-branch> <next-branch>`, force-push it, **retarget-pr** it to the base ref, and **rerun-check** it. Wait for checks to go green before merging it. A conflict during a rebase stops the whole command: report which member conflicted, leave everything merged so far merged, and say plainly that the remainder of the stack now needs a human.
4. **Report.** A block naming every merged PR, the new base of any unmerged remainder, and the chain markers. End with `Verdict: MERGED` when the whole stack landed, or `⚠ NEEDS HUMAN` with the blocking member.

Also state, in a short `## Not to be confused with` section: `/sdlc:merge` merges one PR; this merges a chain. `/sdlc:release-check` decides what goes to production; this only merges, which reaches staging.

- [ ] **Step 3: Register the verdict token**

`Verdict: MERGED` is emitted by Phase 4 and no consumer knows it yet. In `plugins/sdlc/skills/pipeline-contracts/SKILL.md`, add a row to the `## Verdict tokens` table, above the `any autofix loop` row:

```markdown
| `/sdlc:stack` | `MERGED` | the whole chain landed; a partial merge reports `⚠ NEEDS HUMAN` instead |
```

A token a command prints but the vocabulary does not list is exactly the drift `pipeline-contracts:14–16` exists to prevent.

- [ ] **Step 4: Cross-reference from `/sdlc:merge`**

In `plugins/sdlc/commands/merge.md`, in the existing `## Not to be confused with` section, add one line: a PR that is part of a stack is merged by `/sdlc:stack`, because merging it alone strands its children on a deleted branch.

- [ ] **Step 5: Verify**

```bash
CI= make validate 2>&1 | grep -E 'commands/stack|command within'
CI= make validate 2>&1 | tail -3
awk 'END{print NR" lines"}' plugins/sdlc/commands/stack.md
```

Expected: `✓ commands/stack.md`, `✓ every command within 220 lines`, `All checks passed.`

- [ ] **Step 6: Announce and document**

`plugins/sdlc/hooks/session-start`, in the `After the PR:` block, add `/${NAME}:stack` with a four-word gloss. `README.md` line 5: `31 commands` → `32 commands`, and a row in the command table beside the other post-PR commands.

- [ ] **Step 7: Commit**

```bash
git add Makefile README.md plugins/sdlc/commands/stack.md plugins/sdlc/commands/merge.md \
        plugins/sdlc/skills/pipeline-contracts/SKILL.md plugins/sdlc/hooks/session-start
git commit -m "feat(commands): add /sdlc:stack — merge a PR chain bottom-up with a restack between"
```

---

### Task 6: `/sdlc:release-check`

**Files:**
- Create: `plugins/sdlc/commands/release-check.md`
- Modify: `Makefile:19–23` (`COMMANDS`)
- Modify: `plugins/sdlc/skills/pipeline-contracts/SKILL.md:59–67` (verdict tokens table)
- Modify: `plugins/sdlc/commands/changelog.md` (one cross-reference line)
- Modify: `README.md:5` and the command table, `plugins/sdlc/hooks/session-start`

**Interfaces:**
- Consumes: the deployer operations (T4), the `release-readiness` skill and its brief template (T3).
- Produces: `specs/releases/<YYYY-MM-DD>.md` (the brief) and the verdict tokens `READY` / `HOLD`.

- [ ] **Step 1: Register and watch it fail**

Append `release-check` to `COMMANDS` in the `Makefile`. Run `CI= make validate 2>&1 | grep -A1 'commands/release-check'`. Expected: `✗ commands/release-check.md MISSING`.

- [ ] **Step 2: Add the verdict tokens to the shared vocabulary**

In `plugins/sdlc/skills/pipeline-contracts/SKILL.md`, add a row to the `## Verdict tokens` table:

```markdown
| `/sdlc:release-check` | `READY` `HOLD` | the promotion decision for a release set |
```

- [ ] **Step 3: Write the command**

Create `plugins/sdlc/commands/release-check.md`, ≤ 220 lines, same structural conventions as `commands/merge.md` and `commands/arch-review.md`.

- `$ARGUMENTS` is optionally `--to <env>` (default: the last entry in the profile's **Environments**) and `--since <ref>` (default: **current-release** of the target).
- Read `.claude/sdlc.md` for the **Deployer descriptor**, **Environments**, **Merge deploys to** and **Promotion**. **Load the `release-readiness` skill** — it holds the gate table, the ordering rules and the brief format this command applies.
- This command **never promotes.** It decides and writes the brief; a human runs **promote**. State that explicitly, in the same voice `/sdlc:merge` uses for "merging is a human decision".

Phases:

1. **Resolve the set [HARD STOP].** **current-release** of the target, **current-release** of the source environment, then **env-diff** between them. No deployer descriptor → fall back to `git log <last-tag>..origin/main` and print one line saying which checks are unavailable. An empty set → print `nothing to promote — <target> is level with <source>` and stop.
2. **Attribute the set.** For each commit, resolve its PR (**get-pr** or **search-prs** by sha) and its ticket. A commit with no PR is a finding, not a footnote: it reached the default branch outside the pipeline.
3. **Apply the gate [GATE].** Walk the `release-readiness` promotion table row by row. Use **pending-migrations** for the migration row and **deploy-status** for the staging-verification row. Collect every failure as a `HOLD: <reason>` line; do not stop at the first, because the point is to hand back the complete list once.
4. **Write the brief [REQUIRED].** Fill `references/release-brief.md` into `specs/releases/<YYYY-MM-DD>.md`. Every section present; `Not verified` is never empty. If the set does not compress to one page, say so and recommend promoting a prefix, naming the sha to cut at.
5. **Report.** The brief path, then every `HOLD:` line, then `Verdict: READY` or `Verdict: HOLD`, then the chain markers. `READY` prints the exact **promote** invocation for the human to run — it does not run it.

- [ ] **Step 4: Cross-reference from `/sdlc:changelog`**

`commands/changelog.md` already describes itself as running "at the end of a release cycle before tagging". Add one line: the release brief from `/sdlc:release-check` is the input a changelog entry summarises; the brief decides, the changelog records.

- [ ] **Step 5: Verify**

```bash
CI= make validate 2>&1 | grep -E 'commands/release-check|command within'
CI= make validate 2>&1 | tail -3
```

Expected: `✓ commands/release-check.md`, `✓ every command within 220 lines`, `All checks passed.`

- [ ] **Step 6: Announce and document**

`session-start`: add a `Release:` line naming `/${NAME}:release-check`. `README.md` line 5: `32 commands` → `33 commands`, plus a command-table row.

- [ ] **Step 7: Commit**

```bash
git add Makefile README.md plugins/sdlc/commands/release-check.md \
        plugins/sdlc/commands/changelog.md plugins/sdlc/skills/pipeline-contracts/SKILL.md \
        plugins/sdlc/hooks/session-start
git commit -m "feat(commands): add /sdlc:release-check — the promotion gate and the release brief"
```

---

### Task 7: Prove it runs

Instruction files that were never executed are a hypothesis. The previous plan's lesson was exact: a skill nobody exercises is a skill nobody follows, and the harness's own scoring caught a defect no amount of review had. `/sdlc:stack` and `/sdlc:release-check` are interactive-only and therefore cannot be a `evals/harness/scenarios/*` case — the queue's phase list is fixed (`bin/aisdlc:28`). So the proof is a scripted smoke run against the `local` tracker, which needs no network and no GitHub.

**Files:**
- No repo files change. This task produces evidence.

- [ ] **Step 1: Build a scratch repo with a three-PR stack**

```bash
T=$(mktemp -d); cd "$T"
git init -q -b main && git config user.email t@localhost && git config user.name t
mkdir -p .aisdlc/tracker && printf 'seed\n' > README.md
git add -A && git commit -qm "chore: seed"
for s in a b c; do
  git checkout -q -b "ai/SBX-9-$s" && printf '%s\n' "$s" >> README.md
  git commit -qam "feat: slice $s"
done
git log --oneline --all | head -5
```

Expected: four commits, three branches chained a→b→c.

- [ ] **Step 2: Register the three PRs in the local tracker, stacked**

Write `.aisdlc/tracker/prs.jsonl` with three records whose `baseRefName` forms the chain (`main`, `ai/SBX-9-a`, `ai/SBX-9-b`), each `state: "open"`, each labelled `merge-ready`, matching the record shape in `templates/trackers/local.md:69`. Copy `plugins/sdlc/templates/trackers/local.md` to `.claude/trackers/local.md` and write a minimal `.claude/sdlc.md` naming it.

```bash
jq -r '.number, .baseRefName' .aisdlc/tracker/prs.jsonl | paste - -
```

Expected: `1 main`, `2 ai/SBX-9-a`, `3 ai/SBX-9-b`.

- [ ] **Step 3: Run the inspect path**

```bash
claude -p --model haiku --plugin-dir <path-to-this-checkout>/plugins/sdlc \
  --permission-mode bypassPermissions "/sdlc:stack SBX-9"
```

Expected: the chain printed bottom-first as `#1 → #2 → #3`, the per-PR gate table, and **no mutation** — `git log --oneline main | wc -l` still reports 2. A run that merges without `--merge` is a defect in Phase 1's wording, not in the model.

- [ ] **Step 4: Run the merge path**

```bash
claude -p --model haiku --plugin-dir <path-to-this-checkout>/plugins/sdlc \
  --permission-mode bypassPermissions "/sdlc:stack SBX-9 --merge"
```

Expected: three squash commits on `main`, every record `state: "merged"`, and — the assertion that matters — the diff of each merge containing only its own slice:

```bash
git log --oneline main
git show --stat HEAD~1 | grep -c 'README.md'
jq -r 'select(.state != "merged") | .number' .aisdlc/tracker/prs.jsonl | wc -l
```

Expected: 3 new commits, and `0` unmerged records. If a later commit contains an earlier slice's changes, the restack step in Phase 3 is wrong — fix `commands/stack.md`, never the assertion.

- [ ] **Step 5: Run the release gate with no deployer configured**

```bash
claude -p --model haiku --plugin-dir <path-to-this-checkout>/plugins/sdlc \
  --permission-mode bypassPermissions "/sdlc:release-check"
```

Expected: a `specs/releases/<today>.md` brief listing the three PRs, an explicit line stating no deployer descriptor is configured and which checks were therefore skipped, a populated `Not verified` section, and a final `Verdict: HOLD` or `Verdict: READY` on its own line. A brief with an empty `Not verified` section is a defect in `release-readiness` section 7's wording.

- [ ] **Step 6: Full gate sweep on the real repo**

```bash
cd <path-to-this-checkout>
CI= make validate 2>&1 | tail -3
make eval-dry
make selftest 2>&1 | tail -3
diff <(jq -r '.plugins[]|select(.name=="sdlc")|.skills[]' .claude-plugin/marketplace.json) \
     <(jq -r '.plugins[]|select(.name=="sdlc")|.skills[]' .omp-plugin/marketplace.json) && echo "ok manifests agree"
grep -c '12 skills\|33 commands' README.md
```

Expected: `All checks passed.`; 12 skills listed by `eval-dry`, the two new ones showing `trigger:5  no-trigger:3`; selftest `0 failed`; `ok manifests agree`.

- [ ] **Step 7: Record the evidence and clean up**

Paste the Step 4 and Step 5 outputs into the PR body — they are the only proof the instruction files work. Then `rm -rf "$T"`.

---

## Coverage check

| Decision from the session | Task |
|---|---|
| Auto-deploy on merge, configurable target | T4 (descriptor), T5 (merge is a deploy, interactive-only) |
| Staging before production | T3 (two gates), T4 (`Environments`, `Merge deploys to`), T6 |
| Too many, too-large PRs to own responsibly | T2 (size budget, slicing), T3 §7 (one page, not N diffs), T5 Phase 2 (gate the set at once) |
| PR stacking to release many small changes at once | T1 (**retarget-pr**), T2 (the rules), T5 (the mechanism), T6 (released as one set) |

## Risks

- **Restack correctness is the whole feature.** T7 Step 4 is the only assertion that catches a wrong rebase, because a retarget-without-rebase produces a *plausible* merge that quietly re-applies the parent's diff. Never weaken that step.
- **`/sdlc:stack` force-pushes.** `hooks/guard` blocks `--force` in agent sessions (`hooks/guard:2`). Confirm during T5 whether the guard's pre-bash rule blocks the restack push; if it does, the command must state that the push is the human's step, or the guard needs a narrowly-scoped exception for a branch that is a stack member. Decide this in T5, do not discover it in T7.
- **`gh api -X PATCH … -f 'base=…'`** is the documented way to retarget, but GitHub refuses a retarget that would create a cycle or cross repositories. T1 cannot prove the call; T7 exercises the local tracker only. First real use against GitHub is the true test.
