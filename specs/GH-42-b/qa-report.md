**Verdict: PASS**

Ticket: GH-42-b
Verification map: none

Coordinator-implemented slice; UC evidence below. Test locations refer to sections of `evals/harness/selftest.sh` on branch `emgiezet/next-issues-work`.

## UC × test coverage

| UC | requirement (abbreviated) | test location | result |
|----|---------------------------|---------------|--------|
| UC-1a..UC-4 | unknown/object signature rules fire isolated | fast.sh MAINT007_CASES table (5 probes) | ✅ pass |
| UC-5/6 | Reflect.get/apply fire isolated | fast.sh MAINT008_CASES table (2 probes) | ✅ pass |
| UC-7 | good fixtures silent; combined bad files report | fast.sh good loop + combined-fixture blocks | ✅ pass |
| ids | AP-ids present in catalog | catalog_test D36 id-existence check (GH-42-b rows) | ✅ pass |
| fixtures | GH-42-a good fixtures stay clean | good/AP-TS-MAINT-005/006 with unknown-value boundary | ✅ pass |

## Not verified

- Live ESLint only: all nine rules verified against the real pinned eslint-stack via make tool-integration (20 anti-slop cases pass).
