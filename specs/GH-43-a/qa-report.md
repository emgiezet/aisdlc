PASS

## QA Report — GH-43-a

**Ticket:** GH-43-a — Link every phase to the agent session that ran it  
**Branch:** ai/GH-43-a-session-recording  
**Diff base:** main  
**Verification map:** none  
**Suite runs:** `bash evals/harness/selftest.sh` · `CI= make validate`

---

## UC × Test Matrix

| UC | Requirement (summary) | Test location | Status | Coverage type |
|----|----------------------|---------------|--------|---------------|
| UC-1 | `task.json .sessions` has implement + qa entries; `session_id` from phase.json; ISO `started`/`ended` | `selftest.sh:1014–1031` ("sessions: claude records phase sessions (UC-1)") | **PASS** | Automated |
| UC-2 | `transcript` = `$HOME/.claude/projects/<enc>/<sid>.jsonl`; `/` and `.` encoded as `-` | `selftest.sh:1033–1037` ("sessions: transcript encodes worktree path (UC-2)") | **PASS** | Automated |
| UC-3 | omp entry: `runtime=omp`, `session_id`=uuid from `<ts>_<uuid>.jsonl`, `transcript`=absolute path | `selftest.sh:1039–1053` ("sessions: omp records session from sessions/ (UC-3)") | **PASS** | Automated |
| UC-4 | `runtime_version`=first line of `<runtime> --version`; `--version` ran once per task | `selftest.sh:1054–1071` ("sessions: runtime_version from --version (UC-4)") | **PASS** | Automated (value + call-count) |
| UC-5 | Phase with no `session_id`: entry present with `session_id:null`, `transcript:null`; outcome unchanged | `selftest.sh:1072–1079` ("sessions: missing session_id records null (UC-5)") | **PASS** | Automated |

---

## Suite Output

### `bash evals/harness/selftest.sh`

```
163 passed, 0 failed
Wall time: 25.56 seconds
```

Full output: `specs/GH-43-a/qa/selftest.txt`

### `CI= make validate`

```
53 passed, 0 failed
All checks passed.
Wall time: 47.87 seconds
```

Full output: `specs/GH-43-a/qa/validate.txt`

Skipped: 0 in either suite.

---

## Findings

Three assertion-density gaps were identified and closed in Phase 2 before the final run above:

1. **[closed]** `selftest.sh` UC-1 block: `sessions[0].ended` was never asserted. Added: `jq -r '.sessions[0].ended' | grep -qE '^[0-9]{4}-'`.

2. **[closed]** `selftest.sh` UC-1 block: `sessions[1].phase=qa` and `sessions[1].runtime=claude` were not asserted (only `session_id` was checked for the second entry). Added assertion verifying both fields.

3. **[closed]** `selftest.sh` UC-4 block: "ran once per task" constraint had no call-count assertion. Added a counting shim that wraps `stub-claude` and verifies `--version` fires exactly once across a two-phase (`implement`+`qa`) task.

All three gaps were closed with new assertions (see `selftest.sh` diff). No gap required an implementation fix; all gaps were in test-assertion coverage only.

---

## Not Verified

Nothing. All 5 UCs are covered by automated regression tests. No UC was verified by hand only.

Non-functional — "Recording a session never changes a phase's outcome" — exercised by UC-5's `UC-5: outcome unchanged` assertion and implicitly by UC-1 (task reaches `done` with sessions recorded).
