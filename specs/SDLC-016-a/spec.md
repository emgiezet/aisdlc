---
ticket: SDLC-016-a
title: A deterministic plugin packager that renders the command namespace from the manifest
status: draft
stacks: [bash, instructions]
---

# SDLC-016-a — Deterministic plugin packager

## Problem

The command namespace can only become a placeholder once something renders it, and nothing
does: hosts install `plugins/sdlc/` exactly as authored. Before any authored text moves, the
repository needs a packager that turns authored sources into a host-ready tree with the
namespace filled in from the plugin manifest, and a gate that proves that output is the same
every time it is built.

## Scope

In:
- A bash packager that copies `plugins/sdlc/` into an output tree, replacing a declared
  namespace placeholder with the `name` from the plugin manifest; text without a placeholder
  passes through byte-identical, so today's literal `/sdlc:` sources package unchanged.
- A `--check` mode that builds twice into independent temporary trees, compares them byte for
  byte, names any differing path, and writes nothing outside its temporary directory.
- `make validate` runs the `--check` gate.
- The placeholder spelling, the output location and whether output is committed or
  release-only — decided in Open questions before approval and documented with the packager.

Out:
- Generating any `marketplace.json`, which is `SDLC-016-b`.
- Pointing any host's install source at the packaged tree, which is `SDLC-016-c`.
- Replacing literal `/sdlc:` in authored sources, which is `SDLC-016-d`.
- Renaming the default namespace; parameterising rule ids, policy or artefact directories.

Change budget: 300 added lines, 6 files, 4 modules

## Context

- `plugins/slop-guard/scripts/gen-skills` — house precedent for a bash generator with
  `--check` ("idempotency check (runs twice, diffs)"); match its flags and exit codes.
- `plugins/sdlc/.claude-plugin/plugin.json` and `plugins/sdlc/plugin.json` — the manifest
  whose `name` is the namespace; decide which one the packager reads.
- `Makefile` — `validate` target and the `SCRIPTS :=` list (syntax, executable, shellcheck).
- `.github/workflows/validate.yml` — the shellcheck list a new script joins.
- `evals/harness/selftest.sh` — where the determinism cases run against fixtures.
- `docs/overlay-contract.md:31` — the namespace hole this slice starts to close.
- Source spec: `specs/SDLC-016/spec.md`; plan: `specs/SDLC-016/decomposition.md`.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | maintainer | packages a fixture plugin whose commands contain the placeholder, with default manifest metadata | output files render `/sdlc:` where the placeholder stood, contain no unresolved placeholder, and every other byte matches the source | selftest |
| UC-5 | maintainer | runs the packager's `--check` on deterministic inputs | exit 0 after two independent builds compare byte-identical; authored sources and any existing output are byte-identical to before | selftest |
| UC-6 | maintainer | runs `--check` on a fixture whose build differs between runs | non-zero exit naming the differing path; no source or existing output file is written | selftest |
| UC-7 | maintainer | runs `make validate` with the UC-6 fixture in place of the real tree | validate invokes the `--check` gate and exits non-zero | integration |

## Open questions

- [ ] The placeholder spelling (it must never occur by accident in prose, regexes or shell).
- [ ] Where the output tree lives, and whether it is committed or produced only at release.
- [ ] Which manifest is authoritative for `name` when the native and portable ones disagree.
