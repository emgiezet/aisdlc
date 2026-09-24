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

Read `.claude/sdlc.md` for the **Deployer descriptor**, **Environments**, **Merge deploys to**,
and **Promotion**. `none` is a valid value for every key.

**Load the `release-readiness` skill** — it owns the gate table, the migration and config
ordering rules, the rollback rules, and the one-page brief format this command applies.
Execute those rules; do not restate them here.

`--to <env>`: the target environment (default: the last entry in **Environments**).
`--since <ref>`: override the base ref (default: **current-release** of the target).

---

## Phase 1: Resolve the set [HARD STOP]

Resolve `<target>` from `--to` or from the last entry in **Environments**. Resolve `<source>`
as the environment directly before `<target>` in **Environments**.

**Deployer descriptor is `none` or absent:** fall back to git history. Run:

```bash
git log <base-ref>..<merge-target> --oneline
```

where `<base-ref>` is `--since <ref>` if given, else the output of
`git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD`;
`<merge-target>` is the **Merge deploys to** branch (default `origin/main`). Record the
git log output as `<set>`. Print one line:

```
Deployer unavailable — deploy-status, current-release, pending-migrations checks cannot be performed.
```

**With a deployer descriptor:**

1. **current-release** `<target>` → `<target-ref>`. If `--since <ref>` was given, use that as
   `<target-ref>` instead.
2. **current-release** `<source>` → `<source-ref>`.
3. **env-diff** `<source>` `<target>` → `<set>`: one line per commit (sha, subject, PR number).

If `<set>` is empty: print `nothing to promote — <target> is level with <source>` and stop.

Record: `<set>`, `<target-ref>` (live ref in target before this promotion), `<source-ref>`.

---

## Phase 2: Attribute the set

For each commit in `<set>`:

1. **get-pr** or **search-prs** by sha → PR number, linked ticket.
2. A commit with no associated PR is a finding — record: `untracked commit <sha> <subject>
   reached <source> outside the pipeline`.

Record: sha → `{pr, ticket}` for every attributed commit.

---

## Phase 3: Apply the gate [GATE]

Load the `release-readiness` skill's promotion table. Walk **every row** — do not stop at the
first failure. Collect each failing row as a `HOLD: <reason>` line. When a deployer operation
cannot run (no deployer), record `HOLD: <row-name> — deployer unavailable, verify manually`.

| Gate row | How to check |
|---|---|
| Staging verification — every set member verified, not merely deployed | **deploy-status** `<source>`; Phase 2 PR list |
| Pending migrations — none unapplied in the target | **pending-migrations** `<target>` — empty output means none |
| Config and secrets — every new key confirmed present in the target | inspect `<set>` for new keys; flag each for manual confirmation |
| Feature flags — new behaviour behind a flag defaulting off | inspect `<set>` for flag introductions |
| API contract — no breaking change for a client still in flight | review `<set>` against `rest-api-design` / `graphql-api-design` |
| Rollback path — named owner and **rollback** command stated | no deployer call; must be stated in the brief |
| Brief signed — exists and names a signer | answered in Phase 4 |

---

## Phase 4: Write the brief [REQUIRED]

Fill `plugins/sdlc/skills/release-readiness/references/release-brief.md` into
`specs/releases/<YYYY-MM-DD>.md` (create `specs/releases/` if absent). Every section of the
template must appear. Where a value cannot be determined, write `Not verified — <reason>`;
never leave a section empty. If the set does not compress to one page, write:
`Set too large — recommend promoting through <sha> first` and name the cut point.

The **Rollback** section states the exact command the human would run to revert:
`rollback <target> <target-ref>` (where `<target-ref>` is the ref Phase 1 recorded as live in
the target before this promotion — not the ref being promoted).

Commit the brief:

```bash
git add specs/releases/<YYYY-MM-DD>.md
git commit -m "docs(release): brief <YYYY-MM-DD> — <n> changes"
```

---

## Phase 5: Report

```
## Release check — <YYYY-MM-DD>
Set: <n> commits · <source> → <target>
Brief: specs/releases/<YYYY-MM-DD>.md

HOLD: <reason>   ← one line per failing gate row; omit block when none
...
```

`READY` only when every gate row passes. Print the verdict last, exactly once:

```
Verdict: READY
```

or

```
Verdict: HOLD
```

When `READY`, print the promote invocation for the human — **do not run it**:

```
To promote, run:
  promote <target> <source-ref>
```

---

## Not to be confused with

- **`/sdlc:merge`** — merges a single PR into the default branch; this command gates the whole
  set accumulated since the last production promotion.
- **`/sdlc:stack`** — merges a chain of PRs bottom-up; run that first, then run this to gate
  everything that has landed into production.
- **`/sdlc:changelog`** — records what is in a release. Run `/sdlc:release-check` first; the
  brief this command writes is the input `/sdlc:changelog` summarises.
