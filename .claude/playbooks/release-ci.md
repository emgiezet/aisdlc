# Playbook — Release, versioning, manifests, CI workflows

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
The CI/manifest rules file attaches on its own.

## How a release happens (do not do it by hand)

`Validate` green on `main` → `.github/workflows/release.yml` (`workflow_run`) decides the level
from commits since the last tag (`feat!`/`BREAKING CHANGE` → major, `feat` → minor, else patch),
runs `make bump-<level>`, bumps slop-guard only when `plugins/slop-guard/` changed, commits
`chore(release): vX.Y.Z`, tags, pushes without force, and creates the GitHub release.
`workflow_dispatch` with `level: auto|patch|minor|major` is the manual override.

## Sequence

1. **Blast radius first.** A workflow runs with repository tokens; a manifest change decides what
   every user's host installs. Name what breaks if this is wrong: no release, a release loop, a
   host that cannot install, or a token that leaks.
2. **Versions are the Makefile's.** `bump-*` targets own the list of version-carrying files across
   the four hosts and both plugins. A new manifest is added to that list, never bumped from CI
   by a second hand-written list.
3. **Manifests move together.** `.claude-plugin/`, `.omp-plugin/`, `.grok-plugin/`,
   `.agents/plugins/` and `plugins/*/{plugin.json,package.json,.claude-plugin/plugin.json}` —
   `make validate` checks names, paths and versions agree across hosts.
4. **Workflow hardening, every edit** — SHA pins, least `permissions`, no `${{ }}` in `run:`,
   herestrings under `pipefail`: the conventions in `.claude/rules/ci-manifests.md`, applied to
   every step you touch.
5. **No loops.** Pushes by `GITHUB_TOKEN` do not retrigger workflows; keep the `chore(release):`
   HEAD guard as the second defence.
6. **Never weaken a gate.** Removing a test step, adding `continue-on-error`, `if: false` or a
   skip is a test-gate change: say so in the PR body with the reason, and slop-guard will ask.

## Test requirements

Workflows have no unit tests; execute their steps instead of asserting them:

- Extract the changed step with a YAML parser and run it against a scratch clone:
  `/usr/bin/python3 -c 'import yaml; …'` (the brew `python3` lacks pyyaml), in a `mktemp -d`.
- `make bump-<level>` in that clone, then the version-consistency step, both green.
- After merge, watch the real run: `gh run list --workflow Release --limit 3`, and confirm one
  release per merge, tag on `main`, no second run triggered by the bot commit.

## Verify

The verification block in `.claude/rules/ci-manifests.md`; `zizmor .github/workflows/` when it is
installed (`plugins/slop-guard/bin/slopguard doctor --install`).

## Done when

Blast radius stated, versions moved only through `make bump-*`, every manifest agrees, every
action SHA-pinned with least permissions and no inline interpolation, changed steps executed in a
scratch clone, and `CI= make validate` green.
