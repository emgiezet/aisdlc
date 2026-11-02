---
description: Offer Slop Guard to this repository and set it up — install the slop-guard plugin from the same marketplace as sdlc on this host, let it detect the project's stacks, install the pinned linters and scanners those stacks need, choose the enforcement mode and which baseline linter configs to adopt, then prove it with slopguard doctor. Runs from /sdlc:init after the hand-over; use directly to add the guard later or re-check it with --check.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# /sdlc:slopguard-setup

The sdlc `guard` hook covers git and the test suite: force pushes, `--no-verify`, deleted or
skipped tests. **Slop Guard** covers the code itself: a secret scan and protected linter configs
before every write, the stack's linters on the changed lines after it, and a Stop gate that holds
the turn while blockers remain. It is a separate plugin, `slop-guard`, in the same marketplace as
`sdlc`. This command installs it and configures it for *this* repository's stacks.

`$ARGUMENTS`: empty, or `--check` — run Phase 3's `doctor` only, change nothing, report.

Every step that installs or writes is proposed first and runs only on the human's yes: tool
installs download binaries (sha256-pinned) and adopted configs become files the project owns. In a
run with no human to answer (`AISDLC_HEADLESS=1`), propose and stop — never install unattended.

---

## Phase 0: Find the host and the plugin

Identify the host running this session and list the aisdlc plugins it has installed. Each line
is `<id> [enabled] <root>`; the marketplace is the suffix of the `sdlc@…` id (usually `aisdlc`):

```bash
# Claude Code
claude plugin list --json | jq -r '.[] | select(.id | test("^(sdlc|slop-guard)@")) | "\(.id) \(.enabled) \(.installPath)"'
# omp
omp plugin list --json | jq -r '.marketplace[] | select(.id | test("^(sdlc|slop-guard)@")) | "\(.id) \(.entries[0].installPath)"'
```

Codex and Grok: the slop-guard root is `${CLAUDE_PLUGIN_ROOT}/../slop-guard` when it holds
`bin/slopguard` (a local marketplace checkout); the marketplace is the name it was registered as.

`SG_ROOT` is the slop-guard root found above. `SG_DATA` is where the host keeps that plugin's data
— the tools must land there or the hooks will not find them:

- **Claude Code** — `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/data/slop-guard-<marketplace>`
- **Grok** — `$GROK_PLUGIN_DATA` when this shell has it, else the default below
- **omp, Codex** — `${XDG_DATA_HOME:-$HOME/.local/share}/claude/plugins/slop-guard`, the default
  `bin/slopguard` and the omp adapter both use

Shell state does not survive between tool calls, so every **slopguard** call below is written out
in full, run from the repository root:

```bash
CLAUDE_PLUGIN_ROOT="<SG_ROOT>" CLAUDE_PLUGIN_DATA="<SG_DATA>" CLAUDE_PROJECT_DIR="$PWD" "<SG_ROOT>/bin/slopguard" <args>
```

Installed and enabled → Phase 3. Installed but disabled → Phase 1 proposes enabling it
(`claude plugin enable slop-guard@<marketplace>`; omp: `omp plugin enable slop-guard@<marketplace>`).
`--check` with no plugin → report `not installed` and stop.

---

## Phase 1: Propose [GATE]

Present, before installing anything:

1. **What it adds** — the three layers in the first paragraph, one line each, and the stacks
   `/sdlc:init` found (from the `— PREVIOUS STEP (/sdlc:init) said —` block, or `git ls-files`).
2. **Scope** — `project` (recommended: Claude Code writes `enabledPlugins` into
   `.claude/settings.json`, so everyone who opens the repo gets the guard) or `user`.
3. **Enforcement mode** — what the Stop gate does with findings in changed code:

   | Mode | Blockers | Errors |
   |---|---|---|
   | `advisory` | reported, never blocks | reported |
   | `balanced` (default) | block turn end | reported |
   | `strict` | block turn end | block turn end |

   Recommend `balanced`; `strict` only for a repo whose linters are already clean.

```
⏸ SLOP GUARD
Reply 'yes' to install slop-guard@<marketplace> (scope <scope>, mode <mode>), name what to change, or 'no' to skip.
```

`no` → print `Slop Guard skipped — run /sdlc:slopguard-setup any time.` and stop.

---

## Phase 2: Install

| Host | Command |
|---|---|
| Claude Code | `claude plugin install slop-guard@<marketplace> --scope <scope> --config enforcement_mode=<mode>` |
| omp | `omp plugin install slop-guard@<marketplace> --scope=<scope>` |
| Codex | print: open the Plugins Directory, select `<marketplace>`, install `slop-guard`; wait for "done" |
| Grok | print: open `/plugins`, install `slop-guard` from `<marketplace>`; wait for "done" |

omp has no option store for marketplace plugins: a mode other than `balanced` is
`export CLAUDE_PLUGIN_OPTION_ENFORCEMENT_MODE=<mode>` in the shell that starts omp. Say that line;
never edit the human's shell profile. Already installed on Claude Code with another mode →
`printf '{"enforcement_mode":"<mode>"}' | claude plugin configure slop-guard@<marketplace> --values-stdin`.

Read back with the Phase 0 listing; resolve `SG_ROOT` and `SG_DATA` again from it. A plugin that
does not show up is a failed install — report the command's output, do not continue.

---

## Phase 3: Tools [GATE]

Run **slopguard** `doctor`. Its `scope:` line names the stacks it detected; each tool line says
`[ok]`, `[NOT FOUND]` or `version mismatch`, plus `mode: project | overlay`. Show the output.

**Wrong stacks.** A language the survey found is missing from `scope:` (autodetection keys on
anchor files, most of them at the root, so `infra/*.tf` or a monorepo's services are easily
missed), or a stack is listed that the repo does not use → propose `.slopguard.json` at the
repository root. It replaces autodetection, so it names every stack: whole-repo ones in `stacks`,
directory-scoped ones in `paths` — `{"stacks": ["python"], "paths": {"infra": ["terraform"]}}`.
Write it only on a yes, then re-run `doctor` and check the `scope:` line. After that the file is
protected: the guard asks before any later edit.

**Missing tools.** List them with what each needs to install, and check those first:
`command -v uv` for `ruff` and `checkov` (Python lock), `command -v npm` for `eslint-stack` (Node
lock), `command -v php` to *run* `phpstan` and `psalm`. A missing prerequisite is reported with its
install hint, and the tools that do not need it still install. Then ask:

```
Install <n> tools for stacks <stacks> into <SG_DATA>? (pinned versions, sha256-verified downloads)
```

On yes, **slopguard** `doctor --install`, then `doctor` again. Done when it prints
`All tools present and version-matched.`; otherwise name each tool still missing and why.

**Python with a virtualenv.** `mypy` and `pylint` are never installed by the plugin — they must
run from the project's interpreter. When `.venv/`, `venv/` or `.tox/py/` exists and the project
already depends on either tool, offer **slopguard** `adopt-config mypy` / `adopt-config pylint`
(writes `.slopguard/tools/<tool>.yaml`).

---

## Phase 4: Linter configs [GATE]

Every tool in `doctor`'s scope with `mode: overlay` has no project config: it runs with the
plugin's baseline and reports **security findings only**. Adopting the baseline copies it into the
repo and switches that tool to full reporting (style, maintainability, performance, security); the
file is then the project's and the agent must ask before editing it. `mode: project` tools already
use the repo's own config — leave them alone.

Present the overlay tools in one table — tool, the file `adopt-config` would write
(**slopguard** `adopt-config` with no argument lists them), and a recommendation: **adopt** when
the repo's CI already runs that linter or the team wants its style enforced; **keep overlay**
otherwise. Ask once:

```
Adopt baseline configs for: <tools>? Reply with the list to adopt, 'all', or 'none'.
```

Run **slopguard** `adopt-config <tool>` per chosen tool; it refuses to overwrite an existing file,
and that refusal is reported, not worked around. Re-run `doctor`: adopted tools now show
`mode: project`.

---

## Phase 5: Verify and report

Run **slopguard** `doctor` one last time and `git status --short` for the files this run created
(`.claude/settings.json`, `.slopguard.json`, `.slopguard/`, adopted configs).

```
## Slop Guard — <installed | already installed | checked | skipped>
Plugin: slop-guard@<marketplace> <version> · <host>, scope <scope> · mode <mode>
Scope: <the doctor scope line>
Tools: <n> ok · <n> missing (<tool>: <reason>)
Configs: adopted <tools> · overlay <tools> · project <tools>
Files: <new or changed files>

## Next
1. Start a new session — plugin hooks load at session start.
2. git add <files> && git commit -m "chore: set up Slop Guard"
```

Omit step 2 when no file changed. A tool that could not be installed is never reported as covered:
the guard skips it with a note in every session until it is.

---

## Not to be confused with

- **The sdlc `guard` hook** — ships with `sdlc` and is always on: force pushes, `--no-verify`,
  dangerous `rm`, test deletion, planning mode. Slop Guard is the optional second layer.
- **`/sdlc:update`** — re-syncs sdlc's own files after an upgrade. Slop Guard's tools follow its
  lockfile: after upgrading the plugin, re-run this command with `--check`, and `doctor --install`
  when a pin moved.
