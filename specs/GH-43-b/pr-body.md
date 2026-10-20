## GH-43-b — Finished tasks are archived — redacted logs, reports, manifest and index — and survive clean

**QA verdict: PASS** · UC coverage: 8/8 automated · Tests: 250 → 257 · Skipped: 0

🤖 Written by an agent from `specs/GH-43-b/spec.md`. Review the spec's `Out:` scope first —
that is where an unattended run is most likely to have overstepped.

### What the spec asked for

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-6 | queue | a stub task reaches `done` | archive dir exists at `<root>/<repo-slug>/<YYYY-MM>/<id>/` with `manifest.json`, `task.json`, `phases/*.log`, `spec/spec.md`, `spec/qa-report.md`; `sha256sum` of every file equals its `manifest.files` entry | selftest |
| UC-7 | queue | same | `<root>/index.jsonl` gained exactly one line, with that `id`, `status` `done` and the archive `path` | selftest |
| UC-8 | queue | a stub phase log contains a planted `sk-ant-api03-…` key | the archived log has `[REDACTED:anthropic-key]` where the key was, `manifest.redactions["anthropic-key"]` ≥ 1, the live task log is unchanged | selftest |
| UC-9 | queue | a stub task ends `failed` (worktree kept) | archived with `status` `failed` and the worktree's `spec/` reports present | selftest |
| UC-10 | queue | a task is `refused` with `BLOCKED.md` in its worktree | archive holds `spec/BLOCKED.md`, copied before the worktree was removed | selftest |
| UC-11 | maintainer | `aisdlc clean --all` after UC-6 | archive tree and `index.jsonl` byte-identical to before | selftest |
| UC-12 | maintainer | runs a task with `AISDLC_ARCHIVE=off` | no `<root>` directory created, no `index.jsonl` line | selftest |
| UC-13 | maintainer | `aisdlc retry` on the `failed` task from UC-9, which then reaches `done` *(inferred)* | a second dir `<id>.<attempts>/`; the first archive dir unchanged; two index lines for the id | selftest |

### How to verify

```sh
# Full suite (CI path)
CI= make validate

# Runner self-tests only (faster)
make selftest
# Expected: 204 passed, 0 failed

# sdlc plugin unit tests
plugins/sdlc/tests/run-tests
# Expected: 53 passed, 0 failed
```

### Review here first

1. **`plugins/sdlc/bin/aisdlc:1689` — `_arc_redact()`** — regex-based secrets scrubbing applied to every archived text file before sha256 is computed. False negatives leave keys in the archive; false positives corrupt log readability. The rule set is the built-in list only (Anthropic, OpenAI, GitHub, AWS, Bearer, PEM, KEY/SECRET/TOKEN/PASSWORD/API_KEY env lines).

2. **`plugins/sdlc/bin/aisdlc:1748` — `archive_task()`** — core entry point called at every terminal-status site (`done`, `failed`, `refused`, `cancelled`). Non-fatal by contract: any write failure logs a message and returns 0 without altering the task's exit code. Verify the call sites for the `refused` path (worktree removal happens immediately after — the archive copy must precede it).

3. **`plugins/sdlc/bin/aisdlc:~1861` — `flock` on `index.jsonl`** — uses a `.lock` sidecar (not the jsonl itself) so concurrent appends from parallel tasks are safe. The flock fd is released on subshell exit; confirmed correct for the `bash -c` invocation pattern used here.

### Not covered

- Transcript copies, `aisdlc archive ls|show|grep|prune`, `/sdlc:retro --archive`: explicitly out of scope (GH-43-c, GH-43-d, GH-43-e).
- Version-number delta in `package.json`/`plugin.json`: branch pre-dates a version bump on `origin/main`; merge-time concern only, not a defect in this branch.
- Browser: none — no UI in this feature.
