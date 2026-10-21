**Verdict: PASS**

Ticket: GH-43-f
Verification map: none

Coordinator-implemented slice; UC evidence below. Test locations refer to sections of `evals/harness/selftest.sh` on branch `emgiezet/next-issues-work`.

## UC × test coverage

| UC | requirement (abbreviated) | test location | result |
|----|---------------------------|---------------|--------|
| UC-31 | exact phase order; session_id on claude phases only | selftest UC-31 (exact jq sequence) | ✅ pass |
| UC-32 | run_phase failure and GH-52 empty-diff recorded FAIL | selftest UC-32 (both paths) | ✅ pass |
| UC-33 | scope-check BLOCKED: no verify, phases recorded | selftest UC-33 (backticked Out:) | ✅ pass |
| UC-34 | verify FAIL entry with null session | selftest UC-34 | ✅ pass |
| UC-35 | legacy record archives with phases null; earlier archive untouched | selftest UC-35 (cancel path) | ✅ pass |
| UC-36 | manifest.model equals task model | selftest UC-36 | ✅ pass |
| UC-37 | manifest.models maps each phase | selftest UC-37 | ✅ pass |
