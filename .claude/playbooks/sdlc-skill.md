# Playbook — Knowledge skill under `plugins/sdlc/skills/`

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
Load the `task-router` skill (one rule, one file) and `harness-eval` (how a trigger set is judged).

## Sequence

1. **Prove the gap.** `grep -rn` the topic across `plugins/sdlc/skills/` and `plugins/sdlc/commands/`.
   If a skill already owns it, extend that skill. A second skill on one topic is the defect
   `task-router` exists to prevent.
2. **House format** — copy `architecture-review/SKILL.md` or `security-review/SKILL.md`:
   - line 1 `---`; `name:`; `description: >` with a literal "Use when" sentence (CI greps it)
   - one `#` title, a 2–3 sentence framing paragraph naming the failure mode, then `##` only
   - tables over prose, imperative voice, closing `## Non-negotiable` and `## Review checklist`
   - 85–140 lines; depth goes in `references/*.md` (no frontmatter), linked by relative path
3. **Point at neighbours instead of restating them** — a `## What this skill is not` section or
   one line naming the skill that owns the adjacent rule (severity → `code-review`).
4. **Quote the repo, not memory.** A number or path the skill cites (a default in `bin/aisdlc`,
   a section in `pipeline-contracts`) is read from the file now; name the symbol, not a line.
5. **Trigger set** `agents/eval-set.json`: array of `{query, should_trigger, note}`. CI requires
   at least one negative; the recent skills use six positive and four negative, each negative
   naming the skill that owns that query instead.
6. **Register** — omit one and the skill is invisible or unserved:
   - `Makefile` `SKILLS :=`
   - `.claude-plugin/marketplace.json` and `.omp-plugin/marketplace.json`, sdlc `skills` array,
     alphabetical, the two arrays identical
   - `README.md` — skill count on line 5, the "the <n> knowledge skills" sentence, the skills table
   - `plugins/sdlc/hooks/session-start` — the compact list (`Skills load by name:`) **and** the
     long list (`- <name> — …`, dash-aligned)

## Test requirements

- `make eval-dry` prints `✓ <name> trigger:<p>  no-trigger:<n>` with the counts you wrote.
- Registration agreement, both must print their echo:
  ```bash
  diff <(jq -r '.plugins[]|select(.name=="sdlc")|.skills[]' .claude-plugin/marketplace.json) \
       <(jq -r '.plugins[]|select(.name=="sdlc")|.skills[]' .omp-plugin/marketplace.json) && echo manifests-agree
  diff <(jq -r '.plugins[]|select(.name=="sdlc")|.skills[]' .claude-plugin/marketplace.json | sed 's|^./skills/||' | sort) \
       <(grep '^SKILLS :=' Makefile | cut -d= -f2 | tr ' ' '\n' | grep -v '^$' | sort) && echo makefile-agrees
  ```
- Every `references/` link resolves; `grep -c '^### ' SKILL.md` is 0.
- One live load: `claude -p "<a positive query>" --plugin-dir plugins/sdlc --model sonnet
  --max-budget-usd 1 --output-format stream-json --verbose --allowedTools=Skill,Read` shows a
  `Skill {"skill":"sdlc:<name>"}` call and an answer built from the skill's tables.

## Verify

The verification block in `.claude/rules/instructions.md`.

## Done when

The gap was proven, the skill links rather than repeats, the trigger set has negatives naming
their owners, all registration points agree, `CI= make validate` is green and the live load
picked the skill.
