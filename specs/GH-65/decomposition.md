# Decomposition — GH-65

Source: https://github.com/emgiezet/aisdlc/issues/65

Estimate: approximately 850 added lines · 54 files · 2 modules (budget 400/15/6). The eight affected rule files, up to 44 paired-fixture files, one integration test and the changelog exceed the file and line budgets even though they share a module. Comparable commits: `a61af73` changed 9 relevant files, `8d1e0c2` changed 10, and the original rule/fixture commit `beca0dd` changed 114. This estimate includes a real-binary test, not only the YAML changes.
Delivered across all slices: 1,302 added lines in 53 non-spec files, including focused adversarial fixtures discovered during review; the original estimate was low but the combined slice budgets cover the delivered source.

Delivery seam: five language repair PRs followed by one whole-ruleset enforcement PR. Each repair retains the existing test suite; the final gate is introduced only after every rule passes. No suppression or quarantine is used. The approved slice specs are preserved unchanged; their shared test acceptance criteria are delivered by the final dependent enforcement PR rather than a partial scoped gate.

| Slice | Observable outcome | UCs | Budget (added/files/modules) | Depends on |
|---|---|---|---|---|
| `GH-65-a` | C# six-rule fixture contract and real-binary scoped test | UC-1–UC-4 | 350/15/2 | — |
| `GH-65-b` | Rust five-rule fixture contract | UC-5–UC-6 | 270/13/2 | `GH-65-a` |
| `GH-65-c` | Ruby four-rule fixture contract | UC-7–UC-8 | 220/11/2 | `GH-65-b` |
| `GH-65-d` | JVM, Go and Node four-rule fixture contract | UC-9–UC-10 | 300/13/2 | `GH-65-c` |
| `GH-65-e` | React and Laravel three-rule fixture contract; all configured rules enforced | UC-11–UC-14 | 240/11/2 | `GH-65-d` |

Review order: C# → Rust → Ruby → JVM/Go/Node → React/Laravel → enforcement. Each PR is based on the previous branch so the final gate is evaluated against all repairs. The original local-only commit remains preserved separately; the review branches contain its source changes split by this order. Each review diff meets the repository-wide 400 added line / 15 file budget (specs excluded).

Not sliced out: the existing offline YAML/fixture-presence checks stay in place; each slice keeps its fixture pairs and rule fixes together. No catalogue IDs, mappings, tool pins, generated skills or detection pipeline behavior change.
