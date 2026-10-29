# Playbook — Release, versioning, manifests, CI workflows

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
The CI/manifest rules file attaches on its own.

## How a release happens (protected main)

On a release branch, run `make bump-patch|bump-minor|bump-major`. Only when
`plugins/slop-guard/` changed since its last release, also run
`make bump-slopguard`. Open a PR titled exactly `chore(release): vX.Y.Z` and
squash merge it only after its checks pass. `Validate` green on `main` triggers
`.github/workflows/release.yml` (`workflow_run`): it checks the release commit
subject against the sdlc manifest, validates every host manifest, pushes only
the tag, and publishes the GitHub release. Other commits skip the release.
`main` forbids direct pushes, even from `GITHUB_TOKEN`.

## Sequence

1. **Blast radius first.** A workflow runs with repository tokens; a manifest change decides what
   every user's host installs. Name what breaks if this is wrong: no release, a release loop, a
   host that cannot install, or a token that leaks.
2. **Versions are the Makefile's.** `bump-*` targets own the list of
   version-carrying files across the four hosts and both plugins. Run them
   on the release branch, never edit a version field manually.
3. **Manifests move together.** `.claude-plugin/`, `.omp-plugin/`, `.grok-plugin/`,
   `.agents/plugins/` and `plugins/*/{plugin.json,package.json,.claude-plugin/plugin.json}` —
   `make validate` checks names, paths and versions agree across hosts.
4. **Workflow hardening, every edit** — SHA pins, least `permissions`, no `${{ }}` in `run:`,
   herestrings under `pipefail`: the conventions in `.claude/rules/ci-manifests.md`, applied to
   every step you touch.
5. **No loops.** Workflow-run ignores ordinary commits and only tags a
   validated release PR merge. Reruns reuse a tag only if it points at HEAD.
6. **Never weaken a gate.** Removing a test step, adding `continue-on-error`, `if: false` or a
   skip is a test-gate change: say so in the PR body with the reason, and slop-guard will ask.

## Test requirements

Workflows have no unit tests; execute their steps instead of asserting them:

- Extract changed steps with a YAML parser and run them against a scratch
  clone. Prove a normal commit skips, a release commit with a mismatched
  version fails, and a matching release commit tags without pushing `main`.
- `make bump-<level>` in that clone, then the version-consistency step, both green.
- After merge, observe the real `Release` run: exactly one tag pointing at
  the validated release commit, and a GitHub release for that tag.

## Verify

The verification block in `.claude/rules/ci-manifests.md`; `zizmor .github/workflows/` when it is
installed (`plugins/slop-guard/bin/slopguard doctor --install`).

## Done when

Blast radius stated, versions moved only through `make bump-*`, every manifest agrees, every
action SHA-pinned with least permissions and no inline interpolation, changed steps executed in a
scratch clone, and `CI= make validate` green.
