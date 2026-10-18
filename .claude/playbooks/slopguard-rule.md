# Playbook — slop-guard rule, catalogue or linter config

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
All paths below are under `plugins/slop-guard/`. The spec is `docs/slop-guard-spec.md`
(§4.9 catalogue schema, §6 mappings, §9.3 config validation, §10 content licensing).

## Sequence

1. **One id, one source.** Every `AP-*` id is born in `rules/catalog.yaml`. Fields: `id`, `title`,
   `language`, `frameworks`, `category`, `severity`, `cwe`, `summary`, `skill_line`, `bad`,
   `good`, `detect`, `prevent_in_skill`, `references`. Copy the nearest entry in the same section
   and keep ids sequential. `detect: []` means prevention only — say so; no pinned tool finds it.
2. **Write it from scratch.** Never paste rule text, examples or messages from Semgrep,
   SonarSource or OWASP. CWE as `CWE-<n>` plus the `cwe.mitre.org` URL; OWASP as a link only.
3. **Detection wiring, when `detect:` names a tool:**
   - the tool's `rules/mapping/<tool>.yaml` maps its rule id to `ap_id`, `severity`, `category`, `cwe`
   - an opengrep rule lives in `rules/opengrep/<lang>.yaml` with id `slopguard.<lang>[.<framework>].<slug>`
   - a bad and a good sample in `tests/fixtures/<lang>/{bad,good}/` so the integration suite
     proves the tool fires on one and stays quiet on the other
4. **A new tool** is pinned in `tools/tools.lock.json` (`version`, `bin`, per-platform `url` + `sha256`),
   listed in a stack's `tools` array in `rules/stacks.json` or in `SLOPGUARD_CORE_TOOLS`
   (`lib/detect.sh`) — `make validate` fails a pinned tool nothing reaches.
5. **A baseline config** goes in `configs/baseline/`; it is an example, not imposed. Findings
   outside `category: security` are dropped by the security overlay unless the user adopts it.
6. **Regenerate, never hand-edit** `skills/*-antipatterns/`: run `scripts/gen-skills`. A new
   language tag that is a concern rather than a stack gets an explicit `skill_paths` case in
   `gen-skills`, not a fake entry in `rules/stacks.json`.
7. **Changelog.** One entry under `## Unreleased` in `CHANGELOG.md`: what changed, file by file,
   and a **Why** paragraph for any choice a reader would question.

## Test requirements

- `tests/catalog_test.sh` covers schema, known tools, mapping consistency, budgets and
  gen-skills idempotency — extend it only for a new invariant, not per entry.
- A detection change: a fixture pair in step 3, proven by `make tool-integration` after
  `bin/slopguard doctor --install --all` (CI runs it with skips counted as failures).
- A config change: `scripts/validate-configs` reports PASS for that tool, not SKIP.

## Verify

The verification block in `.claude/rules/slopguard-catalog.md`.

## Done when

The entry exists once in `catalog.yaml`, its detection (if any) is mapped and has a firing
fixture, generated skills are regenerated and within 150 lines / 3000 tokens, the changelog
says why, and the catalogue suite plus `CI= make validate` are green.
