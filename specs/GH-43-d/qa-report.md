**Verdict: PASS**

Ticket: GH-43-d
Verification map: none

Coordinator-implemented slice; UC evidence below. Test locations refer to sections of `evals/harness/selftest.sh` on branch `emgiezet/next-issues-work`.

## UC × test coverage

| UC | requirement (abbreviated) | test location | result |
|----|---------------------------|---------------|--------|
| UC-19 | ls rows and filters | selftest UC-19/UC-20 | ✅ pass |
| UC-21 | show bare id lists attempts; id.n shows only that attempt | selftest UC-21 + archive-fixes section | ✅ pass |
| UC-22 | unknown id → not found | selftest UC-22 | ✅ pass |
| UC-23 | grep searches phases/sessions, never spec/ | selftest UC-23 (behavioral assertion) | ✅ pass |
| UC-24 | prune removes old, retains young; prune-all empties index | selftest UC-24 + prune-all regression | ✅ pass |
| UC-38 | shared-path entries retained with warning | selftest UC-38 | ✅ pass |
| UC-40 | root/relative/symlink/outside safety | selftest UC-40 | ✅ pass |

## Not verified

- Prune concurrency is verified by the flock-held two-pass rewrite and the lock test, not by racing processes.
