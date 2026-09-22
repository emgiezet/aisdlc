---
description: Classify finished aisdlc runs by failure cause, rank costs by class, print pipeline metrics, and hand the top cause to /sdlc:issue. Use after any batch of pipeline runs to find which harness file to fix next.
allowed-tools: Bash, Read, Grep, Glob, SlashCommand
---

# /sdlc:retro

Reads `.aisdlc/tasks/` and produces a ranked defect report: every finished task classified,
costs summed by class, pipeline metrics printed as numbers, then one optional issue filed.
Never edits `task.json` or any harness file.

`$ARGUMENTS`: `[--since <YYYY-MM-DD>] [--repo <path>]`

`--since` defaults to 30 days ago (`date -d '-30 days' +%Y-%m-%d` or equivalent).
`--repo` defaults to the current directory. All paths below are relative to `<repo>`.

Read `.claude/sdlc.md` for the **Tracker descriptor**. Execute tracker operations through
the descriptor file; never substitute bare CLI calls.

---

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

Sum `cost_usd` and wall-clock seconds (`updated − created`) per class:

```bash
jq -rn --arg since "<since-date>" '
  [inputs | select((.status == "done" or .status == "failed") and .updated >= $since)
          | {id, status, cost: (.cost_usd // 0),
             wall: ((.updated | fromdateiso8601) - (.created | fromdateiso8601)),
             attempts, error, pr_url}]
  | group_by(.status)   # replace with your class labels in memory
  | .[]
  | {class: .[0].status, count: length,
     cost:  (map(.cost) | add),
     wall:  (map(.wall) | add)}
  | [.class, .count, .cost, .wall] | @tsv
' .aisdlc/tasks/*/task.json
```

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

Compute from `task.json` files only. Read `BLOCKED.md` for the top-three blocked tasks to
extract the first line of each (`head -1 specs/<ticket>/BLOCKED.md` in the task's repo).

```
$ per merged PR:    <sum cost_usd where status=done> / <count where status=done and pr_url non-null>
First-pass PASS %:  <clean count> / <total finished> × 100
BLOCKED rate %:     <blocked count> / <total finished> × 100
  Top causes:       <first line of BLOCKED.md for the 3 highest-cost blocked tasks>
Generated / merged: <total finished> / <done with pr_url non-null>
```

If the tracker is `local` or unreachable, print `n/a` for the merge denominator and the
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
