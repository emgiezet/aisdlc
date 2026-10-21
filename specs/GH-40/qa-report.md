**Verdict: PASS**

Ticket: GH-40
Verification map: none

Coordinator-implemented slice; UC evidence below. Test locations refer to sections of `evals/harness/selftest.sh` on branch `emgiezet/next-issues-work`.

## UC × test coverage

| UC | requirement (abbreviated) | test location | result |
|----|---------------------------|---------------|--------|
| UC-1 | absent/null readiness_min are no-ops | selftest GH-40 UC-1 | ✅ pass |
| UC-2 | below threshold blocks; readiness.md written | selftest GH-40 UC-2 | ✅ pass |
| UC-3 | --force queues with warning and score | selftest GH-40 UC-3 | ✅ pass |
| UC-4 | above threshold queues; READY column | selftest GH-40 UC-4/UC-5 | ✅ pass |
| UC-6 | non-JSON fails closed; --force persists no score | selftest GH-40 UC-6 + force-bounds cases | ✅ pass |
| UC-7 | --issue route skips readiness | selftest GH-40 UC-7 | ✅ pass |
| UC-8 | help documents readiness_min | cmd_help grep | ✅ pass |
| bounds | fraction, [7] gaps, rc=1, is_error rejected | selftest GH-40 fail-closed boundaries | ✅ pass |
| omp | omp runtime readiness via stub | selftest GH-40 omp case + live Sonnet run scored 76 | ✅ pass |
| isolation | data-only flags pinned | selftest GH-40 data-only greps | ✅ pass |
| nonint | non-integer threshold refuses clearly | selftest GH-40 non-integer case | ✅ pass |

## Not verified

- The claude-runtime readiness path is stub-covered only: the local Claude CLI OAuth session expired before a live run. The omp path ran live (score 76, task queued).
