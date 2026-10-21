**Verdict: PASS**

Ticket: GH-39
Verification map: none

Coordinator-implemented slice; UC evidence below. Test locations refer to sections of `evals/harness/selftest.sh` on branch `emgiezet/next-issues-work`.

## UC × test coverage

| UC | requirement (abbreviated) | test location | result |
|----|---------------------------|---------------|--------|
| UC-1 | both passes APPROVED → merged APPROVED; per-pass counts | live Sonnet run, profile key | ⚠ not observed live |
| UC-2 | first APPROVED, adversarial CHANGES_REQUESTED → stricter wins | instruction prose review.md | ⚠ not observed live |
| UC-3 | first CHANGES_REQUESTED, adversarial APPROVED → stricter wins | instruction prose review.md | ⚠ not observed live |
| UC-4 | same finding in both passes appears once untagged | live run (shared blockers merged; adversarial-only nit tagged) | ✅ pass |
| UC-5 | adversarial pass independent; git log -p before aggregate diff | live runs: subagent transcripts show git log -p first | ✅ pass |
| UC-6 | no flag/key → one pass, no Pass N lines | live run on plain fixture | ✅ pass |
| UC-7 | profile key activates two passes | live run on key-true fixture (2 passes, per-pass counts) | ✅ pass |
| UC-8 | spec-only PR skips adversarial pass | live run on spec-only fixture | ✅ pass |
| UC-9 | local diff/mergeability against stored base; fail closed | selftest GH-39 UC-9 (template ops) | ✅ pass |

## Not verified

- UC-1/UC-2/UC-3 merge-rule disagreement cases were not observed live: both passes returned CHANGES_REQUESTED in every live run. The merge rule is instruction-level and verified by inspection; waived by the user’s merge authorization of 2026-10-21.
