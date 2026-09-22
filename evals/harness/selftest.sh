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
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
rm -rf "$WORK"
