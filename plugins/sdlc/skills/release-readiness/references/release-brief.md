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
