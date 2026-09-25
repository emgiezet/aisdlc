---
description: Bring this repository's generated SDLC setup up to date with the installed plugin — add descriptor operations, profile fields and runner config keys introduced since the last update, report drift in the hand-written router, playbooks and rules, and stamp the harness version. Use after updating the plugin, or when a command fails because a descriptor operation is missing.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# /sdlc:update

Updating the plugin updates the commands, the skills and the templates. It does **not** touch what
`/sdlc:init` wrote into this repository — your router, playbooks, rules, profile and descriptors
are yours, and no host plugin manager may rewrite them. That leaves one real failure mode: a
descriptor written months ago has no `### attach-image-evidence`, a command that names it strands,
and nothing said so until the run failed. This command closes that gap and nothing else.

## Arguments

`$ARGUMENTS` may contain `--check` and `--yes`.

- **`--check`** → report every difference and **write nothing**. Ends at Phase 7's report.
- **`--yes`** → apply without asking per file. Still never overwrites an answer you gave.
- Neither → show each proposed change and ask before writing it.

**This command needs an interactive session.** Writes under `.claude/` require an approval no
unattended run gets — deliberately. `--yes` skips *this command's* questions, not that approval.

The two sides never merge into one rule: **generated-verbatim files are re-synced** (descriptors,
config keys, profile fields — the machine-readable contract), **hand-written files are only
reported** (`CLAUDE.md`, playbooks, rules — the prose calibrated to this repo).

---

## Phase 1: Locate both sides

```bash
test -f .claude/sdlc.md || echo "not initialised"
jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"   # installed
jq -r '.harness_version // "unrecorded"' .aisdlc/config.json          # recorded by init/update
```

- **No `.claude/sdlc.md`** → this repo was never set up. Stop, print `INCOMPLETE — run /sdlc:init
  first`, change nothing. `/sdlc:update` never performs a first-time setup: the router is a
  judgement call and belongs to `/sdlc:init`'s review gate.
- **`${CLAUDE_PLUGIN_ROOT}` unset** (some hosts do not export it) → find the installed plugin
  directory, confirm `templates/` and `.claude-plugin/plugin.json` are under it, and say which path
  you used. If you cannot find it, stop with `INCOMPLETE`; guessing at templates is worse than
  stopping.
- **`unrecorded`** → the setup predates version stamping. That is normal and not an error: check
  everything below, then stamp.

Read `.claude/sdlc.md` for **Tracker descriptor**, **Browser descriptor**, **Kind**, **Specs live
in**, **Pull request label**, **Pipeline labels** and **Claim label**. Print one line:
`recorded <version> → installed <version>`.

**Then ask upstream whether the installed plugin is itself behind** — one bounded call, never a
blocker:

```bash
slug=$(jq -r '.repository' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" | sed 's|.*github.com[:/]||; s|\.git$||')
curl -fsSL --max-time 5 "https://raw.githubusercontent.com/${slug}/main/.claude-plugin/marketplace.json" \
  | jq -r 'first(.plugins[]? | select(.name == "sdlc") | .version) // empty'
```

Compare with `sort -V`. Published version higher → say so and name the one command this host
updates with (`/plugin update sdlc@aisdlc`, `omp plugin upgrade sdlc@aisdlc`,
`codex plugin marketplace upgrade`, `npx skills update`), then **continue anyway**: syncing this
repo to the plugin actually installed is still correct and still worth doing. Offline, no `curl`,
a non-GitHub fork or a non-JSON answer → print `upstream: unreachable` and move on. A version
check never fails this command. `aisdlc version --check` runs the same comparison from a shell.

---

## Phase 2: Descriptors — the executable contract

For the tracker descriptor and, when not `none`, the browser descriptor:

```bash
tpl="${CLAUDE_PLUGIN_ROOT}/templates/trackers/<kind>.md"; repo=".claude/trackers/<kind>.md"
comm -13 <(grep '^### ' "$repo" | sort) <(grep '^### ' "$tpl" | sort)   # missing here → to add
comm -23 <(grep '^### ' "$repo" | sort) <(grep '^### ' "$tpl" | sort)   # local extras → keep
```

- **Missing operations** are the bug. Copy each one **byte-for-byte** from the template — heading,
  body, `Returns:` line — and insert it in the template's order. A command that names an operation
  the file does not define fails at the worst moment, in an unattended phase.
- **Operations present in both:** leave alone, always. The body may have been adapted to this
  organisation's CLI, its API host or its label names, and that adaptation is the point of a
  descriptor.
- **Extras only in the repo copy:** report, never delete. A provider may have operations this
  harness does not ship.
- **A descriptor file the profile names but that does not exist** → copy the whole template in, then
  say so loudly: every command that touched the tracker was failing until now.

One file at a time. Show the operation names you will add, write, then re-read the file and confirm
each heading landed. Finally run the descriptor's **auth-check** and put its real result in the
report — a resynced descriptor that cannot authenticate is not a fixed descriptor.

---

## Phase 3: Profile fields

Compare `.claude/sdlc.md` against `${CLAUDE_PLUGIN_ROOT}/templates/sdlc.md`:

```bash
comm -13 <(grep -oE '^- \*\*[^*]+\*\*' .claude/sdlc.md | sort -u) \
         <(grep -oE '^- \*\*[^*]+\*\*' "${CLAUDE_PLUGIN_ROOT}/templates/sdlc.md" | sort -u)
grep -c '^## ' .claude/sdlc.md "${CLAUDE_PLUGIN_ROOT}/templates/sdlc.md"   # sections, same way
```

- **Fields the template has and this profile does not** → append them to the matching section with
  the template's default value *and* its `<!-- … -->` comment. A new field a command reads is a
  `none` the command must be able to find; an absent key makes it guess.
- **Fields this profile has and the template dropped** → report only. Removing a line someone
  answered on purpose is not an update.
- **Never touch an answered field.** Not the stacks table, not the verification commands, not
  `none` where `none` was chosen.

If `/sdlc:init --discovery` wrote a `## Definition of Ready` block, leave it exactly as it is.

---

## Phase 4: Runner config and directories

`.aisdlc/config.json` — the keys the queue runner resolves: `model`, `budget`, `base`, `workers`,
`label`, `specs_dir`; optional `billing` and `model_roles`.

- Add **absent** keys with the defaults `aisdlc help` prints, except `base`, which comes from this
  repo: `git symbolic-ref --short refs/remotes/origin/HEAD` (fall back to the checked-out branch).
- **Never rewrite a value that is there.** A budget someone lowered on purpose stays lowered.
- No `.aisdlc/config.json` at all → write one with those keys. The runner works without it; the
  file exists so the defaults are visible and reviewable.

Then the directories and the exclude, all idempotent: the profile's specs directory,
`<specs>/briefs/`, and `/.aisdlc/` present in `.gitignore` or `.git/info/exclude`.

---

## Phase 5: The hand-written tier — report, do not rewrite

Four checks, each one a line in the report and nothing more:

1. **Router rows against playbook files.** Every destination in the `CLAUDE.md` Task Router must
   exist under `.claude/playbooks/`. A dangling row sends every matching task to a file that is not
   there — the single most expensive drift there is.
2. **Playbook templates this version ships** (`ls ${CLAUDE_PLUGIN_ROOT}/templates/playbooks/`) that
   this repo has no counterpart for. Only worth adopting if the repo does that kind of work now;
   say which, and that `/sdlc:init` is what writes one.
3. **Line budgets** — `CLAUDE.md` ≤ 90, each playbook and rule ≤ 70. Over budget means the router
   is being read past the point where a weak model follows it.
4. **Rules that match nothing** — for each `.claude/rules/*.md`, does its `paths:` frontmatter still
   match a file in this repo? A rule scoped to a directory that was renamed is silently off.

A fix here changes instructions a person wrote for this repo. Name it, do not do it.

---

## Phase 6: Labels

Tracker **Kind** `github` only: **ensure-labels** with the profile's PR label, the four pipeline
labels and the claim label. Six labels, created if absent, never renamed. Other kinds: skip, and say
which kind was detected.

---

## Phase 7: Stamp and report

Stamp only outside `--check`, and only when every step above either applied cleanly or was a
report-only finding:

```bash
jq '.harness_version = "<installed>"' .aisdlc/config.json > /tmp/c.json && mv /tmp/c.json .aisdlc/config.json
```

Then, having re-read what you wrote:

```
## Updated for AI SDLC <recorded> → <installed>
<file>: <what changed — operation names, field names, config keys — or "current">

## Reported, not changed
<router, playbook, rule and budget findings, each with the one action that would fix it>

## Verification
<auth-check result> · <labels ensured or skipped> · <config keys added>

## Next
<the single most useful thing to do now, or "nothing — this repo is current">
```

Report `COMPLETE` when every planned write landed and `auth-check` passed; `INCOMPLETE` otherwise,
naming each file that did not land and why (a refused write, a missing plugin root, a failed
auth-check). `--check` reports `COMPLETE (check only, nothing written)`.

---

## Not to be confused with

- **`/plugin update sdlc@aisdlc`** (and `omp plugin upgrade`, `codex plugin marketplace upgrade`,
  `npx skills update`) — those update the harness. This command updates *your repository* to match
  it. Run them in that order.
- **`/sdlc:init`** — creates the setup, proposes a router, needs a review gate. Run once. Also the
  right command when the repo's shape changed enough that the router is wrong.
- **Editing `CLAUDE.md` by hand** — expected and encouraged. Phase 5 exists to tell you when it is
  due, not to do it for you.
