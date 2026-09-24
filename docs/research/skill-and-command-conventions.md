# Research: Adding a Hand-Written Skill + Slash Command to slop-guard

**Date:** 2026-09-24  
**Scope:** `plugins/slop-guard`, `plugins/sdlc`, repo root — read-only

---

## 1. Skill Anatomy

### Frontmatter fields

Two sources establish the contract: the `secure-review` hand-written skill and `gen-skills` generated output.

**Required by the test** (`tests/catalog_test.sh:257-270`):
```
"name: "*)        $in_fm && has_name=true
"description: "*) $in_fm && has_desc=true
"user-invocable: "*) $in_fm && has_uinv=true
```
Every `SKILL.md` in every `skills/*/` directory **must** have `name`, `description`, and `user-invocable` or the test at `catalog_test.sh:268-271` fails.

**All fields in use — verbatim from the two reference skills:**

`skills/python-antipatterns/SKILL.md` (generated):
```yaml
---
name: python-antipatterns
description: Forbidden Python patterns — SQL injection, shell injection, unsafe deserialization, missing timeouts, blocking async calls. Applies when editing Python files.
paths: ["**/*.py"]
user-invocable: false
---
```

`skills/secure-review/SKILL.md` (hand-written):
```yaml
---
name: secure-review
description: "Security review subagent: reads session findings and the AP-* catalogue, produces a structured security assessment. Cannot write or edit files — a reviewer that can edit is not a reviewer. Invoke with /secure-review."
agent: security-reviewer
context: fork
user-invocable: true
disallowedTools: [Write, Edit, MultiEdit]
---
```

**Field semantics:**
- `name` — must match the skill directory name.
- `description` — shown in the skill list; written as a plain or double-quoted string.
- `paths` — optional JSON array of glob patterns; when present, the runtime auto-loads the skill when an edited file matches. Absent → skill loads on all files (or only on invocation if `user-invocable: true`).
- `user-invocable` — `false` = auto-context only; `true` = also exposed as the slash command `/slop-guard:<name>`. **This is the only mechanism that creates a slash command in slop-guard** (no `commands/` directory exists).
- `agent` — optional; names the agent file in `agents/<name>.md` to spawn as a subagent on invocation.
- `context: fork` — optional; the subagent runs in an isolated context (fork of current session).
- `disallowedTools` — optional JSON array; restricts tools available to the invoked skill/agent.

### Body structure

From both skills, the standard body pattern is:
1. H1: `# <Human title> — do not write these` (generated) or `# <Human title> — /<command-name>` (hand-written, user-invocable).
2. One-sentence context paragraph.
3. `## Blockers` / `## Errors` / `## Warnings` sections (only sections that have entries).
4. Footer: `` Details for any ID: `reference/<ID>.md` `` (generated) or detailed prose (hand-written).

### Size limits

Enforced by **two independent checks**:

1. **`scripts/gen-skills` at generation time** (`gen-skills:12-13`):
   ```
   # §3 budgets enforced: SKILL.md ≤ 150 lines, ≤ 3000 tokens (1 token ≈ 4 chars).
   MAX_LINES=150
   MAX_TOKENS=3000
   TOKEN_DIV=4
   ```
   The generator exits 2 on breach (`gen-skills:180-190`).

2. **`tests/catalog_test.sh:225-246`** (offline CI, runs for ALL `skills/*/SKILL.md` including hand-written ones):
   ```bash
   if [ "$lc" -gt 150 ]; then
       bad "SKILL.md line budget" "${skill_name}: ${lc} lines > 150"
   fi
   if [ "$tc" -gt 3000 ]; then
       bad "SKILL.md token budget" "~${tc} tokens > 3000"
   fi
   ```
   The test applies to **every** `skills/*/SKILL.md`, not just generated ones. A hand-written skill that exceeds 150 lines or ~12 000 characters will fail CI.

---

## 2. Generated vs Hand-Written: Safe Placement

### What gen-skills owns

`scripts/gen-skills` processes **exactly these 12 skill directories**, derived from the catalog via `lang_to_skill()` (`gen-skills:58-80`) and pre-created reference dirs (`gen-skills:380-385`):

```
php-antipatterns  go-antipatterns  python-antipatterns  ts-react-antipatterns
node-antipatterns  sql-antipatterns  iac-antipatterns  jvm-antipatterns
csharp-antipatterns  ruby-antipatterns  rust-antipatterns  agent-discipline
```

The main generation loop (`gen-skills:396-399`):
```bash
for sk in "${!seen_skills[@]}"; do
    gen_skill_md "$sk" <<< "${skill_buckets[$sk]:-}"
done
```
`seen_skills` is built only from catalog language tags, so the set is bounded by the 12 `lang_to_skill()` cases.

### What gen-skills does NOT do

gen-skills **never** calls `rm`, `find -delete`, or any glob over the skills directory to remove entries. It only runs `mkdir -p` and atomic overwrites on the 12 named directories. `skills/secure-review/` exists today and is never touched. Any new directory whose name is not in `lang_to_skill()` is permanently safe.

**Safe names for a new hand-written skill:** any name not in the 12 above — e.g. `refactor-guide`, `code-quality`, `minimalism`, `ponytail-review` would all be safe.

---

## 3. Slash Commands

### slop-guard has no `commands/` directory

There is no `plugins/slop-guard/commands/` path. The `/slop-guard:secure-review` slash command is exposed **exclusively** via the skill frontmatter field `user-invocable: true` in `skills/secure-review/SKILL.md:6`. The Claude Code runtime infers the command name `/<plugin-name>:<skill-name>` from the skill directory name when `user-invocable: true`.

Hooks (`hooks/hooks.json`) wire only `SessionStart`, `PreToolUse`, `PostToolUse`, and `Stop` events — no command registration. Neither `plugin.json` (`plugin.json:1-37`) nor `.claude-plugin/plugin.json` (`.claude-plugin/plugin.json:1-54`) registers any commands.

**Conclusion: to add a new slash command in slop-guard, add a new skill directory with `user-invocable: true` in its frontmatter. No other file needs to change.**

### How the sdlc plugin does it

`plugins/sdlc` has a `commands/` directory with 31 `.md` files. This is a different convention — commands are file-based, not skill-based. The sdlc plugin's `.claude-plugin/plugin.json` does not list commands explicitly; the runtime discovers them from the directory by convention.

**Command file format** — verbatim frontmatter from two real examples:

`plugins/sdlc/commands/arch-review.md:1-4`:
```yaml
---
description: Verify a planned architecture against its numbers — elicit or read the Non-functional targets block (traffic profile, availability tier, RPO/RTO, hard and soft dependencies), check the topology and dependency chain against what the tier forces, and write specs/<EPIC>/arch-review.md with severity-ranked findings and a SOUND/GAPS verdict. Use on an arch.md or any architecture document before it is sliced into specs, or whenever an availability target is stated.
allowed-tools: Bash(git:*), Read, Write, Edit, Grep, Glob
---
```

`plugins/sdlc/commands/backlog.md:1-4`:
```yaml
---
description: Decompose a brief or spec into an evidence-gated epic → story → task tree and file each node through /sdlc:issue — dry-run prints, adoption matches existing issues by title. Use after a brief is evidence-ready to build the tracker backlog.
allowed-tools: Read, Write, Agent, SlashCommand
---
```

**How a path argument is received — definitive:**

Arguments arrive as the string `$ARGUMENTS` (the entire user-typed text after the command name). There is no `$1`, no `argument-hint` metadata field, no positional splitter. The command body describes how to interpret the string:

- `arch-review.md:12-14`: `$ARGUMENTS is an epic id or a path to any Markdown architecture document.`  
- `backlog.md:8`: `` `$ARGUMENTS`: `<brief|spec>` (path) `[--dry-run]` `[--research]` ``

The pattern is always: state in prose at the top of the command body what `$ARGUMENTS` contains, then use it as a variable throughout the instruction text. For a path argument, the command reads the path from `$ARGUMENTS`, checks the file exists, and stops if missing.

---

## 4. Agent Files: Frontmatter Contract

`agents/security-reviewer.md:1-5`:
```yaml
---
description: "Security reviewer subagent — read-only: reads session findings and the AP-* catalogue to produce a structured security assessment. Disallowed tools: Write, Edit, MultiEdit."
disallowedTools: [Write, Edit, MultiEdit]
---
```

**Fields in use:**
- `description` — shown to the spawning context; explains the agent's purpose and constraints.
- `disallowedTools` — JSON array of tool names the subagent cannot use. Enforced by the runtime.
- `model` — **not present**; the agent inherits the session model.

The agent is linked from the skill via `agent: security-reviewer` in the skill frontmatter (`skills/secure-review/SKILL.md:4`). The test at `catalog_test.sh:333-378` verifies the agent file exists and contains evidence that Write/Edit are forbidden.

For a refactor-focused subagent: the agent file should omit `disallowedTools` (or restrict to `Read, Bash, Grep, Glob` and allow `Write, Edit`) and the description should state it may modify files, distinguishing it from the read-only reviewer pattern.

---

## 5. Guideline Sources for "Beautiful Code"

| Source | Path | Rule class owned |
|--------|------|------------------|
| AP-* anti-pattern catalogue | `plugins/slop-guard/rules/catalog.yaml` | Language-specific security, performance, and maintainability bad/good patterns — the canonical list of what NOT to write, with one-liner `skill_line` ≤ 100 chars and full `bad`/`good` examples. Each entry has `severity` (blocker/error/warn) and `category`. |
| Agent-discipline skill | `plugins/slop-guard/skills/agent-discipline/SKILL.md` | Always-on behavioral rules for agents: AP-AGENT-001–009 (suppression policy, baseline changes, test integrity, dependency installs, credential handling, scope discipline, docs lookups, pinned versions). |
| Always-on policy | `plugins/slop-guard/rules/policies/always-on.yaml` | Machine-readable version of AP-AGENT-* with `enforcement`, `decision` (deny/ask/warn), and `severity` — consumed by hooks. |
| Pre-write policy | `plugins/slop-guard/rules/policies/write.yaml` | Secret scanning config, protected file patterns (tool configs, baselines), conditional triggers (pyproject.toml, tsconfig, CI step removal). |
| Pre-bash policy | `plugins/slop-guard/rules/policies/bash.yaml` | Shell command restrictions, package-install gates. |
| Pre-read policy | `plugins/slop-guard/rules/policies/read.yaml` | Credential and secret file deny-list. |
| Suppression policy | `plugins/slop-guard/rules/policies/suppressions.yaml` | Suppression-comment validation rules. |
| AI SDLC operating manual | `docs/ai-sdlc.md` | Pipeline-level rules: spec-first delivery, test floors, review capacity, scope discipline. Not code-style rules. |

**`catalog.yaml` structure** (`rules/catalog.yaml:1-83`):
```yaml
- id: AP-PHP-SEC-001
  title: SQL built by string interpolation or concatenation
  language: [php]
  frameworks: [laravel, symfony, plain]
  category: security          # security | performance | maintainability
  severity: blocker           # blocker | error | warn
  cwe: [CWE-89]
  summary: <prose>
  skill_line: <≤100-char one-liner for SKILL.md>
  bad: |                      # fenced code example
    ...
  good: |                     # fenced code example
    ...
  detect:                     # tool + rule pairs for static detection
    - { tool: psalm, rule: TaintedSql }
    - { tool: opengrep, rule: slopguard.php.laravel.raw-sql-interpolation }
  prevent_in_skill: true      # include skill_line in the language skill
  references:
    - https://...
```
`skill_line` is extracted by `gen-skills:parse_skill_records()` (`gen-skills:201-215`) and placed directly in `SKILL.md` bullet lists. `reference/*.md` files are generated by `generate_reference_files()` from `bad`, `good`, `summary`, `detect`, and `references` fields.

**Ponytail/minimalism skill:** Not present in this repo. The ponytail family of skills lives in the harness system skills layer, not in either plugin. There is no `CLAUDE.md` at the repo root and no `.claude/` directory.

---

## 6. Existing Refactor-Adjacent Prior Art

Searching `plugins/sdlc/commands/` for commands that rewrite or refactor code:

- `implement.md` — implements an approved spec; writes new code but does not refactor existing code for quality.
- `continue.md` — resumes blocked implementations; explicitly states `Never rewrite history` (`continue.md:47`).
- `fix-pr.md` — fixes a broken PR's CI and review blockers; scope is CI/review findings, not quality refactoring.
- `fix-issue.md` — orchestrates the full bug-fix chain; scope is bug correction.
- `qa.md` — verification against spec; read-oriented, closes test gaps.

No command in either plugin rewrites code for style, complexity reduction, or code-smell remediation. The `changelog.md` mentions the `refactor` conventional-commit type as a classification token only (`changelog.md:55`), not as an action.

**Conclusion:** There is no existing command or skill to extend. A new skill (e.g. `skills/refactor-guide/`) with `user-invocable: true` is the correct addition — it becomes `/slop-guard:refactor-guide`. If the command needs to accept a file-or-directory path, describe the argument in the skill body as: `$ARGUMENTS is a file path or directory to refactor. ...`  The runtime passes the user-typed string verbatim as `$ARGUMENTS`.

---

## Quick-Reference: Adding the New Skill + Command

1. **Create** `plugins/slop-guard/skills/<new-name>/SKILL.md` with these frontmatter fields:
   ```yaml
   ---
   name: <new-name>
   description: "<shown in palette; state the argument shape here>"
   user-invocable: true
   disallowedTools: []     # or omit if no tool restrictions needed
   ---
   ```
2. **Keep under budget:** ≤ 150 lines, ≤ ~12 000 characters (3 000 tokens × 4 chars). `catalog_test.sh:237-246` will fail CI otherwise.
3. **Document `$ARGUMENTS`** at the top of the body: `$ARGUMENTS is a file or directory path.`
4. **Optional agent:** if the command should spawn a subagent, add `agents/<new-name>.md` and reference it from the skill with `agent: <new-name>` and `context: fork`.
5. **No other file needs to change.** The slash command `/slop-guard:<new-name>` is exposed automatically by `user-invocable: true`.
