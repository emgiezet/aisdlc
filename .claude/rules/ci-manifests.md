---
paths:
  - ".github/workflows/**"
  - ".claude-plugin/**"
  - ".omp-plugin/**"
  - ".grok-plugin/**"
  - ".agents/**"
  - "plugins/*/plugin.json"
  - "plugins/*/package.json"
  - "plugins/*/.claude-plugin/**"
  - "Makefile"
---

# CI workflows, plugin manifests, Makefile

## Conventions observed here

- Workflows (slop-guard AP-CI rules, followed by `release.yml`):
  - every `uses:` pinned to a full 40-char commit SHA, tag in a trailing comment (AP-CI-001)
  - top-level `permissions: contents: read`; `write` scoped to the one job that needs it (AP-CI-004)
  - no `${{ … }}` inside `run:` — values arrive through `env:` (AP-CI-003)
  - shell steps that can fail mid-pipe use herestrings, not `printf | grep -q`, under `pipefail`
  - `validate.yml` still has tag-pinned actions (`@v7`); a change to that file pins what it touches
- The `Makefile` owns lists: `COMMANDS`, `SKILLS`, `AGENTS`, `PLAYBOOKS`, `TRACKERS`, `BROWSERS`,
  `VERIFY`, `SCRIPTS`, and the version-carrying files behind `bump-*`. CI calls make targets
  instead of restating a list.
- Four hosts, two plugins: names, source paths and versions agree across `.claude-plugin/`,
  `.omp-plugin/`, `.grok-plugin/`, `.agents/plugins/` and each plugin's `plugin.json`,
  `.claude-plugin/plugin.json`, `package.json`. The sdlc `skills` arrays in the Claude and omp
  marketplaces are identical and alphabetical.
- `version` fields change only through `make bump-*` on a release PR; the
  release workflow tags a validated merge and never pushes commits to `main`.

## Verification

```bash
CI= make validate                                  # JSON, cross-host names/paths/versions, lists
zizmor .github/workflows/                          # when installed via slopguard doctor --install
diff <(jq -r '.plugins[]|select(.name=="sdlc")|.skills[]' .claude-plugin/marketplace.json) \
     <(jq -r '.plugins[]|select(.name=="sdlc")|.skills[]' .omp-plugin/marketplace.json) && echo manifests-agree
```

A changed workflow step is executed, not just linted: extract it with
`/usr/bin/python3` + `yaml` and run it against a scratch clone in `mktemp -d`.
