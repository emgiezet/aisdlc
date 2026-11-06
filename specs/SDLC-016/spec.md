---
ticket: SDLC-016
title: Namespace placeholders and generated host packaging
status: superseded
stacks: [bash, instructions]
---

# SDLC-016 — Namespace placeholders and generated host packaging

Superseded by four slices — see [decomposition.md](decomposition.md): `SDLC-016-a` → `-b` → `-c` → `-d`.

## Problem

The command namespace is embedded in commands, templates, documentation, and fixtures instead
of coming from plugin metadata. A tracked-working-tree grep measured **1,031 occurrences of
`/sdlc:` across 129 tracked files**, before these draft specs were created; this supersedes the
older comparison estimate. Four independently maintained marketplace manifests also repeat
shared metadata in different host schemas, so renaming or packaging for another host requires
coordinated manual edits with no deterministic generation gate.

## Scope

In:
- Replace the literal namespace references throughout the tracked source surface with a
  declared placeholder resolved from plugin metadata at package time; migrate callers,
  documentation, fixtures, and checks together rather than preserving a legacy alias.
- Generate `.claude-plugin/marketplace.json`, `.agents/plugins/marketplace.json`,
  `.grok-plugin/marketplace.json`, and `.omp-plugin/marketplace.json` from one authoritative
  shared metadata source, retaining each host's required schema and plugin inventory.
- Preserve today's default command invocations in packaged output, while proving a different
  namespace can be selected without editing authored command text.
- Provide a packaging `--check` mode that compares independent generations for determinism,
  and invoke it from `make validate` so nondeterministic packaging fails validation.
- Keep release/version updates consistent with the authoritative metadata and generator.

Out:
- Renaming the public default namespace as part of this change or retaining old-name shims.
- Parameterising rule ids, policy directories, artefact directories, or verification commands;
  those are separate overlay-contract holes.
- Replacing the queue runtime, adding a host, or redesigning host manifest schemas.
- Pulling generated output or executable code from the external comparison repository.

Change budget: 1800 added lines, 150 files, 30 modules

The wider budget covers the measured mechanical namespace migration plus its generator and
fixtures; replaced source lines count as additions. It does not authorise unrelated prose or
runtime changes. Re-estimate the file/module totals against the selected packaging layout
before approval if the complete caller migration exceeds this envelope.

## Context

- `docs/overlay-contract.md:24-38` — the parameterisation table; its first hole is plugin id
  and command namespace, sourced from the plugin manifest (`docs/overlay-contract.md:31`).
- `plugins/sdlc/.claude-plugin/plugin.json` and `plugins/sdlc/plugin.json` — existing native
  and portable plugin manifests, the metadata inputs whose ownership must be reconciled.
- `.claude-plugin/marketplace.json` and `.omp-plugin/marketplace.json` — marketplace
  `plugins[]`, string `source`, versions, and the SDLC skills list.
- `.agents/plugins/marketplace.json` — marketplace `plugins[]`, local `source.path`, policy,
  category, and interface fields.
- `.grok-plugin/marketplace.json` — marketplace `plugins[]`, `source.type`/`source.path`,
  category, keywords, and versions.
- `Makefile` — `PLUGIN_JSON`, `MARKETPLACE_JSON`, `CODEX_MARKETPLACE`, `GROK_MARKETPLACE`,
  `OMP_MARKETPLACE`, `PORTABLE_SDLC_JSON`, and `validate`; existing cross-marketplace checks
  are constraints on the generated host projections, not a reason to collapse their schemas.
- `plugins/sdlc/commands/implement.md`, `plugins/sdlc/templates/sdlc.md`, and
  `evals/harness/stub-claude` — representative authored instruction, consumer template, and
  namespaced-command fixture surfaces in the measured migration.
- `evals/harness/selftest.sh` — deterministic packaging and namespace regression fixtures.
- External model, paths relative to the read-only comparison clone: prose tokens
  `{{HARNESS_DIR}}` and `{{INVOKE}}` are declared in `scripts/package.ts:171-172`;
  invocation replacement is in `scripts/package.ts:207-216` and Markdown transformation
  calls the token substitution in `scripts/package.ts:407-426`. The packager documents
  directory/invocation projection in `scripts/package.ts:10-14,27-30`; its `--check` contract
  compares two independent temporary builds (`scripts/package.ts:34-37`) and the CLI exits
  1 on determinism problems (`scripts/package.ts:2220-2229`). Borrow the projection boundary,
  not the TypeScript implementation or its full host catalogue.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | maintainer | packages with the existing default plugin metadata | generated instructions render today's default namespace, contain no unresolved namespace placeholders, and command handoffs retain their command names and arguments | integration |
| UC-2 | maintainer | packages the same authored sources with a different namespace in the authoritative metadata | generated invocation references use that namespace throughout; command suffixes and arguments are preserved without editing authored sources or providing old-name aliases | integration |
| UC-3 | maintainer | generates all host marketplaces | all four named `marketplace.json` files parse; each retains its host-specific source shape and required fields, with the existing plugin inventory and consistent shared names, descriptions, versions where present, and skills where present | unit |
| UC-4 | maintainer | changes one shared metadata value in the authoritative source and regenerates | each applicable host projection reflects the same new value, with no manual edits to any generated marketplace file | unit |
| UC-5 | maintainer | runs packaging `--check` on deterministic inputs | exits 0 after comparing byte-identical output from two independent generations; authored sources and existing generated files remain byte-identical to their pre-check contents | selftest |
| UC-6 | maintainer | runs packaging `--check` with a fixture whose generation produces different bytes between runs | exits non-zero and names the differing output; it does not overwrite existing source or generated files | selftest |
| UC-7 | maintainer | runs `make validate` with the UC-6 nondeterministic packaging fixture | validation invokes the packaging `--check` gate and exits non-zero instead of reporting success | integration |
| UC-8 | maintainer | scans the migrated authored source surface and runs the command fixtures against packaged output | namespace references use the declared placeholder rather than literal default-namespace invocations; the namespaced command fixture still recognises the rendered commands, and the default package passes the existing cross-marketplace checks | integration |

`test` = the lowest tier that can observe the result: `selftest` | `unit` | `integration`.

## Open questions

- [ ] What exact placeholder spelling and authored/generated directory layout will let all
  four hosts consume rendered commands without rendering authored files in place? Decide
  which generated projections are committed and which are release-only before approval.
- [ ] Which existing plugin metadata becomes authoritative, and how are shared marketplace
  metadata versus host-only schema fields separated? Define how the existing release targets
  update the source before regenerating; generated manifests must not become a second source.
- [ ] Does `--check` additionally detect stale committed output, or only nondeterministic
  generation? UC-5/UC-6 require determinism and no writes; stale-output policy is a separate
  decision and must not be implied by a byte-comparison success message.
- [ ] How are placeholder literals in instructional examples, historical documents, regexes,
  and shell fixture strings escaped or rendered without changing their meaning? Inventory the
  complete 129-file measured surface and keep no unexamined caller outside the migration.
- [ ] What packaging command/interface and runtime dependency fit the existing bash tooling,
  and how will a clean checkout obtain the generated host projections before installation?
  Choose the entry-point path rather than assuming a script already exists.
