---
description: Gate between staging and production — enumerates the release set, attributes each commit to a PR and ticket, walks the release-readiness promotion table row by row, writes specs/releases/<YYYY-MM-DD>.md, and returns READY or HOLD. Never promotes; the human runs promote. Use before every production deployment.
allowed-tools: Bash(git:*), Read, Write, Grep, Glob, SlashCommand
---

# /sdlc:release-check

`$ARGUMENTS` is `[--to <env>] [--since <ref>]`.

This command is **never automated**. It decides and writes the brief; **promoting is a human
decision**. After a `READY` verdict this command prints the exact **promote** invocation for
the human to run — it does not run it. There is no `--promote` flag; a promotion nobody
supervised is a production incident waiting to happen.

Read `.claude/sdlc.md` for the **Deployer descriptor**, **Environments**, **Default base ref**,
and **Promotion**. `none` is a valid value for every key.

**Load the `release-readiness` skill** — it owns the gate table, the migration and config
ordering rules, the rollback rules, and the one-page brief format this command applies.
Execute those rules; do not restate them here.

`--to <env>`: the target environment (default: the last entry in **Environments**).
`--since <ref>`: base git ref for the no-deployer fallback only (default: most recent tag).

---

## Phase 1: Resolve the set [HARD STOP]

**`Environments: none`** — there is no promotion target. Enumerate the git history set:

```bash
git log <base-ref>..<default-base-ref> --oneline
```

where `<base-ref>` is `--since <ref>` if given, else
`git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD`; and
`<default-base-ref>` is **Default base ref**, or `origin/main` when that key is absent or `none`. Print the set, then:

```
Environments: none — no promotion target configured; every environment check skipped.
```

Stop here. Do not continue to Phase 2 or beyond.

If `--since <ref>` is passed and the **Deployer descriptor** names a deployer: the release
set is defined by the deployer's view of what is live, not a git ref, so `--since` does not
apply. Print that line and stop.

---

Resolve `<target>` from `--to` or from the last entry in **Environments**. Resolve `<source>`
as the entry directly before `<target>` in **Environments**.

**`Deployer descriptor: none`** — fall back to git history. Resolve `<base-ref>` as
`--since <ref>` if given, else the output of
`git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD`;
`<default-base-ref>` is **Default base ref**, or `origin/main` when that key is absent or `none`. Run:

```bash
git log <base-ref>..<default-base-ref> --oneline
```

Record the output as `<set>`. Print:

```
Deployer unavailable — deploy-status, current-release, pending-migrations cannot be performed.
```

**With a deployer descriptor:**

1. **current-release** `<target>` → `<target-ref>` (always from the deployer; `--since` does
   not override this value — `<target-ref>` must reflect what is actually live in the target).
2. **current-release** `<source>` → `<source-ref>`.
3. **env-diff** `<source>` `<target>` → `<set>`: one line per commit (sha, subject, PR number).

If `<set>` is empty: print `nothing to promote — <target> is level with <source>` and stop.

Record: `<set>`, `<target-ref>` (live ref in target before this promotion), `<source-ref>`.

---

## Phase 2: Attribute the set

For each commit in `<set>`:

1. **get-pr** or **search-prs** by sha → PR number, linked ticket.
2. A commit with no associated PR is a finding — record:
   `untracked commit <sha> <subject> reached <source> outside the pipeline`.

Record: sha → `{pr, ticket}` for every attributed commit.

---

## Phase 3: Apply the gate [GATE]

Load the `release-readiness` skill's promotion table. Walk **every row** — do not stop at the
first failure. Collect each failing row as a `HOLD: <reason>` line.

Deployer operations called for two rows:

- **Staging verification row** → **deploy-status** `<source>`, cross-checked against the Phase 2
  PR list. With no deployer: `HOLD: staging verification — deployer unavailable, verify manually`.
- **Migrations row** → **pending-migrations** `<target>` — empty output means none.
  With no deployer: `HOLD: pending migrations — deployer unavailable, verify manually`.

For the remaining rows (config and secrets, feature flags, API contract): inspect `<set>`; flag
each for manual confirmation in the brief.

Defer two rows to after Phase 4 (both require brief fields that do not exist yet):
**rollback owner** and **brief signed**. Record them as pending; Phase 4 evaluates both.

---

## Phase 4: Write the brief [REQUIRED]

If `specs/releases/<YYYY-MM-DD>.md` already exists (re-run after the human filled in
`Signer:` or `Owner:`): update it in place, refreshing every section from the current gate
data. A `Signer:` or `Owner:` value the human has filled in is never overwritten. If the
file is absent, fill `../skills/release-readiness/references/release-brief.md` into it.
Every section of the template must appear. Where a value is unknown: write
`Not verified — <reason>`; never leave a section empty. If the set does not compress to one
page: write `Set too large — recommend promoting through <sha> first` and name the sha.

The **Rollback** section states: `rollback <target> <target-ref>` where `<target-ref>` is the
ref Phase 1 recorded as live in the target before this promotion — not the ref being promoted.
When the deployer is unavailable, write `Not verified — no deployer; rollback ref unknown`.

Evaluate the two deferred gate rows now that the brief exists:

- **Rollback owner**: the brief's `Rollback` line must name an owner. If absent:
  add `HOLD: no rollback owner named — fill Owner in the brief and re-run`.
- **Brief signed**: the brief's header must name a signer. If absent:
  add `HOLD: brief not yet signed — fill Signer in the brief and re-run`.

Append any new `HOLD:` lines to the Phase 3 list.

Commit the brief if it changed (an identical second pass is not an error):

```bash
git add specs/releases/<YYYY-MM-DD>.md
git diff --cached --quiet || git commit -m "docs(release): brief <YYYY-MM-DD> — <n> changes"
```

---

## Phase 5: Report

```
## Release check — <YYYY-MM-DD>
Set: <n> commits · <source> → <target>
Brief: specs/releases/<YYYY-MM-DD>.md

HOLD: <reason>   ← one line per failing row from Phases 3 and 4; omit block when none
...
```

`READY` only when every gate row passes. When `READY` and **Promotion** is not `none`, print
the invocation for the human — **do not run it**:

```
To promote, run:
  promote <target> <source-ref>
```

With `Promotion: none`: print the verdict and omit the invocation block.

Print the verdict exactly once, last:

```
Verdict: READY
```

or

```
Verdict: HOLD
```

---

## Not to be confused with

- **`/sdlc:merge`** — merges a single PR into the default branch; this command gates the whole
  set accumulated since the last production promotion.
- **`/sdlc:stack`** — merges a chain of PRs bottom-up; run that first, then run this to gate
  everything that has landed into production.
- **`/sdlc:changelog`** — records what is in a release. Run `/sdlc:release-check` first; the
  brief this command writes is the input `/sdlc:changelog` summarises.
