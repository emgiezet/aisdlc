**Verdict: PASS**

Ticket: GH-43-c
Verification map: none

Coordinator-implemented slice; UC evidence below. Test locations refer to sections of `evals/harness/selftest.sh` on branch `emgiezet/next-issues-work`.

## UC × test coverage

| UC | requirement (abbreviated) | test location | result |
|----|---------------------------|---------------|--------|
| UC-14 | claude transcript copied and redacted; sha256 matches manifest | selftest UC-14 | ✅ pass |
| UC-15 | omp session files copied | selftest UC-15 + multi-file archive probe | ✅ pass |
| UC-16 | missing transcript → copied:false reason:not found | selftest UC-16 | ✅ pass |
| UC-17 | archive_transcripts=off → disabled | selftest UC-17 | ✅ pass |
| UC-18 | profile Archive: off (backtick) prevents archiving | selftest + coordinator probe | ✅ pass |
| UC-30 | real scanner redacts; no network | betterleaks v2.0.0-rc.4 probe, strace zero connect/send | ✅ pass |
| UC-43 | metadata sanitized; traversal contained; rc=0 incomplete withheld; multiline replaced; replacement failure withheld | coordinator security probes (all green) | ✅ pass |

## Not verified

- Scanner coverage uses the verified official v2.0.0-rc.4 binary (SHA256-matched release asset); the managed lockfile still pins 1.8.1, so production hosts without v2 keep built-in-only redaction.
