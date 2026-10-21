**Verdict: PASS**

Ticket: GH-41
Verification map: none

Coordinator-implemented slice; UC evidence below. Test locations refer to sections of `evals/harness/selftest.sh` on branch `emgiezet/next-issues-work`.

## UC × test coverage

| UC | requirement (abbreviated) | test location | result |
|----|---------------------------|---------------|--------|
| UC-1 | PR body contains Change map + before/after table | live ship smoke: MAP-1 pr-body.md (12-node graph, UC table) | ✅ pass |
| UC-2 | out-of-scope node carries warning style | live smoke (styled Other node) + selftest classification helpers | ✅ pass |
| UC-3 | docs-only diff omits the section | instruction prose (ship.md --docs rule) | ⚠ instruction-level |
| UC-4 | ship.md example mermaid parseable, ≥2 nodes ≥1 edge | selftest GH-41 UC-4 + browser render of the example | ✅ pass |
| UC-5 | ≤12 nodes with aggregation strategy | live smoke (16 modules → 12 nodes, Other aggregate) + cap text check | ✅ pass |
| UC-6 | README row mentions Change map | selftest GH-41 UC-6 grep | ✅ pass |

## Not verified

- UC-3 (docs-only omission) is verified by instruction inspection only; no live docs-only ship run was made.
