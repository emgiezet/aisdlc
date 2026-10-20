**Verdict: PASS**

Ticket: GH-43-b
Verification map: none

---

## UC × test coverage

| UC | requirement (abbreviated) | test location | assertions | result |
|----|---------------------------|---------------|------------|--------|
| UC-6 | done task → archive dir with manifest, task.json, phases, spec; sha256 matches manifest.files; required manifest fields present | `evals/harness/selftest.sh:1118–1148` | 10 | ✅ pass |
| UC-7 | index.jsonl gains exactly one line; id, status done, path correct | `evals/harness/selftest.sh:1150–1160` | 3 | ✅ pass |
| UC-8 | archived log has `[REDACTED:anthropic-key]`; manifest.redactions ≥ 1; live log unchanged | `evals/harness/selftest.sh:1162–1178` | 4 | ✅ pass |
| UC-9 | failed task archived; manifest status failed; spec/BLOCKED.md and spec/spec.md present | `evals/harness/selftest.sh:1180–1193` | 5 | ✅ pass |
| UC-10 | refused task: archive dir and spec/BLOCKED.md copied before worktree removal | `evals/harness/selftest.sh:1196–1217` | 3 | ✅ pass |
| UC-11 | `clean --all` leaves archive byte-identical | `evals/harness/selftest.sh:1219–1229` | 2 | ✅ pass |
| UC-12 | `AISDLC_ARCHIVE=off` → no archive dir, no index.jsonl entry | `evals/harness/selftest.sh:1232–1247` | 3 | ✅ pass |
| UC-13 | retry → `<id>.2/` dir; first archive unchanged; two index lines | `evals/harness/selftest.sh:1249–1261` | 4 | ✅ pass |

Covered: 8/8 UCs automated · 0 manual-only · Skipped: 0

Non-functional (cancelled task archived — spec scope + non-functional section):
`evals/harness/selftest.sh:1281–1302` — 4 assertions, ✅ pass

---

## Suite output

```
$ make selftest
204 passed, 0 failed   (EXIT 0, ~55 s)
# Before Phase 2 gap tests: 197 passed; 7 assertions added.

$ plugins/sdlc/tests/run-tests
53 passed, 0 failed   (EXIT 0, ~1.4 s)
```

No skipped tests. No `.only()` or focused tests in the diff.

---

## Findings (all resolved by added tests)

All four findings from Phase 1 were minor (test assertions weaker than the UC, or a non-functional requirement untested). None indicated an implementation defect — all tests pass against the existing implementation.

1. **[resolved] UC-9 assertion narrower than spec** — added `spec/spec.md` assertion (`selftest.sh:1191–1193`). The worktree of a failed task carries the spec; it must appear in the archive. Passes.

2. **[resolved] UC-12 missing index.jsonl check** — added grep assertion (`selftest.sh:1243–1246`) verifying `AISDLC_ARCHIVE=off` appends no line to `index.jsonl`. Passes.

3. **[resolved] UC-6 manifest fields not individually validated** — added `jq -e 'has(…)'` assertion (`selftest.sh:1142–1147`) checking `policy_fingerprint`, `aisdlc_version`, `archived_at`, `runtime_version`, `sessions`, `attempts` are all present. Passes.

4. **[resolved] No test for cancelled-task archiving** — added 4-assertion block (`selftest.sh:1281–1302`) covering: status is `cancelled`, archive dir created, manifest status `cancelled`, index.jsonl entry present. Passes.

---

## Not verified

- Browser: none — no UI in this feature.
- Transcript copies, `aisdlc archive` subcommands, `/sdlc:retro --archive`: explicitly out of scope (GH-43-c, GH-43-d, GH-43-e).
- Version-number delta in `package.json`/`plugin.json`: branch pre-dates a version bump on `origin/main`; merge-time concern only, not a defect in this branch.
