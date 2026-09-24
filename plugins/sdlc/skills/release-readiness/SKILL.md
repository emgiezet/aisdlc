---
name: release-readiness
description: >
  The gate between staging and production — what makes a set of merged changes promotable,
  migration and config ordering, feature-flag defaults, the rollback path, and the one-page
  brief a human can actually take responsibility for. Use when deciding what goes to
  production, whether a release set is safe to promote, what to prepare before a deploy, or
  when a release is too large to sign off with confidence.
---

# Release Readiness

Staging is not production. The defect this skill exists to prevent is the conflated gate:
teams that apply the production bar at every merge slow every PR down; teams that apply the
staging bar at promote time ship surprises. The bar belongs at the promotion gate — that is
when a human holds the whole set and takes responsibility for it.

## Two gates, not one

| Gate | Question | Blast radius | Who decides |
|---|---|---|---|
| Merge | Is this safe *on staging*? Cheap, revertible, auto-deployed | One change, staging only | The author |
| Promote | Is this set safe *for users*? The whole set, not the last PR | All users, production | A named signer |

## The release set

The release set is everything merged since the last promotion — **not** the stack you just
merged. Enumerate it before any other gate runs:

- **deploy-status**: the current deployment state of each environment
- **current-release**: what the deploy target reports as live in production
- **env-diff**: what staging has that **current-release** does not

**env-diff** is the release set. A release set nobody enumerated is the most common cause
of "we didn't know that was in there."

## Promotion gate

Run each row in order. A failing row is a `HOLD`; all rows passing is `READY`. Name the failing row in the verdict.

| Check | HOLD reason |
|---|---|
| Every set member verified on staging, not merely deployed there | Deployed ≠ verified; a pod restart is not a test |
| Migrations applied on staging and reversible or expand-only | A migrate-and-promote is a rollback that cannot roll back |
| Every new config key and secret already present in production | A missing key is not a quick fix at promote time |
| New behaviour behind a flag that defaults to off | A flag-less change cannot be disabled without another deploy |
| No API or contract change that breaks a client still in flight | See `rest-api-design` and `graphql-api-design` for the breaking-change tables |
| A rollback path exists: an owner and a **rollback** command | "We'd roll back" without a tested command is not a rollback path |
| The brief exists and names a signer | A brief nobody signed is a brief nobody read |

## Migration ordering

Expand-then-contract, in this exact sequence. Each step ships as a separate release.

1. Add the nullable column; write to both old and new paths — this step ships first.
2. Backfill: populate the new column from existing data — ships as its own release.
3. Read from the new path only; continue writing to both paths — ships after the backfill is complete and verified.
4. Stop writing the old column; the new path is the only writer — ships after step 3 is verified stable.
5. Drop the old column — a later release, never the same one as step 4.

**A release is rollback-safe only if every migration in it is forward-compatible with the
previous release's code.** A destructive migration in the same set as the code that stopped
using the column is a rollback that cannot roll back. Use **pending-migrations** to list what
has not yet run on the target before **promote** runs.

## Config and secrets

Config lands in production *before* the code that reads it — always. That ordering is the
opposite of the code's dependency direction, which is why it is forgotten.

A missing key discovered at promote time is a `HOLD`, not a quick fix: nothing verified on
staging proves anything about production when the key is absent. Confirm every new key and
secret that **env-diff** surfaces already exists in the target before **promote** runs.

## Rollback

| Situation | Action |
|---|---|
| Bad code, no migration | **rollback**: redeploy the previous release |
| Bad code, expand-only migration | **rollback**: redeploy previous; the new column is harmless |
| Bad code, destructive migration | Forward-fix only — this is why the gate forbids it |
| One bad PR in a good set | Revert that PR and re-promote; never hand-edit production |

"We'd roll back" without a tested command and a named owner is not a rollback path.

## The brief is the deliverable

**A human signs one page, not N diffs.** The brief states, for the whole set: what a user
will notice, the blast radius, the migrations, the config, the flags, the rollback command,
and what was verified on staging and how.

If the set cannot be compressed to one page, the set is too large — promote a prefix of it
instead. Template: [`references/release-brief.md`](references/release-brief.md).

## Non-negotiable

1. Never promote a set nobody enumerated.
2. Never ship a destructive migration in the same release as the code that stopped using the column.
3. Never promote with a config key missing in the target environment.
4. Never promote on a staging verification nobody performed.
5. Never sign a brief you did not read because the set was too big to read.

## Review checklist

- [ ] Release set enumerated with **deploy-status**, **current-release**, and **env-diff** before any other gate
- [ ] Every set member verified on staging, not just deployed
- [ ] All migrations on staging are expand-only or explicitly reversible
- [ ] Every new config key and secret confirmed present in the target
- [ ] New behaviour behind a flag defaulting to off
- [ ] No breaking API or contract change for a client still in flight
- [ ] Rollback path named, owner named, **rollback** command tested
- [ ] Brief written, filled, and signed before **promote** runs
