# Decomposition — SDLC-016

Estimate: ~1450 added lines · ~110 files · 18 modules (budget 400/15/6, ceiling 3000)
— measured: 584 lines with a literal `/sdlc:` in 89 authored files across 14 modules (specs,
`docs/plans/` and `docs/research/` excluded as historical records), plus a packager, a
marketplace generator and four generated manifests. The migration is shotgun fan-out by
construction: one pattern, ~7 lines per file.
Seam: seam first, then mechanical

| Slice | Outcome a user or operator can see | UCs | Budget | Depends on |
|---|---|---|---|---|
| `SDLC-016-a` | a packager renders the namespace from the manifest; `make validate` fails on a nondeterministic build | UC-1, UC-5, UC-6, UC-7 | 300 lines, 6 files, 4 modules | — |
| `SDLC-016-b` | the four marketplaces are generated from one source; a hand edit or a stale file fails `--check` | UC-3, UC-4, UC-4a, UC-4b | 350 lines, 10 files, 6 modules | `-a` |
| `SDLC-016-c` | every host, `install.sh`, the queue and the eval load the packaged tree — byte-identical behaviour | UC-8a, UC-8c, UC-8d | 150 lines, 8 files, 6 modules | `-b` |
| `SDLC-016-d` | `mechanical: true` — authored `/sdlc:` literals become the placeholder; a second namespace renders without editing a file | UC-2, UC-8b, UC-8e | 650 lines, 95 files, 14 modules | `-c` |

Order: -a → -b → -c → -d. Each merges on its own; none waits for the next.
Not sliced out: UC-8 split into UC-8a (install path, `-c`) and UC-8b (migrated surface, `-d`);
UC-8c, UC-8d, UC-8e and UC-4a, UC-4b are the checks each slice needs to prove itself. The
migration stays one slice: half-migrated sources would render two vocabularies at once, and
the pattern is reviewed once, not per file. `-d` cannot precede `-c`: an unrendered placeholder
would reach users verbatim.
