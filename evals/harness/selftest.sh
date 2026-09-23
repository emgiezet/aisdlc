#!/usr/bin/env bash
# selftest.sh — verifies the aisdlc runner against stub-claude. No API calls, no cost.
#
# Covers the runner's contract, not the agents' output: phase sequencing, the spec gate,
# no-op detection, failure retention, and artifact collection. Every case here exists because
# it broke once.
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "${HARNESS_DIR}/../.." && pwd)"
AISDLC="${REPO_ROOT}/plugins/sdlc/bin/aisdlc"
WORK="${TMPDIR:-/tmp}/aisdlc-selftest"
STUB_DIR="$WORK/bin"

PASS=0
FAIL=0
ok()   { printf '  ok    %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  FAIL  %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

fresh_repo() {
    local dir="$1" status="${2:-approved}"
    rm -rf "$dir"
    mkdir -p "$dir/specs/SBX-1"
    git -C "$dir" init -q -b master
    git -C "$dir" config user.email selftest@localhost
    git -C "$dir" config user.name selftest
    {
        echo "---"
        echo "ticket: SBX-1"
        echo "title: Selftest spec"
        echo "status: $status"
        echo "---"
        echo
        echo "| id | actor | action | expected observable result | test |"
        echo "|----|-------|--------|----------------------------|------|"
        echo "| UC-1 | caller | calls Stub() | returns a non-empty string | unit |"
    } > "$dir/specs/SBX-1/spec.md"
    git -C "$dir" add -A
    git -C "$dir" commit -q -m "chore: selftest baseline"
    git -C "$dir" update-ref refs/remotes/origin/master HEAD
}

task_field() {
    local dir="$1" field="$2" f
    f="$(ls -1 "$dir"/.aisdlc/tasks/*/task.json 2>/dev/null | head -1)"
    [ -n "$f" ] && jq -r "$field // empty" "$f"
}

rm -rf "$WORK"
mkdir -p "$STUB_DIR"
ln -sf "$HARNESS_DIR/stub-claude" "$STUB_DIR/claude"
export PATH="$STUB_DIR:$PATH"

printf 'aisdlc runner selftest (stub claude, no API calls)\n\n'

# --------------------------------------------------------------------------- #
printf 'every requested phase runs, in order\n'
R="$WORK/phases"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "done" ] && ok "status is done" || bad "status" "$(task_field "$R" .status)"
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ -f "$D/implement.log" ] && ok "implement ran" || bad "implement" "no implement.log"
# The regression that motivated this file: claude consumes stdin, which used to eat the
# phase loop's own input so only the first phase ever ran.
[ -f "$D/qa.log" ] && ok "qa ran too (stdin not swallowed)" || bad "qa" "no qa.log — the phase loop lost its input"
[ -f "$D/qa-report.md" ] && ok "qa report collected" || bad "artifacts" "qa-report.md not copied out"
[ -s "$D/changes.diff" ] && ok "diff collected" || bad "artifacts" "changes.diff empty"

# --------------------------------------------------------------------------- #
printf '\na phase that never ran is a failure, not a success\n'
R="$WORK/noop"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_STUB=noop "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "failed" ] && ok "0-turn phase marked failed" \
    || bad "no-op detection" "status is $(task_field "$R" .status), expected failed"

# --------------------------------------------------------------------------- #
printf '\na blocked implementation keeps its evidence\n'
R="$WORK/blocked"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_STUB=blocked "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "failed" ] && ok "status is failed" || bad "status" "$(task_field "$R" .status)"
WT="$(task_field "$R" .worktree)"
[ -n "$WT" ] && [ -d "$WT" ] && ok "worktree kept for inspection" || bad "worktree" "removed on failure"
[ -f "$WT/specs/SBX-1/BLOCKED.md" ] && ok "BLOCKED.md present" || bad "BLOCKED.md" "missing"
case "$(task_field "$R" .error)" in *BLOCKED*) ok "error mentions BLOCKED.md" ;; *) bad "error" "$(task_field "$R" .error)" ;; esac
"$AISDLC" retry "$(task_field "$R" .id)" --repo "$R" >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "queued" ] && ok "retry re-queues and clears the worktree" \
    || bad "retry" "status is $(task_field "$R" .status)"

# --------------------------------------------------------------------------- #
printf '\nthe spec gate refuses before spending anything\n'
R="$WORK/draft"
fresh_repo "$R" draft
if "$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1; then
    bad "draft spec" "add accepted a draft spec"
else
    ok "add refuses a draft spec"
fi
"$AISDLC" add SBX-1 --repo "$R" --no-pr --force >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "refused" ] && ok "worktree gate refuses it even with --force" \
    || bad "worktree gate" "status is $(task_field "$R" .status)"
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ ! -f "$D/implement.json" ] && ok "model was never invoked" || bad "gate" "implement.json exists — a model ran"

# --------------------------------------------------------------------------- #
printf '\nthe target repo never looks dirty\n'
R="$WORK/clean"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
[ -z "$(git -C "$R" status --porcelain)" ] && ok ".aisdlc/ excluded from git" \
    || bad "cleanliness" "$(git -C "$R" status --porcelain | head -1)"

# --------------------------------------------------------------------------- #
printf '\nparallel workers drain the queue exactly once\n'
R="$WORK/parallel"
fresh_repo "$R"
for n in 2 3 4; do
    cp -R "$R/specs/SBX-1" "$R/specs/SBX-$n"
    sed -i "s/SBX-1/SBX-$n/" "$R/specs/SBX-$n/spec.md"
done
git -C "$R" add -A >/dev/null
git -C "$R" commit -q -m "chore: more specs"
git -C "$R" update-ref refs/remotes/origin/master HEAD
for n in 1 2 3 4; do "$AISDLC" add "SBX-$n" --repo "$R" --no-pr >/dev/null 2>&1; done
"$AISDLC" run --repo "$R" --workers 3 >/dev/null 2>&1
done_count="$(jq -sr '[.[] | select(.status == "done")] | length' "$R"/.aisdlc/tasks/*/task.json)"
[ "$done_count" -eq 4 ] && ok "all 4 tasks done, none run twice" || bad "parallel" "$done_count of 4 done"
[ "$(wc -l < "$R/.aisdlc/queue.jsonl" | tr -d ' ')" -eq 0 ] && ok "queue drained" || bad "queue" "not empty"

# --------------------------------------------------------------------------- #
printf '\nthe queue tells hooks there is nobody to ask\n'
grep -q 'AISDLC_HEADLESS=1' "$REPO_ROOT/plugins/sdlc/bin/aisdlc" \
    && ok "invoke_claude exports AISDLC_HEADLESS" \
    || bad "headless marker" "hooks cannot tell a queued phase from an interactive session"

# --------------------------------------------------------------------------- #
printf '\nreview phase runs after ship with the PR number\n'
R="$WORK/review-phase"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ -f "${D}review.log" ] && ok "review.log exists" || bad "review phase" "no review.log"
grep -qE '/(sdlc:)?review 7 --autofix' "${D}review.log" 2>/dev/null \
    && ok "review prompt contains PR number 7" \
    || bad "review prompt" "PR number missing in review.log"

# --------------------------------------------------------------------------- #
printf '\n--no-pr strips ship and review\n'
R="$WORK/no-pr"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .status)" = "done" ] && ok "--no-pr task done" \
    || bad "--no-pr status" "status is $(task_field "$R" .status)"
[ ! -f "${D}ship.log" ] && ok "ship phase absent" || bad "--no-pr" "ship.log exists"
[ ! -f "${D}review.log" ] && ok "review phase absent" || bad "--no-pr" "review.log exists"

# --------------------------------------------------------------------------- #
printf '\nadd --issue claims once and refuses twice\n'
R="$WORK/issue-claim"
fresh_repo "$R"
mkdir -p "$R/.aisdlc/tracker/issues"
cat > "$R/.aisdlc/tracker/issues/42.md" <<'ISSUE'
---
number: 42
title: selftest bug
state: open
labels: [bug]
assignees: []
author: selftest
created: 2026-09-22T00:00:00Z
---
Test bug.

## Comments
ISSUE
mkdir -p "$R/.claude"
cat > "$R/.claude/sdlc.md" <<'SDLC'
## Issue tracker
- **Tracker descriptor:** `.claude/trackers/local.md`
SDLC
"$AISDLC" add --issue 42 --repo "$R" >/dev/null 2>&1 \
    && ok "first add --issue 42 succeeds" \
    || bad "issue claim" "first add --issue failed"
grep -q 'in-progress' "$R/.aisdlc/tracker/issues/42.md" \
    && ok "issue has in-progress label" \
    || bad "claim" "in-progress not in labels after claim"
grep -q $'\360\237\244\226' "$R/.aisdlc/tracker/issues/42.md" \
    && ok "claim comment appended" \
    || bad "claim comment" "no robot comment in issue file"
"$AISDLC" add --issue 42 --repo "$R" >/dev/null 2>&1 \
    && bad "double claim" "second add --issue 42 should have failed" \
    || ok "second add --issue 42 refused: already claimed"

# --------------------------------------------------------------------------- #
printf '\nbugfix spec passes the gate only while the issue is labelled bug\n'
R="$WORK/bugfix-gate-ok"
fresh_repo "$R"
cat > "$R/specs/SBX-1/spec.md" <<'BFSPEC'
---
ticket: SBX-1
kind: bugfix
status: approved
approved-by: issue #42 (label bug, @selftest)
---

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | caller | calls Stub() | returns a non-empty string | unit |
BFSPEC
git -C "$R" add -A >/dev/null
git -C "$R" commit -q -m "bugfix spec"
git -C "$R" update-ref refs/remotes/origin/master HEAD
mkdir -p "$R/.aisdlc/tracker/issues"
cat > "$R/.aisdlc/tracker/issues/42.md" <<'ISSUE'
---
number: 42
title: selftest bug
state: open
labels: [bug]
assignees: []
author: selftest
created: 2026-09-22T00:00:00Z
---
Test bug.

## Comments
ISSUE
mkdir -p "$R/.claude"
cat > "$R/.claude/sdlc.md" <<'SDLC'
## Issue tracker
- **Tracker descriptor:** `.claude/trackers/local.md`
SDLC
"$AISDLC" add SBX-1 --repo "$R" >/dev/null 2>&1 \
    && ok "bugfix spec passes gate with bug label" \
    || bad "bugfix gate" "add refused with bug label present"
# Same spec, issue without bug label — gate must refuse.
R="$WORK/bugfix-gate-no-label"
fresh_repo "$R"
cat > "$R/specs/SBX-1/spec.md" <<'BFSPEC'
---
ticket: SBX-1
kind: bugfix
status: approved
approved-by: issue #42 (label bug, @selftest)
---

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | caller | calls Stub() | returns a non-empty string | unit |
BFSPEC
git -C "$R" add -A >/dev/null
git -C "$R" commit -q -m "bugfix spec"
git -C "$R" update-ref refs/remotes/origin/master HEAD
mkdir -p "$R/.aisdlc/tracker/issues"
cat > "$R/.aisdlc/tracker/issues/42.md" <<'ISSUE'
---
number: 42
title: selftest bug
state: open
labels: []
assignees: []
author: selftest
created: 2026-09-22T00:00:00Z
---
Test bug (no bug label).

## Comments
ISSUE
mkdir -p "$R/.claude"
cat > "$R/.claude/sdlc.md" <<'SDLC'
## Issue tracker
- **Tracker descriptor:** `.claude/trackers/local.md`
SDLC
"$AISDLC" add SBX-1 --repo "$R" >/dev/null 2>&1 \
    && bad "bugfix gate" "add should refuse without bug label" \
    || ok "bugfix spec refused without bug label"

# --------------------------------------------------------------------------- #
printf '\nartifacts_exist scorer uses real score() from run.sh\n'
declare -i A_PASS=0 A_FAIL=0
assert_ok()   { A_PASS+=1; }
assert_fail() { A_FAIL+=1; }
_SCORE_TMP="$WORK/score_fn.sh"
awk '/^score\(\) \{$/{f=1} f{print} /^}$/ && f{f=0; exit}' \
    "$HARNESS_DIR/run.sh" > "$_SCORE_TMP"
# shellcheck source=/dev/null
. "$_SCORE_TMP"
_SBOX="$WORK/scorer-sandbox"
mkdir -p "$_SBOX"
git -C "$_SBOX" init -q -b master
git -C "$_SBOX" config user.email score@localhost
git -C "$_SBOX" config user.name score
touch "$_SBOX/.keep"
git -C "$_SBOX" add -A
git -C "$_SBOX" commit -q -m "init"
_SBASE="$(git -C "$_SBOX" rev-parse HEAD)"
_SSCEN="$WORK/scorer-scen.json"
printf '{"assert":{"artifacts_exist":["specs/SBX-4/qa/UC-1.png"]}}\n' > "$_SSCEN"
# absent → score must record a failure
A_PASS=0; A_FAIL=0
score "$_SBOX" "$_SSCEN" "SBX-4" "$_SBASE" >/dev/null 2>&1
[ "$A_FAIL" -gt 0 ] \
    && ok "absent artifact: score() records a failure" \
    || bad "artifacts_exist absent" "score() did not flag missing artifact"
# present non-empty → score must pass
mkdir -p "$_SBOX/specs/SBX-4/qa"
printf 'PNG' > "$_SBOX/specs/SBX-4/qa/UC-1.png"
A_PASS=0; A_FAIL=0
score "$_SBOX" "$_SSCEN" "SBX-4" "$_SBASE" >/dev/null 2>&1
[ "$A_FAIL" -eq 0 ] \
    && ok "present artifact: score() records a pass" \
    || bad "artifacts_exist present" "score() flagged a present artifact as missing"
unset _SCORE_TMP _SBOX _SBASE _SSCEN
# --------------------------------------------------------------------------- #
printf '\nclaim failure: die and create no task\n'
R="$WORK/issue-claim-fail"
fresh_repo "$R"
mkdir -p "$R/.aisdlc/tracker/issues"
mkdir -p "$R/.claude"
cat > "$R/.claude/sdlc.md" <<'SDLC'
## Issue tracker
- **Tracker descriptor:** `.claude/trackers/local.md`
SDLC
"$AISDLC" add --issue 99 --repo "$R" >/dev/null 2>&1 \
    && bad "claim failure" "add should have failed when claim cannot be established" \
    || ok "add --issue fails when claim fails"
task_count="$(find "$R/.aisdlc/tasks" -name 'task.json' 2>/dev/null | wc -l | tr -d ' ')"
[ "${task_count:-0}" -eq 0 ] \
    && ok "no task created after failed claim" \
    || bad "claim failure" "${task_count} task(s) created after failed claim"
# --------------------------------------------------------------------------- #
printf '\nissue released after ship, prs.jsonl created\n'
R="$WORK/issue-handoff"
fresh_repo "$R"
mkdir -p "$R/.aisdlc/tracker/issues"
cat > "$R/.aisdlc/tracker/issues/42.md" <<'ISSUE'
---
number: 42
title: selftest bug
state: open
labels: [bug]
assignees: []
author: selftest
created: 2026-09-22T00:00:00Z
---
Test bug.

## Comments
ISSUE
mkdir -p "$R/.claude"
cat > "$R/.claude/sdlc.md" <<'SDLC'
## Issue tracker
- **Tracker descriptor:** `.claude/trackers/local.md`
SDLC
"$AISDLC" add --issue 42 --repo "$R" >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
grep -q 'handed off to PR #7' "$R/.aisdlc/tracker/issues/42.md" \
    && ok "issue released with 'handed off to PR #7'" \
    || bad "issue handoff" "$(grep 'completed\|handed\|aborted' \
       "$R/.aisdlc/tracker/issues/42.md" 2>/dev/null | head -1 || echo 'no release comment')"
[ -f "$R/.aisdlc/tracker/prs.jsonl" ] \
    && ok "prs.jsonl created after PR claim" \
    || bad "PR claim" "prs.jsonl not created"
# The hand-off is a real lock swap: exactly one PR record, released (no in-progress) once review passed.
[ "$(jq -s 'map(select(.number == 7)) | length' "$R/.aisdlc/tracker/prs.jsonl" 2>/dev/null)" = "1" ] \
    && ok "one PR record for #7, not a duplicate" \
    || bad "PR record" "expected one record for PR 7"
jq -e 'select(.number == 7) | (.labels | index("in-progress")) == null and (.reviews | map(.verdict) | index("APPROVED"))' \
    "$R/.aisdlc/tracker/prs.jsonl" >/dev/null 2>&1 \
    && ok "PR lock released with APPROVED after review" \
    || bad "PR release" "$(jq -c 'select(.number == 7) | {labels, reviews}' "$R/.aisdlc/tracker/prs.jsonl" 2>/dev/null)"
# --------------------------------------------------------------------------- #
printf '\nissue released aborted when a phase fails\n'
R="$WORK/issue-abort"
fresh_repo "$R"
mkdir -p "$R/.aisdlc/tracker/issues"
cat > "$R/.aisdlc/tracker/issues/42.md" <<'ISSUE'
---
number: 42
title: selftest bug
state: open
labels: [bug]
assignees: []
author: selftest
created: 2026-09-22T00:00:00Z
---
Test bug.

## Comments
ISSUE
mkdir -p "$R/.claude"
cat > "$R/.claude/sdlc.md" <<'SDLC'
## Issue tracker
- **Tracker descriptor:** `.claude/trackers/local.md`
SDLC
"$AISDLC" add --issue 42 --repo "$R" >/dev/null 2>&1
AISDLC_STUB=blocked "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
grep -qE 'aborted:' "$R/.aisdlc/tracker/issues/42.md" \
    && ok "issue released with aborted: when a phase fails" \
    || bad "issue abort" "$(grep 'completed\|handed\|aborted' \
       "$R/.aisdlc/tracker/issues/42.md" 2>/dev/null | head -1 || echo 'no release comment')"

# --------------------------------------------------------------------------- #
printf '\ncancel gives a queued issue claim back; retry takes it again\n'
R="$WORK/issue-cancel"
fresh_repo "$R"
mkdir -p "$R/.aisdlc/tracker/issues" "$R/.claude"
cat > "$R/.aisdlc/tracker/issues/42.md" <<'ISSUE'
---
number: 42
title: selftest bug
state: open
labels: [bug]
assignees: []
author: selftest
created: 2026-09-22T00:00:00Z
---
Test bug.

## Comments
ISSUE
printf -- '- **Tracker descriptor:** `.claude/trackers/local.md`\n' > "$R/.claude/sdlc.md"
"$AISDLC" add --issue 42 --repo "$R" >/dev/null 2>&1
ID="$(ls -1 "$R/.aisdlc/tasks" | head -1)"
"$AISDLC" cancel "$ID" --repo "$R" >/dev/null 2>&1
grep -qE '^labels:.*in-progress' "$R/.aisdlc/tracker/issues/42.md" \
    && bad "cancel release" "in-progress still on the issue after cancel" \
    || ok "cancel released the issue claim"
"$AISDLC" retry "$ID" --repo "$R" >/dev/null 2>&1 \
    && ok "retry re-queued the cancelled issue task" \
    || bad "retry" "retry failed"
grep -qE '^labels:.*in-progress' "$R/.aisdlc/tracker/issues/42.md" \
    && ok "retry re-claimed the issue" \
    || bad "retry claim" "no in-progress after retry"

# --------------------------------------------------------------------------- #
# scope-check tests — use the existing stub (ok mode) so implement and qa run
# normally; scope verdict depends solely on the spec's In:/Out: and .claude/sdlc.md
# --------------------------------------------------------------------------- #

fresh_repo_scope() {
    local dir="$1" in_section="$2" out_section="$3" oob="${4:-}"
    fresh_repo "$dir"
    # Overwrite the minimal spec with one that has In:/Out: sections.
    cat > "$dir/specs/SBX-1/spec.md" <<SCOPE_SPEC
---
ticket: SBX-1
title: Selftest scope spec
status: approved
---

## Scope

In:
${in_section}

Out:
${out_section}

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | caller | calls Stub() | returns a non-empty string | unit |
SCOPE_SPEC
    mkdir -p "$dir/.claude"
    printf '## Repo-wide out of bounds\n%s\n' "$oob" > "$dir/.claude/sdlc.md"
    git -C "$dir" add -A
    git -C "$dir" commit -q -m "chore: scope selftest spec"
    git -C "$dir" update-ref refs/remotes/origin/master HEAD
}

# The stub (ok mode) commits: pkg/stub.go, pkg/stub_test.go, specs/SBX-1/qa-report.md

# --------------------------------------------------------------------------- #
printf '\nscope-check: all changed files in scope → PASS\n'
R="$WORK/scope-pass"
# In: covers both pkg/ and specs/SBX-1/ — every file the stub commits is in scope.
fresh_repo_scope "$R" \
    $'- `pkg/`\n- `specs/SBX-1/`' \
    "" \
    ""
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .status)" = "done" ] \
    && ok "scope PASS: task done" \
    || bad "scope PASS status" "$(task_field "$R" .status)"
[ -f "${D}scope-report.md" ] \
    && ok "scope PASS: scope-report.md collected" \
    || bad "scope PASS artifacts" "scope-report.md missing from task dir"
grep -q 'Verdict: PASS' "${D}scope-report.md" 2>/dev/null \
    && ok "scope PASS: verdict is PASS" \
    || bad "scope PASS verdict" "$(grep 'Verdict:' "${D}scope-report.md" 2>/dev/null || echo 'no Verdict line')"
[ "$(task_field "$R" .scope_verdict)" = "PASS" ] \
    && ok "scope PASS: scope_verdict in task.json" \
    || bad "scope_verdict" "$(task_field "$R" .scope_verdict)"

# --------------------------------------------------------------------------- #
printf '\nscope-check: undeclared changed file → GAPS, chain continues\n'
R="$WORK/scope-gaps"
# In: covers only pkg/ — specs/SBX-1/qa-report.md (committed by stub qa) is undeclared.
fresh_repo_scope "$R" \
    $'- `pkg/`' \
    "" \
    ""
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .status)" = "done" ] \
    && ok "scope GAPS: task still done (GAPS does not stop the chain)" \
    || bad "scope GAPS status" "$(task_field "$R" .status)"
grep -q 'Verdict: GAPS' "${D}scope-report.md" 2>/dev/null \
    && ok "scope GAPS: verdict is GAPS" \
    || bad "scope GAPS verdict" "$(grep 'Verdict:' "${D}scope-report.md" 2>/dev/null || echo 'no Verdict line')"
grep -qF '**undeclared**' "${D}scope-report.md" 2>/dev/null \
    && ok "scope GAPS: undeclared files listed in report" \
    || bad "scope GAPS report" "no **undeclared** entry found"
[ "$(task_field "$R" .scope_verdict)" = "GAPS" ] \
    && ok "scope GAPS: scope_verdict in task.json" \
    || bad "scope_verdict GAPS" "$(task_field "$R" .scope_verdict)"

# --------------------------------------------------------------------------- #
printf '\nscope-check: repo-wide prohibition hit → BLOCKED, chain stops before ship\n'
R="$WORK/scope-blocked"
# In: covers only pkg/. Repo-wide prohibition lists specs/SBX-1/qa-report.md (committed
# by stub qa). ship must NOT run; task must be failed.
fresh_repo_scope "$R" \
    $'- `pkg/`' \
    "" \
    $'- `specs/SBX-1/qa-report.md`'
"$AISDLC" add SBX-1 --repo "$R" >/dev/null 2>&1   # full pipeline (includes ship+review)
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .status)" = "failed" ] \
    && ok "scope BLOCKED: task failed" \
    || bad "scope BLOCKED status" "$(task_field "$R" .status)"
grep -q 'Verdict: BLOCKED' "${D}scope-report.md" 2>/dev/null \
    && ok "scope BLOCKED: verdict is BLOCKED" \
    || bad "scope BLOCKED verdict" "$(grep 'Verdict:' "${D}scope-report.md" 2>/dev/null || echo 'no Verdict line')"
[ ! -f "${D}ship.log" ] \
    && ok "scope BLOCKED: ship phase never ran" \
    || bad "scope BLOCKED chain" "ship.log exists — pipeline was not stopped"
grep -qF '**out of bounds**' "${D}scope-report.md" 2>/dev/null \
    && ok "scope BLOCKED: out-of-bounds file listed in report" \
    || bad "scope BLOCKED report" "no **out of bounds** entry found"
# --------------------------------------------------------------------------- #
# --------------------------------------------------------------------------- #
printf '\nbilling=subscription: null cost, no --max-budget-usd in args\n'
R="$WORK/billing-sub"
fresh_repo "$R"
mkdir -p "$R/.aisdlc"
printf '{"billing":"subscription"}\n' > "$R/.aisdlc/config.json"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "done" ] \
    && ok "billing=subscription: task done" \
    || bad "billing=subscription status" "$(task_field "$R" .status)"
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
_cost_raw="$(jq '.cost_usd' "$(ls "$R"/.aisdlc/tasks/*/task.json | head -1)")"
[ "$_cost_raw" = "null" ] \
    && ok "billing=subscription: cost_usd is null" \
    || bad "billing=subscription cost_usd" "expected null, got $_cost_raw"
# stub-claude writes its args to stderr, which invoke_claude appends to the phase log
! grep -q -- '--max-budget-usd' "${D}implement.log" \
    && ok "billing=subscription: --max-budget-usd absent from invoke" \
    || bad "billing=subscription args" "--max-budget-usd found in implement.log"
grep -q 'billing subscription' "${D}implement.log" \
    && ok "billing=subscription: mode logged in phase log" \
    || bad "billing=subscription log" "billing subscription not in implement.log"
# 0-turn failure path must still fire in subscription mode (billing must not weaken this gate)
R="$WORK/billing-sub-noop"
fresh_repo "$R"
mkdir -p "$R/.aisdlc"
printf '{"billing":"subscription"}\n' > "$R/.aisdlc/config.json"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_STUB=noop "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "failed" ] \
    && ok "billing=subscription: 0-turn phase still a hard failure" \
    || bad "billing=subscription 0-turn" "status $(task_field "$R" .status), expected failed"
# --------------------------------------------------------------------------- #
printf '\nbilling=api (default): numeric cost, --max-budget-usd present\n'
R="$WORK/billing-api"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "done" ] \
    && ok "billing=api: task done" \
    || bad "billing=api status" "$(task_field "$R" .status)"
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
_cost_raw="$(jq '.cost_usd' "$(ls "$R"/.aisdlc/tasks/*/task.json | head -1)")"
[ "$_cost_raw" != "null" ] && [ -n "$_cost_raw" ] \
    && ok "billing=api: cost_usd is numeric ($_cost_raw)" \
    || bad "billing=api cost_usd" "expected numeric, got $_cost_raw"
grep -q -- '--max-budget-usd' "${D}implement.log" \
    && ok "billing=api: --max-budget-usd present in invoke" \
    || bad "billing=api args" "--max-budget-usd absent from implement.log"
unset _cost_raw

# --------------------------------------------------------------------------- #
printf '\nmodel_roles absent: no models key, log headers unchanged (UC-1)\n'
R="$WORK/mr-uc1"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --model sonnet --no-pr >/dev/null 2>&1
TF="$(ls -1 "$R"/.aisdlc/tasks/*/task.json 2>/dev/null | head -1)"
[ "$(jq -r '.model' "$TF")" = "sonnet" ] \
    && ok "UC-1: model=sonnet in task.json" \
    || bad "UC-1 model" "$(jq -r '.model' "$TF")"
[ "$(jq 'has("models")' "$TF")" = "false" ] \
    && ok "UC-1: no models key when model_roles absent" \
    || bad "UC-1 models key" "unexpected models: $(jq '.models' "$TF")"
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
grep -q '(model sonnet' "${D}implement.log" 2>/dev/null \
    && ok "UC-1: implement.log header shows sonnet" \
    || bad "UC-1 log header" "$(grep '(model' "${D}implement.log" 2>/dev/null | head -1)"

# --------------------------------------------------------------------------- #
printf '\nmodel_roles full: models key maps every phase (UC-2)\n'
R="$WORK/mr-uc2"
fresh_repo "$R"
mkdir -p "$R/.aisdlc"
printf '{"model_roles":{"smol":"haiku","slow":"opus"}}\n' > "$R/.aisdlc/config.json"
"$AISDLC" add SBX-1 --repo "$R" --model sonnet >/dev/null 2>&1
TF="$(ls -1 "$R"/.aisdlc/tasks/*/task.json 2>/dev/null | head -1)"
[ "$(jq 'has("models")' "$TF")" = "true" ] \
    && ok "UC-2: models key present" \
    || bad "UC-2 models key" "no models key in task.json"
[ "$(jq -r '.models["scope-check"]' "$TF")" = "haiku" ] \
    && ok "UC-2: scope-check → haiku (smol role)" \
    || bad "UC-2 scope-check" "$(jq -r '.models["scope-check"]' "$TF")"
[ "$(jq -r '.models.ship' "$TF")" = "haiku" ] \
    && ok "UC-2: ship → haiku (smol role)" \
    || bad "UC-2 ship" "$(jq -r '.models.ship' "$TF")"
[ "$(jq -r '.models.review' "$TF")" = "opus" ] \
    && ok "UC-2: review → opus (slow role)" \
    || bad "UC-2 review" "$(jq -r '.models.review' "$TF")"
[ "$(jq -r '.models.implement' "$TF")" = "sonnet" ] \
    && ok "UC-2: implement → sonnet (default role falls back)" \
    || bad "UC-2 implement" "$(jq -r '.models.implement' "$TF")"
[ "$(jq -r '.models.qa' "$TF")" = "sonnet" ] \
    && ok "UC-2: qa → sonnet (default role falls back)" \
    || bad "UC-2 qa" "$(jq -r '.models.qa' "$TF")"

# --------------------------------------------------------------------------- #
printf '\nmodel_roles: run_phase routes each phase to its model (UC-3)\n'
R="$WORK/mr-uc3"
fresh_repo "$R"
mkdir -p "$R/.aisdlc"
printf '{"model_roles":{"smol":"haiku","slow":"opus"}}\n' > "$R/.aisdlc/config.json"
"$AISDLC" add SBX-1 --repo "$R" --model sonnet >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
grep -q '(model haiku' "${D}ship.log" 2>/dev/null \
    && ok "UC-3: ship.log header shows haiku" \
    || bad "UC-3 ship model" "$(grep '(model' "${D}ship.log" 2>/dev/null | head -1)"
grep -q '(model opus' "${D}review.log" 2>/dev/null \
    && ok "UC-3: review.log header shows opus" \
    || bad "UC-3 review model" "$(grep '(model' "${D}review.log" 2>/dev/null | head -1)"
grep -q '(model sonnet' "${D}implement.log" 2>/dev/null \
    && ok "UC-3: implement.log header shows sonnet" \
    || bad "UC-3 implement model" "$(grep '(model' "${D}implement.log" 2>/dev/null | head -1)"

# --------------------------------------------------------------------------- #
printf '\nmodel_roles partial: missing roles fall back to task model (UC-4)\n'
R="$WORK/mr-uc4"
fresh_repo "$R"
mkdir -p "$R/.aisdlc"
printf '{"model_roles":{"smol":"haiku"}}\n' > "$R/.aisdlc/config.json"
"$AISDLC" add SBX-1 --repo "$R" --model sonnet --no-pr >/dev/null 2>&1
TF="$(ls -1 "$R"/.aisdlc/tasks/*/task.json 2>/dev/null | head -1)"
[ "$(jq 'has("models")' "$TF")" = "true" ] \
    && ok "UC-4: models key present with partial config" \
    || bad "UC-4 models key" "no models key"
[ "$(jq -r '.models["scope-check"]' "$TF")" = "haiku" ] \
    && ok "UC-4: scope-check → haiku (smol configured)" \
    || bad "UC-4 scope-check" "$(jq -r '.models["scope-check"]' "$TF")"
[ "$(jq -r '.models.implement' "$TF")" = "sonnet" ] \
    && ok "UC-4: implement → sonnet (default role not in config, falls back)" \
    || bad "UC-4 implement" "$(jq -r '.models.implement' "$TF")"
[ "$(jq -r '.models.qa' "$TF")" = "sonnet" ] \
    && ok "UC-4: qa → sonnet (default role not in config, falls back)" \
    || bad "UC-4 qa" "$(jq -r '.models.qa' "$TF")"
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "done" ] \
    && ok "UC-4: task completes without error on partial config" \
    || bad "UC-4 status" "$(task_field "$R" .status)"

# --------------------------------------------------------------------------- #
printf '\nmodel_roles snapshot: config edit after add does not affect queued task (UC-5)\n'
R="$WORK/mr-uc5"
fresh_repo "$R"
mkdir -p "$R/.aisdlc"
printf '{"model_roles":{"smol":"haiku","slow":"opus"}}\n' > "$R/.aisdlc/config.json"
"$AISDLC" add SBX-1 --repo "$R" --model sonnet >/dev/null 2>&1
# Edit config after add — snapshot in task.json must be used, not the new config
printf '{"model_roles":{"smol":"changed-model","slow":"another-model"}}\n' > "$R/.aisdlc/config.json"
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
grep -q '(model haiku' "${D}ship.log" 2>/dev/null \
    && ok "UC-5: ship uses snapshotted haiku, not changed-model" \
    || bad "UC-5 snapshot ship" "$(grep '(model' "${D}ship.log" 2>/dev/null | head -1)"
grep -q '(model opus' "${D}review.log" 2>/dev/null \
    && ok "UC-5: review uses snapshotted opus, not another-model" \
    || bad "UC-5 snapshot review" "$(grep '(model' "${D}review.log" 2>/dev/null | head -1)"

# --------------------------------------------------------------------------- #
printf '\naisdlc help documents model_roles (UC-6)\n'
HELP_OUT="$("$AISDLC" help 2>&1)"
printf '%s' "$HELP_OUT" | grep -q 'model_roles' \
    && ok "UC-6: help mentions model_roles" \
    || bad "UC-6 model_roles" "model_roles not found in help output"
printf '%s' "$HELP_OUT" | grep -q 'smol' \
    && ok "UC-6: help mentions smol role" \
    || bad "UC-6 smol" "smol not found in help output"
printf '%s' "$HELP_OUT" | grep -q 'slow' \
    && ok "UC-6: help mentions slow role" \
    || bad "UC-6 slow" "slow not found in help output"
printf '%s' "$HELP_OUT" | grep -qE 'scope-check.*ship|ship.*scope-check' \
    && ok "UC-6: help shows smol phases (scope-check, ship)" \
    || bad "UC-6 smol phases" "scope-check/ship not found together in help output"

# --------------------------------------------------------------------------- #
printf '\nPR claim lock survives a gh build where `gh pr edit` fails (SDLC-012)\n'
R="$WORK/pr-claim"
fresh_repo "$R"
git -C "$R" remote add origin git@github.com:acme/widget.git
ln -sf "$HARNESS_DIR/stub-gh" "$STUB_DIR/gh"
export STUB_GH_STATE="$WORK/gh-state.json" STUB_GH_LOG="$WORK/gh-calls.log" STUB_GH_USER="selftest-user"
rm -f "$STUB_GH_STATE" "$STUB_GH_LOG"

# The tracker helpers are internal, so drive them directly. `help` is the one argument that
# defines every function and exits zero without touching the queue.
# shellcheck source=/dev/null
( source "$AISDLC" help >/dev/null 2>&1; tracker_github_pr_claim "$R" 7 ) \
    && ok "claim succeeds while gh pr edit fails" \
    || bad "pr claim" "tracker_github_pr_claim returned non-zero"
jq -e '(.labels | index("in-progress")) and (.assignees | index("selftest-user"))' "$STUB_GH_STATE" >/dev/null \
    && ok "claim applied label and assignee" \
    || bad "pr claim state" "$(cat "$STUB_GH_STATE")"
grep -q 'gh pr edit' "$STUB_GH_LOG" \
    && bad "pr claim wire" "runner still calls gh pr edit" \
    || ok "claim never calls gh pr edit"

# Seed the label explicitly: an assertion that passes on an empty tracker proves nothing.
printf '{"labels":["ai-sdlc","in-progress"],"assignees":["selftest-user"]}\n' > "$STUB_GH_STATE"
# shellcheck source=/dev/null
( source "$AISDLC" help >/dev/null 2>&1; tracker_github_pr_release "$R" 7 APPROVED ) >/dev/null 2>&1
jq -e '(.labels | index("in-progress")) | not' "$STUB_GH_STATE" >/dev/null \
    && ok "release removed the in-progress label" \
    || bad "pr release" "label still set: $(cat "$STUB_GH_STATE")"
unset STUB_GH_STATE STUB_GH_LOG STUB_GH_USER
rm -f "$STUB_DIR/gh"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
rm -rf "$WORK"
