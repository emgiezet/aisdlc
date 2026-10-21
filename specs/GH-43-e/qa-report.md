**Verdict: PASS**

Ticket: GH-43-e
Verification map: none

Coordinator-implemented slice; UC evidence below. Test locations refer to sections of `evals/harness/selftest.sh` on branch `emgiezet/next-issues-work`.

## UC × test coverage

| UC | requirement (abbreviated) | test location | result |
|----|---------------------------|---------------|--------|
| UC-25 | cross-repo table, blocked 50%, $0.15/merged, Stopped-at causes | live Sonnet retro run (archive fixture) | ✅ pass |
| UC-26 | --since filters on archived_at | live run (a-7 pre-cutoff absent) | ✅ pass |
| UC-27 | --repo <slug> filters; absent repo → unknown/n-a | live run repo-b | ✅ pass |
| UC-28 | AISDLC_ARCHIVE=off → archive unavailable or disabled | live run | ✅ pass |
| UC-29 | live mode never reads the archive | live run (no archive tool calls) | ✅ pass |
| UC-39 | dedup by attempts; refused/cancelled excluded | live run (a-3 $0.30 not $0.40) | ✅ pass |
| UC-42 | only verified MERGED counts; OPEN/CLOSED excluded | live run ($0.20 over 2 merged) | ✅ pass |

## Not verified

- The spec’s test column names harness-eval, but harness scenarios drive queue phases, not interactive commands; these UCs were verified by live end-to-end runs recorded here instead. UC-25 fixture text corrected to the real BLOCKED.md format (see plan doc).
