---
paths:
  - "plugins/slop-guard/rules/**"
  - "plugins/slop-guard/configs/**"
  - "plugins/slop-guard/skills/**"
  - "plugins/slop-guard/tools/**"
---

# slop-guard catalogue, mappings, configs and generated skills

## Conventions observed here

- `rules/catalog.yaml` is the only source of `AP-*` ids. Ids are `AP-<LANG>-<AREA>-<NNN>` or
  `AP-<AREA>-<NNN>` (`AP-AGENT-002`, `AP-AUTH-007`, `AP-CI-001`); never renumbered, never reused.
- Severity scale `blocker | error | warn | info`; categories `security | performance |
  maintainability | supply-chain`. Security plus a CWE Top 25 entry is `blocker`.
- Text is original. CWE by number with the `cwe.mitre.org` URL; OWASP and vendor docs as links.
- `skills/*-antipatterns/**` and `skills/agent-discipline/**` (SKILL.md and `reference/<ID>.md`)
  are **generated** by `scripts/gen-skills` — edit the catalogue and regenerate. Hand-written
  skills here: `deslop`, `secure-review`.
- Generated SKILL.md budget: ≤ 150 lines, ≤ 3000 tokens (≈ 4 chars/token); gen-skills fails over it.
- `rules/mapping/<tool>.yaml` maps the tool's rule id → `ap_id`, `severity`, `category`, `cwe`.
  A tool-wide catch-all uses a bucket id ending `-000` with no catalogue page.
- `tools/tools.lock.json`: per tool a `version`, `bin` and `assets` keyed by platform
  (linux/darwin × amd64/arm64), each with release `url` and `sha256`. Every pinned tool is
  reachable from a stack in `rules/stacks.json` or from `SLOPGUARD_CORE_TOOLS` in `lib/detect.sh`.
- `configs/baseline/` are examples, not defaults imposed on a repo; without adoption only
  `category: security` findings survive the overlay.

## Verification

```bash
plugins/slop-guard/scripts/gen-skills
plugins/slop-guard/scripts/gen-skills --check          # idempotent
git status --short plugins/slop-guard/skills            # every generated change intended
bash plugins/slop-guard/tests/catalog_test.sh
plugins/slop-guard/scripts/validate-configs             # PASS, not SKIP, for the tool you changed
CI= make validate
make tool-integration    # after plugins/slop-guard/bin/slopguard doctor --install --all
```
