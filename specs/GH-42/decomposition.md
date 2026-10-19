# Decomposition — GH-42

Source: https://github.com/emgiezet/aisdlc/issues/42 (map dmmulroy/anti-slop into AP-TS-*)

Estimate: ~650 added lines · 39 files · 1 module (budget 400/15/6 from PR #45's profile).
Files break the budget: per AP id a catalogue entry, a generated reference page, two fixtures and
integration cases.
Seam: vertical by AP-id group. `-a` carries the decision, the package pin and the plugin
registration, so `-b` and `-c` only add rules.

| Slice | Outcome a user or operator can see | UCs | Budget | Depends on |
|---|---|---|---|---|
| `GH-42-a` | D36 maps all 23 upstream rules; the ESLint port is pinned; fabricated type evidence reported as `AP-TS-MAINT-005/006` | UC-1…UC-7 | 260 lines, 15 files | — |
| `GH-42-b` | `unknown`/`object` contracts and `Reflect` access reported as `AP-TS-MAINT-007/008` | UC-8…UC-14 | 210 lines, 12 files | `-a` |
| `GH-42-c` | accumulator-copying reducers and module mocking reported as `AP-TS-PERF-005`, `AP-TS-MAINT-009` | UC-15…UC-21 | 190 lines, 12 files | `-a` |

Order: -a → (-b, -c in either order). Each merges on its own.

Not sliced out:
- The D36 table lists every rule, including those `-b` and `-c` add, with the slice named per
  row: a decision recorded once is cheaper to review than three partial tables.
- Generated reference pages ride with their catalogue entry: `gen-skills --check` in
  `make validate` fails any commit that separates them.

Corrections to the issue, verified upstream:
- Upstream at `c44ef22` (the commit the ESLint port tracks) has 23 rules — 18 generic, 5 Effect —
  not 15. D36 maps all 23.
- `@spacemansh/anti-slop` 0.3.0 (MIT) ships all 18 generic rules for ESLint as `anti-slop/<name>`,
  with no runtime dependencies and optional peers; no custom ESLint rule is needed.
- ESLint has no port of Oxlint's `no-accumulating-spread`; the spread form of an accumulator copy
  stays prevention-only.
