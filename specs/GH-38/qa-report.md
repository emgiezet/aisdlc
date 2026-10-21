**Verdict: PASS**

Ticket: GH-38
Verification map: none

Coordinator-implemented slice; UC evidence below. Test locations refer to sections of `evals/harness/selftest.sh` on branch `emgiezet/next-issues-work`.

## UC × test coverage

| UC | requirement (abbreviated) | test location | result |
|----|---------------------------|---------------|--------|
| UC-1 | count=cap → no pop, exit 0; unavailable count exits non-zero | selftest GH-38 UC-1/UC-1b | ✅ pass |
| UC-2 | spend cap stops after 2 of 3 tasks | selftest GH-38 UC-2 | ✅ pass |
| UC-3 | null defaults drain queue; config beats env | selftest GH-38 UC-3/UC-3b | ✅ pass |
| UC-4 | status names the stopping limit and spend | selftest GH-38 UC-4a/4b | ✅ pass |
| UC-5 | all-subscription queue warns; null cost shown n/a | selftest GH-38 UC-5 | ✅ pass |
| UC-6 | env cap over GitHub; labelled PRs counted across pages; fail-closed | selftest GH-38 UC-6 (stub-gh pagination) | ✅ pass |
| UC-7 | in-flight tasks finish; barrier proves 2 in flight | selftest GH-38 UC-7 (deadline-bound barrier) | ✅ pass |
| UC-8 | non-numeric cap exits non-zero before pop | selftest GH-38 UC-8 | ✅ pass |

## Not verified

- Concurrent second `run` refusal is covered by a selftest case with a sleeping stub; the GitHub tracker against the real gh API is covered by the stub-gh pagination case only (no live GitHub run).
