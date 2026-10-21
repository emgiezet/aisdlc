---
description: Classify finished aisdlc runs by failure cause, rank costs by class, print pipeline metrics, and hand the top cause to /sdlc:issue. Use after any batch of pipeline runs to find which harness file to fix next.
allowed-tools: Bash, Read, Grep, Glob, SlashCommand
---

# /sdlc:retro

Reads `.aisdlc/tasks/` — or, with `--archive`, the cross-repo archive (Phase 0) — and produces a
ranked defect report: every finished task classified, costs summed by class, pipeline metrics
printed as numbers, then one optional issue filed. Never edits `task.json` or any harness file.

Arguments passed: `$ARGUMENTS`. Usage: `[--since <YYYY-MM-DD>] [--repo <slug>] [--archive]`.
When the arguments passed contain `--archive`, start at Phase 0 and never read `.aisdlc/tasks/`.

`--since` defaults to 30 days ago (`date -d '-30 days' +%Y-%m-%d` or equivalent).
`--repo` in live mode defaults to the current directory. In archive mode (`--archive`) there
is no default repo: `--repo` accepts a `repo_slug` value (third column of `aisdlc archive ls`)
and filters only when explicitly passed; omitting it returns tasks from all repos.

Read `.claude/sdlc.md` for the **Tracker descriptor**. Execute tracker operations through
the descriptor file; never substitute bare CLI calls.

---

## Phase 0: Archive mode [runs only when `--archive` is present]

**Skip entirely when `--archive` is absent.** When present, run before Phase 1 and replace it.

1. **Resolve archive root:**
   ```bash
   root="${AISDLC_ARCHIVE:-${XDG_DATA_HOME:-$HOME/.local/share}/aisdlc/archive}"
   ```

2. **Check availability:** If `AISDLC_ARCHIVE=off` or the archive root directory does not exist,
   print `archive unavailable or disabled` and stop (exit 0). The live `.aisdlc/tasks/` is never
   read when `--archive` is present.

3. **Read `<root>/index.jsonl`:** For each line, apply `--since` (compare `.archived_at`, not
   `.updated`) and — only when `--repo` was explicitly passed — `--repo <slug>` (match
   `.repo_slug`; the current-directory default does not apply in archive mode). Resolve `.path`
   for each surviving entry; read `<path>/task.json` (not `manifest.json`) to build each working
   task record — `task.json` carries `.error`, `.created`, `.updated`, `.cost_usd`, `.pr_url`,
   `.attempts`, `.id`, `.status`. Read `<path>/manifest.json` alongside only for the `.repo`
   field used by Phase 3 tracker lookup.

4. **Deduplicate by `(repo_slug, id)`:** If multiple `index.jsonl` entries exist for the same
   `.id` (retried tasks), retain the record with the highest `task.json .attempts`, breaking ties
   by latest index `.archived_at`. The deduplicated cost comes from this single retained record;
   the earlier-attempt record's cost is not counted separately.

5. **Filter to `done` or `failed` status only.** Exclude `refused` and `cancelled` before
   Phases 2–4. The surviving `<path>/task.json` files, one per deduplicated task, replace
   `.aisdlc/tasks/*/task.json` as the input of every Phase 2–4 command, including the Phase 3
   `jq` (drop its `.updated >= $since` clause; `--since` already applied to `.archived_at`
   during filtering in step 3).

6. **Resolve supplementary files from the archive path:** `<path>/spec/qa-report.md` for the
   `gaps` class check (Phase 2), `<path>/spec/BLOCKED.md` for top causes (Phase 4).
   `manifest.pr_url` is used for the PR URL in Phases 2 and 3 tracker lookups.

7. **Tracker lookups in Phases 2 and 3:** for each task, read `<manifest.repo>/.claude/sdlc.md`
   for the tracker descriptor, and execute operations with `<manifest.repo>` as working directory.
   Never pass a filesystem path as the `{owner}/{repo}` tracker argument. Count a PR as merged
   **only** on an explicit merged state, normalising case: `MERGED` from GitHub, `merged` from
   the local provider (`local.md`); `CLOSED` alone is not merged. If `<manifest.repo>` is absent
   on this machine, `<manifest.repo>/.claude/sdlc.md` is missing, or the tracker call fails:
   classify the PR state as `unknown` and the task's review-loop count as `n/a` (print the
   standard unavailability line; **never fall back to the current directory's descriptor**),
   exclude from the merged denominator, and print `n/a` for cost-per-merged-PR when no merged
   tasks have non-null `cost_usd`. Never count a `pr_url` as merged without a successful tracker
   verification.

After Phase 0, Phases 2, 3, 4, and 5 run on the working task set above. Phase 1 does not run.

## Phase 1: Discover finished runs [HARD STOP]

**First action, before anything else:**

```bash
ls .aisdlc/tasks/
```

If the directory is absent or empty, print `no finished runs since <date>` and stop.

For each subdirectory, read `.aisdlc/tasks/<id>/task.json`. Keep only tasks where both:
- `.status` is `"done"` or `"failed"`, **and**
- `.updated` ≥ `<since-date>` (ISO-8601 compare: `"2026-09-01T00:00:00Z"`).

```bash
jq -r 'select((.status == "done" or .status == "failed") and .updated >= "<since-date>") | .id' \
  .aisdlc/tasks/*/task.json
```

If zero tasks remain, print `no finished runs since <date>` and stop. (UC-6)

---

## Phase 2: Classify [UC-1]

Apply these rules top-to-bottom to every filtered task; first match wins.

| Class | jq filter on `task.json` | Extra check |
|---|---|---|
| `blocked` | `.status == "failed" and (.error // "" \| test("BLOCKED"))` | — |
| `failed` | `.status == "failed"` | — |
| `gaps` | `.status == "done"` | `grep -m1 '^Verdict:' .aisdlc/tasks/<id>/qa-report.md` returns `Verdict: GAPS` |
| `review-loop` | `.status == "done"` | **get-pr** from tracker has `.reviews \| length >= 2`; `n/a` if tracker `none` or call fails (UC-4) |
| `retried` | `.status == "done" and .attempts > 1` | — |
| `clean` | `.status == "done"` | — |

For `review-loop` on a `local` tracker: read `.aisdlc/tracker/prs.jsonl`, extract the PR
number from `.pr_url` (`/pull/([0-9]+)` or local `#([0-9]+)`), then:

```bash
jq -r --arg n "<pr#>" 'select(.number == ($n|tonumber)) | .reviews | length' \
  .aisdlc/tracker/prs.jsonl
```

If the tracker is `none`, `local` with missing `prs.jsonl`, or any call fails: mark
`review-loop` counts as `n/a` and print one line:
`review-loop count unavailable — tracker is <kind> or unreachable`. (UC-4)

Print: `ID | class`. One row per task.

---

## Phase 3: Cause ranking [UC-2]

Sum `cost_usd` and wall-clock seconds (`updated − created`) per class. Tasks billed under
a Claude Pro/Max subscription have `cost_usd: null` — they carry no cost data (the CLI
reports no per-token pricing on a subscription plan). Exclude null-cost tasks from cost
averages; render their cost column as `n/a`.

Use the Phase 2 classification (not raw `.status`) for grouping. Sort rows by `cost_usd`
descending. Print:

| class | count | share% | total_cost_usd | wall_min | harness file |
|---|---|---|---|---|---|

Harness file per class (from `harness-eval` § "Diagnosing a failure"):

| Class | Harness file |
|---|---|
| `blocked` | `spec-authoring` |
| `gaps` | `spec-authoring` |
| `review-loop` | playbook |
| `retried` | playbook |
| `failed` | `task-router` |
| `clean` | — |

---

## Phase 4: Metrics [UC-3]

Compute from `task.json` files only. Read `BLOCKED.md` for the top-three blocked tasks; the
cause is its `**Stopped at:**` line — the first line is always the `# BLOCKED — <TICKET>` heading
(archive: `<path>/spec/BLOCKED.md` from Phase 0 step 6; live: `grep -m1 '^\*\*Stopped at:\*\*' specs/<ticket>/BLOCKED.md`).

```
$ per merged PR:    <sum cost_usd over merged done tasks with non-null cost> ÷ their count
                    archive: "merged" = Phase 0 step 7 result; live: done with pr_url non-null
                    (print "n/a" when no merged tasks have non-null cost_usd)
First-pass PASS %:  <clean count> / <total finished> × 100
BLOCKED rate %:     <blocked count> / <total finished> × 100
  Top causes:       <`**Stopped at:**` line of BLOCKED.md for the 3 highest-cost blocked tasks>
Generated / merged: <total finished> / <merged count (archive: verified; live: pr_url non-null)>
```

In live mode, if the tracker is `local` or unreachable, print `n/a` for the merge denominator and the
review-loop count, and add one line:
`merge ratio and review-loop count unavailable — tracker is local or unreachable`. (UC-4)

Report is ≤ 60 lines total across Phases 2–4.

---

## Phase 5: Issue handoff [UC-5]

Identify the highest-cost non-`clean` class from Phase 3 (first row). Ask exactly once:

```
File an issue for the top cause (<class>, $<cost>, harness: <file>)? [y/N]
```

**On `N` or no input:** stop; write nothing.

**On `Y`:** invoke `/sdlc:issue` via the `SlashCommand` tool. If `SlashCommand` is
unavailable, read `${CLAUDE_PLUGIN_ROOT}/commands/issue.md` and follow it verbatim. Pass
outputs from this retro in a block headed `— PREVIOUS STEP (/sdlc:retro) said —`.

Issue body to supply:

```
Cause: <class>
Evidence: tasks <id1> <id2> … · total $<cost> · <count> runs
Symptom: <matching row text from harness-eval § "Diagnosing a failure">
Harness file: <file>
```

End the retro report with the chain marker exactly:

```
Issue: #<n> (<url>)
```

---

## Not to be confused with

- **`/sdlc:harness-eval`** — runs model × scenario evals against the sandbox fixture to
  measure a single harness change. `retro` reads production run history to find which
  change to make next.
- **`aisdlc status`** — shows the live queue and current task states; `retro` reads only
  completed runs.
- **`/sdlc:autopilot`** — diagnoses a single in-flight PR; `retro` looks back across all
  finished tasks.
