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
WORK="${AISDLC_SELFTEST_WORK:-$(mktemp -d "${TMPDIR:-/tmp}/aisdlc-selftest.XXXXXX")}"
STUB_DIR="$WORK/bin"

_selftest_cleanup() {
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        rm -rf "$WORK"
    else
        printf '\nscratch dir kept for inspection: %s\n' "$WORK" >&2
    fi
}
trap _selftest_cleanup EXIT

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
    # Create .claude/ so the policy edit test can detect modifications.
    mkdir -p "$dir/.claude/rules"
    printf '# test rule\n' > "$dir/.claude/rules/test.md"
    # A test that already exists on the base, so a branch deleting it can be caught.
    mkdir -p "$dir/legacy"
    printf 'package legacy\n\nimport "testing"\n\nfunc TestLegacy(t *testing.T) {}\n' > "$dir/legacy/old_test.go"
    git -C "$dir" add -A
    git -C "$dir" commit -q -m "chore: selftest baseline"
    git -C "$dir" update-ref refs/remotes/origin/master HEAD
    # verify fails closed without commands, so every fixture carries one that passes. Written
    # after the commit: .aisdlc/ is state, never part of the tree.
    mkdir -p "$dir/.aisdlc"
    printf '{"verify":["test -f pkg/stub_test.go"]}\n' > "$dir/.aisdlc/config.json"
}

task_field() {
    local dir="$1" field="$2" f
    f="$(ls -1 "$dir"/.aisdlc/tasks/*/task.json 2>/dev/null | head -1)"
    [ -n "$f" ] && jq -r "$field // empty" "$f"
}

if [ -n "${AISDLC_SELFTEST_WORK:-}" ]; then
    rm -rf "$WORK"
fi
mkdir -p "$STUB_DIR"
ln -sf "$HARNESS_DIR/stub-claude" "$STUB_DIR/claude"
ln -sf "$HARNESS_DIR/stub-omp" "$STUB_DIR/omp"
export PATH="$STUB_DIR:$PATH"

printf 'aisdlc runner selftest (stub claude and stub omp, no API calls)\n\n'

# --------------------------------------------------------------------------- #
printf 'every requested phase runs, in order (GH-52 UC-2)\n'
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
[ -f "$D/qa.json" ] && ok "GH-52 UC-2: qa result present" || bad "GH-52 UC-2 qa" "qa.json missing"
[ -f "$D/qa-report.md" ] && ok "qa report collected" || bad "artifacts" "qa-report.md not copied out"
[ -s "$D/changes.diff" ] && ok "diff collected" || bad "artifacts" "changes.diff empty"
head -1 "$D/verify-report.md" 2>/dev/null | grep -qx PASS && ok "verify ran and passed" \
    || bad "verify" "no PASS verify-report.md in the task dir"

# --------------------------------------------------------------------------- #
printf '\na phase that never ran is a failure, not a success\n'
R="$WORK/noop"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_STUB=noop "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "failed" ] && ok "0-turn phase marked failed" \
    || bad "no-op detection" "status is $(task_field "$R" .status), expected failed"

# --------------------------------------------------------------------------- #
printf '\nthe message-array output shape is read like the bare result object\n'
# Newer claude CLIs answer --output-format json with the whole message array. Read as an
# object it yields 0 turns, so a phase that in fact succeeded was reported as never having run.
R="$WORK/json-array"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_STUB_JSON=array "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "done" ] && ok "array output: task completes" \
    || bad "array output" "status is $(task_field "$R" .status), expected done"
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
grep -q 'implement ok (6 turns)' "$D/implement.log" \
    && ok "array output: turns read from the result element" \
    || bad "array output turns" "$(grep -c . "$D/implement.log") log lines, no 'implement ok (6 turns)'"
[ "$(task_field "$R" .cost_usd)" != "0" ] && ok "array output: cost accumulated" \
    || bad "array output cost" "cost_usd is $(task_field "$R" .cost_usd), expected non-zero"

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
printf '\nGH-52: implement that changes nothing is caught before qa runs\n'
R="$WORK/gh52-refuse"; fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_ARCHIVE="$WORK/gh52-archive" AISDLC_STUB=refuse "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "failed" ] && ok "GH-52 UC-1: status failed" || bad "GH-52 UC-1 status" "$(task_field "$R" .status)"
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ ! -f "${D}qa.json" ] && ok "GH-52 UC-1: qa.json absent" || bad "GH-52 UC-1 qa" "qa.json exists"
[ "$(task_field "$R" .error)" = "phase 'implement' failed — it changed no file; see implement.json for why" ] && ok "GH-52 UC-1: exact no-change diagnostic" || bad "GH-52 UC-1 error" "$(task_field "$R" .error)"
jq -e '.status == "failed"' "$WORK/gh52-archive/index.jsonl" >/dev/null 2>&1 \
    && ok "GH-52 UC-1: empty implementation failure archived" || bad "GH-52 archive" "terminal record missing"
R="$WORK/gh52-uc3"; fresh_repo "$R"; BASE="$(git -C "$R" rev-parse HEAD)"
mkdir -p "$R/.claude/rules"; printf 'x\n' > "$R/.claude/rules/test.md"
git -C "$R" add .claude/rules/test.md && git -C "$R" commit -qm "agent config only"
# shellcheck source=plugins/sdlc/bin/aisdlc
out="$(source "$AISDLC" help >/dev/null 2>&1; _branch_changes "$R" "$BASE" "specs/SBX-1")"
[ -z "$out" ] && ok "GH-52 UC-3: agent-config-only diff empty" || bad "GH-52 UC-3" "$out"

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
printf '\npull picks the oldest approved issue nobody holds and this repo has not built\n'
R="$WORK/pull-select"
fresh_repo "$R"
mkdir -p "$R/.aisdlc/tracker/issues" "$R/.claude"
printf -- '- **Tracker descriptor:** `.claude/trackers/local.md`\n' > "$R/.claude/sdlc.md"
local_issue() {   # number state labels assignees
    printf -- '---\nnumber: %s\ntitle: selftest\nstate: %s\nlabels: [%s]\nassignees: [%s]\nauthor: selftest\ncreated: 2026-09-22T00:00:00Z\n---\nBody.\n\n## Comments\n' \
        "$1" "$2" "$3" "$4" > "$R/.aisdlc/tracker/issues/$1.md"
}
local_issue 3 closed bug ""                      # closed: not work
local_issue 5 open "bug, in-progress" "someone"  # someone else's
local_issue 7 open bug ""                        # the one
local_issue 8 open bug ""                        # already has a branch
local_issue 9 open feature ""                    # not approved: no bug label
git -C "$R" branch ai/GH-8-20260101 >/dev/null 2>&1
out="$("$AISDLC" pull --repo "$R" --dry-run 2>&1)"
[ "$out" = "would pull #7 (candidates: 7)" ] \
    && ok "pull --dry-run selects #7 and only #7" \
    || bad "pull selection" "$out"
[ -z "$(ls -A "$R/.aisdlc/tasks" 2>/dev/null)" ] \
    && ok "pull --dry-run queued nothing" \
    || bad "pull dry-run" "a task was created"
"$AISDLC" pull --repo "$R" --no-pr >/dev/null 2>&1 \
    && ok "pull queued #7" \
    || bad "pull" "pull returned non-zero"
[ "$(task_field "$R" .ticket)" = "GH-7" ] && [ "$(task_field "$R" .is_issue)" = "true" ] \
    && ok "pull created a GH-7 issue task" \
    || bad "pull task" "ticket $(task_field "$R" .ticket) is_issue $(task_field "$R" .is_issue)"
grep -qE '^labels:.*in-progress' "$R/.aisdlc/tracker/issues/7.md" \
    && ok "pull claimed #7" \
    || bad "pull claim" "no in-progress on #7"
"$AISDLC" pull --repo "$R" --no-pr >/dev/null 2>&1 \
    && bad "pull twice" "second pull should find nothing: #7 is built, #8 has a branch" \
    || ok "second pull finds nothing — a built issue is never pulled again"
task_count="$(find "$R/.aisdlc/tasks" -name 'task.json' | wc -l | tr -d ' ')"
[ "$task_count" -eq 1 ] \
    && ok "still one task after the second pull" \
    || bad "pull duplicate" "$task_count tasks"

# --------------------------------------------------------------------------- #
printf '\nloop --once drains the queue even when pull finds nothing\n'
"$AISDLC" loop --repo "$R" --once --no-pr >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "done" ] \
    && ok "loop --once ran the queued GH-7 task to done" \
    || bad "loop drain" "status $(task_field "$R" .status)"
grep -q 'Lock released' "$R/.aisdlc/tracker/issues/7.md" \
    && ok "loop released the issue after the run" \
    || bad "loop release" "no release comment on #7"
"$AISDLC" loop --repo "$R" --once --interval abc >/dev/null 2>&1 \
    && bad "loop interval" "non-numeric --interval accepted" \
    || ok "loop refuses a non-numeric --interval"

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
printf '\nGH-51 UC-1: scope-check: all changed files in scope → PASS\n'
R="$WORK/scope-pass"
# Only pkg/ is declared; the task's own spec directory is excluded from classification.
fresh_repo_scope "$R" \
    $'- `pkg/`' \
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
printf '\nGH-51 UC-2: scope-check: undeclared changed file → GAPS, chain continues\n'
R="$WORK/scope-gaps"
# Only pkg/stub.go is declared; stub_test.go remains undeclared, unlike harness reports.
fresh_repo_scope "$R" \
    $'- `pkg/stub.go`' \
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
grep -qF '`specs/SBX-1/qa-report.md`' "${D}scope-report.md" 2>/dev/null \
    && bad "GH-51 UC-2 scope GAPS report" "specs/SBX-1/qa-report.md appears in report — should be excluded" \
    || ok "GH-51 UC-2: scope GAPS: specs/SBX-1/qa-report.md not present in report (excluded by _branch_changes)"
[ "$(task_field "$R" .scope_verdict)" = "GAPS" ] \
    && ok "scope GAPS: scope_verdict in task.json" \
    || bad "scope_verdict GAPS" "$(task_field "$R" .scope_verdict)"

# --------------------------------------------------------------------------- #
printf '\nscope-check: own spec-dir artefacts are excluded from diff → PASS (regression)\n'
R="$WORK/scope-own-spec-dir"
# Harness reports are excluded even when only pkg/ is declared.
fresh_repo_scope "$R" \
    $'- `pkg/`' \
    "" \
    ""
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .scope_verdict)" = "PASS" ] \
    && ok "scope own-spec-dir: verdict is PASS (artefacts excluded from diff)" \
    || bad "scope own-spec-dir verdict" "$(task_field "$R" .scope_verdict)"
grep -qF '**undeclared**' "${D}scope-report.md" 2>/dev/null \
    && bad "scope own-spec-dir report" "specs/SBX-1/qa-report.md wrongly listed as undeclared" \
    || ok "scope own-spec-dir: no undeclared entry — own spec-dir artefacts are excluded from diff"

# --------------------------------------------------------------------------- #
printf '\nGH-51 UC-3: scope-check: repo-wide prohibition hit → BLOCKED, chain stops before ship\n'
R="$WORK/scope-blocked"
# Prohibit a real source file, not an excluded harness report; ship must not run.
fresh_repo_scope "$R" \
    $'- `pkg/stub.go`' \
    "" \
    $'- `pkg/stub_test.go`'
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
# _branch_changes unit tests (GH-51 UC-4)
# --------------------------------------------------------------------------- #
printf '\n_branch_changes: own-specdir excluded, sibling visible, root bookkeeping excluded (GH-51 UC-4)\n'
_BC_WT="$WORK/bc-wt"
mkdir -p "$_BC_WT/pkg" "$_BC_WT/specs/SBX-1" "$_BC_WT/specs/SBX-2" "$_BC_WT/src/specs/SBX-1" "$_BC_WT/custom.specs/SBX-1"
git -C "$_BC_WT" init -q -b master; git -C "$_BC_WT" config user.email bc@localhost; git -C "$_BC_WT" config user.name bc
printf 'base\n' > "$_BC_WT/pkg/stub.go"; git -C "$_BC_WT" add -A && git -C "$_BC_WT" commit -q -m "base"; git -C "$_BC_WT" update-ref refs/remotes/origin/master HEAD
printf 'impl\n' > "$_BC_WT/pkg/stub.go";   printf 'qa\n'     > "$_BC_WT/specs/SBX-1/qa-report.md"  # own specdir — must be excluded
printf 'spec\n' > "$_BC_WT/specs/SBX-2/spec.md"; printf 'nested\n' > "$_BC_WT/src/specs/SBX-1/file.go" # sibling visible; nested prefix visible
printf 'agents\n' > "$_BC_WT/AGENTS.md";   printf 'claude\n' > "$_BC_WT/CLAUDE.md"                  # root bookkeeping — must be excluded
printf 'bak\n' > "$_BC_WT/AGENTS.md.bak";  printf 'ts\n'     > "$_BC_WT/CLAUDE.md.ts"               # suffix-named — must remain visible
printf 'custom\n' > "$_BC_WT/custom.specs/SBX-1/qa.md"                                               # custom specdir (metachar) — must be excluded
git -C "$_BC_WT" add -A && git -C "$_BC_WT" commit -q -m "branch changes"
# shellcheck source=plugins/sdlc/bin/aisdlc
_BC_OUT="$(source "$AISDLC" help >/dev/null 2>&1; _branch_changes "$_BC_WT" "origin/master" "specs/SBX-1")"
for _f in 'pkg/stub.go' 'specs/SBX-2/spec.md' 'src/specs/SBX-1/file.go'; do
    printf '%s\n' "$_BC_OUT" | grep -qF "$_f" \
        && ok "GH-51 UC-4: _branch_changes: $_f visible" \
        || bad "GH-51 UC-4 _branch_changes" "$_f missing from output"
done
printf '%s\n' "$_BC_OUT" | grep -qF 'specs/SBX-1/qa-report.md' \
    && bad "GH-51 UC-4 _branch_changes" "specs/SBX-1/qa-report.md present — own specdir must be excluded" \
    || ok "GH-51 UC-4: _branch_changes: specs/SBX-1/qa-report.md excluded (own specdir)"
for _f in 'AGENTS.md' 'CLAUDE.md'; do
    printf '%s\n' "$_BC_OUT" | grep -qxF "$_f" \
        && bad "GH-51 UC-4 _branch_changes" "$_f present — root bookkeeping must be excluded" \
        || ok "GH-51 UC-4: _branch_changes: $_f excluded (root bookkeeping)"
done
for _f in 'AGENTS.md.bak' 'CLAUDE.md.ts'; do
    printf '%s\n' "$_BC_OUT" | grep -qxF "$_f" \
        && ok "GH-51 UC-4: _branch_changes: $_f visible (not excluded)" \
        || bad "GH-51 UC-4 _branch_changes root-file-suffix" "$_f excluded — exact match required"
done
# shellcheck source=plugins/sdlc/bin/aisdlc
_BC_OUT2="$(source "$AISDLC" help >/dev/null 2>&1; _branch_changes "$_BC_WT" "origin/master" "custom.specs/SBX-1")"
printf '%s\n' "$_BC_OUT2" | grep -qF 'custom.specs/SBX-1/qa.md' \
    && bad "GH-51 UC-4 _branch_changes metachar" "custom.specs/SBX-1/qa.md present — custom specdir must be excluded (literal, not regex)" \
    || ok "GH-51 UC-4: _branch_changes: custom.specs/SBX-1/qa.md excluded (metachar-safe literal prefix)"
printf '%s\n' "$_BC_OUT2" | grep -qF 'specs/SBX-2/spec.md' \
    && ok "GH-51 UC-4: _branch_changes custom specdir: sibling specs/SBX-2/spec.md still visible" \
    || bad "GH-51 UC-4 _branch_changes custom specdir" "specs/SBX-2/spec.md missing"
unset _BC_WT _BC_OUT _BC_OUT2 _f
printf '\nGH-51 UC-1 boundary: bookkeeping-only changes still enforce the size ceiling\n'
R="$WORK/gh51-uc5"; fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_STUB=noop "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
_WT5="$(task_field "$R" .worktree)"; _ID5="$(ls "$R"/.aisdlc/tasks/ | head -1)"
printf '%s\n' {1..3001} > "$_WT5/AGENTS.md"
git -C "$_WT5" add AGENTS.md && git -C "$_WT5" commit -q -m "bookkeeping"
"$AISDLC" scope-check "$_ID5" --repo "$R" >/dev/null 2>&1; _SIZE_RC=$?
[ "$_SIZE_RC" -eq 1 ] && [ "$(task_field "$R" .scope_verdict)" = "BLOCKED" ] \
    && ok "GH-51 UC-1: bookkeeping-only branch blocked by size ceiling" \
    || bad "GH-51 UC-1 size boundary" "rc=$_SIZE_RC verdict=$(task_field "$R" .scope_verdict)"
unset R _WT5 _ID5 _SIZE_RC

# --------------------------------------------------------------------------- #
# GH-54: verbatim In: exempts from spec-Out; globs/dirs/Context: do not
# --------------------------------------------------------------------------- #

printf '\nGH-54 UC-1: verbatim In: beats Out: cross-reference → PASS\n'
R="$WORK/gh54-uc1"
fresh_repo_scope "$R" \
    $'- `pkg/stub.go` — implementation\n- `pkg/stub_test.go` — tests\n- `specs/SBX-1/`' \
    $'- `pkg/stub.go` is referenced here as a cross-reference, not as a prohibition' \
    ""
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .scope_verdict)" = "PASS" ] \
    && ok "GH-54 UC-1: scope_verdict PASS" || bad "GH-54 UC-1 scope_verdict" "$(task_field "$R" .scope_verdict)"
grep -q 'Verdict: PASS' "${D}scope-report.md" 2>/dev/null \
    && ok "GH-54 UC-1: report PASS" || bad "GH-54 UC-1 verdict" "$(grep 'Verdict:' "${D}scope-report.md" 2>/dev/null)"
[ "$(task_field "$R" .status)" = "done" ] \
    && ok "GH-54 UC-1: task done" || bad "GH-54 UC-1 status" "$(task_field "$R" .status)"

printf '\nGH-54 UC-2: directory-pattern In: does not exempt from Out: → BLOCKED\n'
R="$WORK/gh54-uc2"
fresh_repo_scope "$R" $'- `pkg/` — all package files' $'- `pkg/stub.go` — out of bounds' ""
"$AISDLC" add SBX-1 --repo "$R" >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .scope_verdict)" = "BLOCKED" ] \
    && ok "GH-54 UC-2: scope_verdict BLOCKED (dir-pattern does not exempt)" \
    || bad "GH-54 UC-2 scope_verdict" "$(task_field "$R" .scope_verdict)"

printf '\nGH-54 UC-3: glob In: (* ? [...]) does not exempt from Out: → BLOCKED\n'
for _gh54pat in 'pkg/*.go' 'pkg/stub.?o' 'pkg/stu[b].go'; do
    R="$WORK/gh54-uc3-${_gh54pat//[^a-zA-Z0-9]/-}"
    fresh_repo_scope "$R" "- \`${_gh54pat}\` — glob" $'- `pkg/stub.go` — out of bounds' ""
    "$AISDLC" add SBX-1 --repo "$R" >/dev/null 2>&1
    "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
    D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
    [ "$(task_field "$R" .scope_verdict)" = "BLOCKED" ] \
        && ok "GH-54 UC-3 (${_gh54pat}): BLOCKED (glob In: does not exempt)" \
        || bad "GH-54 UC-3 ${_gh54pat}" "$(task_field "$R" .scope_verdict)"
done

printf '\nGH-54 UC-4: verbatim In: skips spec-Out but repo-wide prohibited wins → BLOCKED\n'
R="$WORK/gh54-uc4"
fresh_repo_scope "$R" \
    $'- `pkg/stub.go` — implementation\n- `pkg/stub_test.go` — tests\n- `specs/SBX-1/`' \
    $'- `pkg/stub.go` cross-referenced here' \
    $'- `pkg/stub.go`'
"$AISDLC" add SBX-1 --repo "$R" >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .scope_verdict)" = "BLOCKED" ] \
    && ok "GH-54 UC-4: scope_verdict BLOCKED (prohibited overrides verbatim In:)" \
    || bad "GH-54 UC-4 scope_verdict" "$(task_field "$R" .scope_verdict)"
grep -qF '**out of bounds** (prohibited)' "${D}scope-report.md" 2>/dev/null \
    && ok "GH-54 UC-4: row shows **out of bounds** (prohibited)" \
    || bad "GH-54 UC-4 report" "$(grep 'out of bounds' "${D}scope-report.md" 2>/dev/null || echo 'no oob line')"

printf '\nGH-54 UC-5: Context: mention only does not exempt from Out: → BLOCKED\n'
R="$WORK/gh54-uc5"
fresh_repo_scope "$R" $'- `pkg/stub_test.go` — tests\n- `specs/SBX-1/`' $'- `pkg/stub.go` — out of bounds' ""
printf '\n## Context\n\n- `pkg/stub.go`: existing file for reference\n' >> "$R/specs/SBX-1/spec.md"
git -C "$R" add specs/SBX-1/spec.md
git -C "$R" -c user.name=selftest -c user.email=selftest@localhost commit -q -m "chore: GH-54-UC-5 context"
git -C "$R" update-ref refs/remotes/origin/master HEAD
"$AISDLC" add SBX-1 --repo "$R" >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .scope_verdict)" = "BLOCKED" ] \
    && ok "GH-54 UC-5: scope_verdict BLOCKED (Context: does not exempt)" \
    || bad "GH-54 UC-5 scope_verdict" "$(task_field "$R" .scope_verdict)"

printf '\nGH-54 UC-6: verbatim In: beats Out: for one file; undeclared second → GAPS\n'
R="$WORK/gh54-uc6"
fresh_repo_scope "$R" $'- `pkg/stub.go` — implementation' $'- `pkg/stub.go` cross-referenced here' ""
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .scope_verdict)" = "GAPS" ] \
    && ok "GH-54 UC-6: scope_verdict GAPS" || bad "GH-54 UC-6 scope_verdict" "$(task_field "$R" .scope_verdict)"
grep -qF '**undeclared**' "${D}scope-report.md" 2>/dev/null \
    && ok "GH-54 UC-6: undeclared listed" || bad "GH-54 UC-6 undeclared" "no **undeclared** entry"
[ "$(task_field "$R" .status)" = "done" ] \
    && ok "GH-54 UC-6: task done (GAPS does not stop pipeline)" \
    || bad "GH-54 UC-6 status" "$(task_field "$R" .status)"

# --------------------------------------------------------------------------- #
# structure check selftest (UC-1, UC-3, UC-4 — GH-44)
# --------------------------------------------------------------------------- #

# Stub lizard lives in a dedicated dir; generated here, added to PATH only for UC-1.
_LIZARD_STUB_DIR="$WORK/lizard-stub-bin"
mkdir -p "$_LIZARD_STUB_DIR"
cat > "$_LIZARD_STUB_DIR/lizard" <<'LIZARD_STUB_EOF'
#!/usr/bin/env bash
# stub-lizard — fake lizard for selftest structure checks. No real analysis; returns
# fixed CC values so the selftest can assert on specific erosion/hotspot outcomes.
#
# The structure check exports _AISDLC_STRUCT_PASS=before for the before-version call
# and leaves it unset (defaults to "after") for the current-HEAD call. The stub uses
# this to return different CC values, simulating a function whose CC rose from 8 to 14.
#
# File-name heuristics keep the test simple:
#   *_test.go files (Go test files): low CC (2) to avoid polluting the largest-CC-
#   increase result with the added-file entry.
#
# Lizard CSV format (1.24.1): no header; fields 6-9 double-quoted:
#   NLOC,CCN,token,PARAM,length,"location","file","function","long_name",start,end
set -uo pipefail

for f in "$@"; do
    case "$f" in
        *.go|*.py|*.js|*.ts)
            case "${_AISDLC_STRUCT_PASS:-after}" in
                before)
                    cc=8; nloc=45
                    ;;
                *)
                    case "$f" in
                        *_test.go|*_test.py|*.test.ts|*.spec.ts) cc=2; nloc=20 ;;
                        *)                                         cc=14; nloc=45 ;;
                    esac
                    ;;
            esac
            printf '%d,%d,100,2,30,"%s:GoFunc","%s","GoFunc","GoFunc",1,30\n' \
                "$nloc" "$cc" "$f" "$f"
            ;;
    esac
done
LIZARD_STUB_EOF
chmod +x "$_LIZARD_STUB_DIR/lizard"

# --------------------------------------------------------------------------- #
printf '\nstructure UC-1: CC 8 -> 14 in a Go file → ## Structure, new hotspot, GAPS\n'
R="$WORK/struct-uc1"
fresh_repo_scope "$R" \
    $'- `pkg/`\n- `specs/SBX-1/`' \
    "" \
    ""
# Pre-create pkg/stub.go at the base so the stub's commit makes it a Modified (M) file.
# The stub lizard returns CC=8 for the before pass and CC=14 for the after pass.
mkdir -p "$R/pkg"
printf 'package pkg\nfunc Stub() string { return "before" }\n' > "$R/pkg/stub.go"
git -C "$R" add -A && git -C "$R" commit -q -m "feat: add stub at base"
git -C "$R" update-ref refs/remotes/origin/master HEAD
# Use verify=true so the UC-1 test doesn't need pkg/stub_test.go to exist
mkdir -p "$R/.aisdlc"
printf '{"verify":["true"]}\n' > "$R/.aisdlc/config.json"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
PATH="$_LIZARD_STUB_DIR:$PATH" "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .scope_verdict)" = "GAPS" ] \
    && ok "UC-1: verdict is GAPS (structure finding promotes PASS)" \
    || bad "UC-1 verdict" "$(task_field "$R" .scope_verdict)"
grep -q '## Structure' "${D}scope-report.md" 2>/dev/null \
    && ok "UC-1: ## Structure section present in scope-report.md" \
    || bad "UC-1 structure section" "## Structure not found"
grep -q '8 -> 14' "${D}scope-report.md" 2>/dev/null \
    && ok "UC-1: CC 8 -> 14 listed in ## Structure" \
    || bad "UC-1 CC change" "8 -> 14 not in scope-report.md"
grep -qF 'new hotspot:' "${D}scope-report.md" 2>/dev/null \
    && ok "UC-1: new hotspot finding present" \
    || bad "UC-1 new hotspot" "new hotspot: not found in scope-report.md"
grep -q 'Largest CC increase' "${D}scope-report.md" 2>/dev/null \
    && ok "UC-1: Largest CC increase line present" \
    || bad "UC-1 largest" "Largest CC increase not found"

# --------------------------------------------------------------------------- #
printf '\nstructure UC-3: lizard not on PATH → skipped: not installed, no finding\n'
# Hide only the optional external tool; do not depend on the host's installed toolchain.
R="$WORK/struct-uc3"
fresh_repo_scope "$R" \
    $'- `pkg/`\n- `specs/SBX-1/`' \
    "" \
    ""
mkdir -p "$R/pkg"
printf 'package pkg\nfunc Stub() string { return "before" }\n' > "$R/pkg/stub.go"
git -C "$R" add -A && git -C "$R" commit -q -m "feat: add stub at base"
git -C "$R" update-ref refs/remotes/origin/master HEAD
mkdir -p "$R/.aisdlc"
printf '{"verify":["true"]}\n' > "$R/.aisdlc/config.json"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
(
    command() {
        [ "${1:-}" = "-v" ] && [ "${2:-}" = "lizard" ] && return 1
        builtin command "$@"
    }
    export -f command
    "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
)
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
grep -q '## Structure' "${D}scope-report.md" 2>/dev/null \
    && ok "UC-3: ## Structure section present (skipped message)" \
    || bad "UC-3 structure section" "## Structure not found"
grep -qF 'not installed' "${D}scope-report.md" 2>/dev/null \
    && ok "UC-3: section says 'not installed'" \
    || bad "UC-3 skip message" "$(grep -A1 '## Structure' "${D}scope-report.md" 2>/dev/null | tail -1)"
# No ### Findings when lizard is absent
! grep -q '### Findings' "${D}scope-report.md" 2>/dev/null \
    && ok "UC-3: no findings when lizard absent" \
    || bad "UC-3 no findings" "### Findings unexpectedly present"
[ "$(task_field "$R" .scope_verdict)" != "BLOCKED" ] \
    && ok "UC-3: scope-check returns 0 (phase continues)" \
    || bad "UC-3 phase continues" "task failed when it should continue"


# --------------------------------------------------------------------------- #
printf '\nstructure UC-4: only .md files changed → no ## Structure section\n'
R="$WORK/struct-uc4"
fresh_repo_scope "$R" \
    $'- `docs/impl-notes.md`' \
    "" \
    ""
# mdonly stub: implement commits only a .md file; qa adds qa-report.md
mkdir -p "$R/.aisdlc"
printf '{"verify":["test -f specs/SBX-1/qa-report.md"]}\n' > "$R/.aisdlc/config.json"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_STUB=mdonly "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .scope_verdict)" = "PASS" ] && [ -f "${D}scope-report.md" ] && ! grep -q '## Structure' "${D}scope-report.md" \
    && ok "UC-4: no ## Structure section when only .md files changed" \
    || bad "UC-4 no structure" "scope-check did not PASS, report is missing, or ## Structure is present"

# --------------------------------------------------------------------------- #
printf '\nbilling=subscription: null cost, no --max-budget-usd in args\n'
R="$WORK/billing-sub"
fresh_repo "$R"
mkdir -p "$R/.aisdlc"
printf '{"verify":["true"],"billing":"subscription"}\n' > "$R/.aisdlc/config.json"
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
printf '{"verify":["true"],"billing":"subscription"}\n' > "$R/.aisdlc/config.json"
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
printf '{"verify":["true"],"model_roles":{"smol":"haiku","slow":"opus"}}\n' > "$R/.aisdlc/config.json"
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
printf '{"verify":["true"],"model_roles":{"smol":"haiku"}}\n' > "$R/.aisdlc/config.json"
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
printf '{"verify":["true"],"model_roles":{"smol":"haiku","slow":"opus"}}\n' > "$R/.aisdlc/config.json"
"$AISDLC" add SBX-1 --repo "$R" --model sonnet >/dev/null 2>&1
# Edit config after add — snapshot in task.json must be used, not the new config
printf '{"verify":["true"],"model_roles":{"smol":"changed-model","slow":"another-model"}}\n' > "$R/.aisdlc/config.json"
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

# pull over github: the selector filters assignees and in-progress on the runner side, from
# the one `gh issue list` call, and asks for the approval label on the wire.
export STUB_GH_ISSUES="$WORK/gh-issues.json"
printf '[{"number":12,"labels":[{"name":"bug"}],"assignees":[]},
         {"number":4,"labels":[{"name":"bug"},{"name":"in-progress"}],"assignees":[{"login":"other"}]},
         {"number":6,"labels":[{"name":"bug"}],"assignees":[{"login":"other"}]},
         {"number":9,"labels":[{"name":"bug"}],"assignees":[]}]\n' > "$STUB_GH_ISSUES"
printf -- '- **Tracker descriptor:** `.claude/trackers/github.md`\n' > "$R/.claude/sdlc.md"
out="$("$AISDLC" pull --repo "$R" --dry-run 2>&1)"
[ "$out" = "would pull #9 (candidates: 9 12)" ] \
    && ok "pull over github: oldest unassigned, not in-progress, first" \
    || bad "pull github selection" "$out"
grep -q 'gh issue list .*--label bug' "$STUB_GH_LOG" \
    && ok "pull over github asks for the approval label on the wire" \
    || bad "pull github wire" "$(grep 'issue list' "$STUB_GH_LOG" || echo 'no issue list call')"
unset STUB_GH_ISSUES
unset STUB_GH_STATE STUB_GH_LOG STUB_GH_USER
rm -f "$STUB_DIR/gh"


# --------------------------------------------------------------------------- #
printf '\nverify is the last gate before ship, and it reads git, not reports\n'
verify_case() {  # <name> <stub mode> <config json> — expects FAIL and no ship
    local name="$1" mode="$2" config="$3"
    R="$WORK/verify-$name"
    fresh_repo "$R"
    [ -n "$config" ] && printf '%s\n' "$config" > "$R/.aisdlc/config.json"
    "$AISDLC" add SBX-1 --repo "$R" >/dev/null 2>&1
    AISDLC_STUB="$mode" "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
    D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
}
verify_case unconfigured ok '{}'
[ "$(task_field "$R" .verify_verdict)" = "FAIL" ] && ok "no verify commands is a FAIL, not a skip" \
    || bad "verify" "verdict is $(task_field "$R" .verify_verdict) with nothing configured"
[ ! -f "$D/ship.log" ] && ok "ship never ran" || bad "verify" "it shipped without a verify PASS"
case "$(task_field "$R" .error)" in *verify*configured*) ok "the error says what to configure" ;;
    *) bad "verify" "error is $(task_field "$R" .error)" ;; esac

verify_case redcommand ok '{"verify":["true","exit 3"]}'
[ "$(task_field "$R" .verify_verdict)" = "FAIL" ] && ok "a failing verification command fails verify" \
    || bad "verify" "verdict is $(task_field "$R" .verify_verdict)"
grep -q 'exit 3.*exited 3\|`exit 3` exited 3' <<< "$(task_field "$R" .verify_failures)" \
    && ok "the failure names the command" || bad "verify" "failures: $(task_field "$R" .verify_failures)"
[ ! -f "$D/ship.log" ] && ok "ship never ran" || bad "verify" "shipped past a red command"

verify_case nouc nouc ''
[ "$(task_field "$R" .verify_verdict)" = "FAIL" ] && ok "a UC with no test naming it fails verify" \
    || bad "verify" "verdict is $(task_field "$R" .verify_verdict)"
grep -q 'UC-1' "$D/verify-report.md" && ok "the report names the untested UC" || bad "verify" "UC-1 not in verify-report.md"

verify_case skiptest skiptest ''
[ "$(task_field "$R" .verify_verdict)" = "FAIL" ] && ok "a switched-off test fails verify" \
    || bad "verify" "t.Skip was accepted"

verify_case dirty dirty ''
[ "$(task_field "$R" .verify_verdict)" = "FAIL" ] && ok "an uncommitted change fails verify — the PR would not contain it" \
    || bad "verify" "a dirty worktree was verified as the commit"
grep -q 'pkg/stub.go' "$D/verify-report.md" && ok "the report names the uncommitted file" || bad "verify" "uncommitted file not named"
[ ! -f "$D/ship.log" ] && ok "ship never ran" || bad "verify" "shipped with the fix left uncommitted"

verify_case deltest deltest ''
[ "$(task_field "$R" .verify_verdict)" = "FAIL" ] && ok "a deleted test file fails verify" \
    || bad "verify" "deleting legacy/old_test.go was accepted"
grep -q 'legacy/old_test.go' "$D/verify-report.md" && ok "the report names the deleted file" \
    || bad "verify" "deleted file not named"

# A deletion a human retired on the base passes; the same entry written by the branch does not.
R="$WORK/verify-retired"
fresh_repo "$R"
printf 'legacy/old_test.go  TestLegacy covered a removed client\n' > "$R/.claude/retired-tests"
git -C "$R" add .claude/retired-tests && git -C "$R" commit -q -m "chore: retire legacy test"
git -C "$R" update-ref refs/remotes/origin/master HEAD
"$AISDLC" add SBX-1 --repo "$R" >/dev/null 2>&1
AISDLC_STUB=deltest "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ "$(task_field "$R" .verify_verdict)" = "PASS" ] && ok "a deletion retired on the base passes verify" \
    || bad "verify" "verdict is $(task_field "$R" .verify_verdict): $(task_field "$R" .verify_failures)"
grep -q 'retired via .claude/retired-tests: legacy/old_test.go' "$D/verify-report.md" \
    && ok "the report still names the retired file" || bad "verify" "retired file not named in verify-report.md"

verify_case selfretire selfretire ''
[ "$(task_field "$R" .verify_verdict)" = "FAIL" ] && ok "a retirement the branch wrote for itself fails verify" \
    || bad "verify" "the branch approved its own deletion"
[ ! -f "$D/ship.log" ] && ok "ship never ran" || bad "verify" "shipped a self-retired deletion"

# --------------------------------------------------------------------------- #
printf '\nthe omp runtime runs the same pipeline\n'
R="$WORK/omp"
TRACE="$WORK/omp-invocations.txt"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --runtime omp >/dev/null 2>&1
[ "$(task_field "$R" .runtime)" = "omp" ] && ok "runtime recorded at queue time" \
    || bad "omp runtime" "runtime is $(task_field "$R" .runtime)"
AISDLC_STUB_TRACE="$TRACE" "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "done" ] && ok "status is done" || bad "omp runtime" "status is $(task_field "$R" .status): $(task_field "$R" .error)"
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
for ph in implement qa ship review; do  # verify runs in-process, no model
    grep -q "=== omp -p \"/sdlc:$ph SBX-1\"" "$D/$ph.log" 2>/dev/null \
        && ok "$ph ran through omp as /sdlc:$ph" || bad "omp runtime" "$ph.log has no omp invocation"
done
[ -f "$D/implement.json.stream.jsonl" ] && ok "the raw event stream is kept" || bad "omp runtime" "no implement.json.stream.jsonl"
[ "$(jq -r '.num_turns' "$D/implement.json")" = "6" ] && ok "turns counted from turn_end events" \
    || bad "omp runtime" "num_turns is $(jq -r '.num_turns' "$D/implement.json")"
# stub-claude reports 0.05 per phase except review (0.02); four model phases ran.
[ "$(jq -r '.cost_usd' "$D/task.json")" = "0.17" ] && ok "cost summed from turn usage" \
    || bad "omp runtime" "cost_usd is $(jq -r '.cost_usd' "$D/task.json")"
grep -q -- '--plugin-dir [^ ]*/plugins/sdlc ' "$TRACE" && ok "--plugin-dir loads this checkout's plugin" \
    || bad "omp runtime" "no --plugin-dir for the sdlc plugin"
grep -q -- '--plugin-dir [^ ]*/plugins/slop-guard' "$TRACE" && ok "--plugin-dir loads the guard plugin beside it" \
    || bad "omp runtime" "no --plugin-dir for slop-guard"
grep -q -- '--approval-mode yolo' "$TRACE" && ok "no approval prompt can stall the phase" \
    || bad "omp runtime" "--approval-mode yolo missing"
grep -q '^omp headless:1 ' "$TRACE" && ok "the phase runs with AISDLC_HEADLESS=1" \
    || bad "omp runtime" "AISDLC_HEADLESS not set"
grep -q 'max-budget-usd' "$TRACE" && bad "omp runtime" "a spend cap omp cannot enforce was passed" \
    || ok "no spend cap is claimed"

printf '\nomp forwards an unknown command to the model; the runner must not accept that\n'
R="$WORK/omp-noop"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --runtime omp >/dev/null 2>&1
AISDLC_STUB=noop "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "failed" ] && ok "an unexpanded command fails the phase" \
    || bad "omp expansion" "status is $(task_field "$R" .status)"
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
[ ! -f "$D/qa.log" ] && ok "nothing runs after it" || bad "omp expansion" "qa ran after an improvised implement"
grep -q 'Unknown command' "$D/implement.log" && ok "the log says the command was not expanded" \
    || bad "omp expansion" "implement.log does not say why"

R="$WORK/omp-nocmd"
TRACE="$WORK/omp-nocmd.txt"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --runtime omp --phase implement,bogus --no-pr >/dev/null 2>&1
AISDLC_STUB_TRACE="$TRACE" "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "failed" ] && ok "a phase with no command file fails" \
    || bad "omp command check" "status is $(task_field "$R" .status)"
[ "$(grep -c '/sdlc:bogus' "$TRACE" 2>/dev/null)" = "0" ] && ok "omp was never invoked for it" \
    || bad "omp command check" "omp ran a command that does not exist"

printf '\nan omp phase that edits the policy layer fails\n'
R="$WORK/omp-policy"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --runtime omp --no-pr >/dev/null 2>&1
AISDLC_STUB=policyedit "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "failed" ] && ok "editing .claude/ fails the task" \
    || bad "omp policy" "status is $(task_field "$R" .status)"
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"
grep -q 'edited .claude/' "$D/implement.log" && ok "the log names the policy edit" \
    || bad "omp policy" "implement.log does not mention .claude/"

printf '\nthe runtime is validated and resolved like every other default\n'
R="$WORK/omp-config"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --runtime nonsense >/dev/null 2>&1 \
    && bad "runtime" "an unknown runtime was accepted" || ok "an unknown runtime is refused"
mkdir -p "$R/.aisdlc"
printf '{"verify":["true"],"runtime":"omp"}\n' > "$R/.aisdlc/config.json"
"$AISDLC" add SBX-1 --repo "$R" >/dev/null 2>&1
[ "$(task_field "$R" .runtime)" = "omp" ] && ok "config.json sets the runtime" \
    || bad "runtime" "runtime is $(task_field "$R" .runtime)"
# A queued omp task on a machine without omp: refuse up front, leave the task queued.
NO_OMP="$WORK/no-omp-bin"
mkdir -p "$NO_OMP"
for tool in git jq flock bash sed awk grep find sort sha256sum cut tr wc head tail date dirname basename mkdir cat printf readlink; do
    p="$(command -v "$tool")" && ln -sf "$p" "$NO_OMP/$tool"
done
PATH="$NO_OMP" "$AISDLC" run --repo "$R" --once >/dev/null 2>&1 \
    && bad "runtime" "run started without omp installed" || ok "run refuses when a queued task's runtime is missing"
[ "$(task_field "$R" .status)" = "queued" ] && ok "the task stays queued" \
    || bad "runtime" "status is $(task_field "$R" .status)"

printf '\nsessions: claude records phase sessions (UC-1)\n'
R="$WORK/sessions-uc1"; fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"; TF="$D/task.json"
[ "$(jq -r '.sessions | length' "$TF")" -ge 2 ] && ok "UC-1: two entries" || bad "UC-1 len" "$(jq '.sessions|length' "$TF")"
[ "$(jq -r '.sessions[0].phase,.sessions[0].runtime' "$TF")" = "implement
claude" ] && ok "UC-1: phase and runtime" || bad "UC-1 fields" "$(jq -r '.sessions[0]' "$TF")"
[ "$(jq -r '.sessions[0].session_id' "$TF")" = "$(jq -r '.session_id // empty' "$D/implement.json")" ] \
    && ok "UC-1: session_id from implement.json" || bad "UC-1 sid" "mismatch"
jq -r '.sessions[0].started' "$TF" | grep -qE '^[0-9]{4}-' && ok "UC-1: ISO started" || bad "UC-1 ts" "$(jq -r '.sessions[0].started' "$TF")"
jq -r '.sessions[0].ended' "$TF" | grep -qE '^[0-9]{4}-' && ok "UC-1: ISO ended" || bad "UC-1 ended" "$(jq -r '.sessions[0].ended' "$TF")"
[ "$(jq -r '.sessions[1].session_id' "$TF")" = "$(jq -r '.session_id // empty' "$D/qa.json")" ] \
    && ok "UC-1: qa session_id" || bad "UC-1 qa" "mismatch"
[ "$(jq -r '.sessions[1].phase,.sessions[1].runtime' "$TF")" = "qa
claude" ] && ok "UC-1: qa phase and runtime" || bad "UC-1 qa fields" "$(jq -r '.sessions[1]' "$TF")"
printf '\nsessions: transcript encodes worktree path (UC-2)\n'
R="$WORK/sessions-uc2"; fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --phase implement >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"; TF="$D/task.json"
_WT="$(jq -r '.worktree' "$TF")"; _SID="$(jq -r '.sessions[0].session_id' "$TF")"
[ "$(jq -r '.sessions[0].transcript' "$TF")" = "$HOME/.claude/projects/$(printf '%s' "$_WT"|tr '/.' '-')/${_SID}.jsonl" ] \
    && ok "UC-2: transcript encodes /. to -" || bad "UC-2" "$(jq -r '.sessions[0].transcript' "$TF")"
unset _WT _SID
printf '\nsessions: omp records session from sessions/ (UC-3)\n'
R="$WORK/sessions-uc3"; fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --runtime omp --phase implement >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
D="$(ls -d "$R"/.aisdlc/tasks/*/ | head -1)"; TF="$D/task.json"
_JF="$(ls "${D%/}/sessions/"*.jsonl 2>/dev/null | head -1 || true)"
[ -n "$_JF" ] && ok "UC-3: session .jsonl written" || bad "UC-3" "none in ${D%/}/sessions/"
_UUID="$(basename "${_JF:-x}" .jsonl | sed 's/^[^_]*_//')"
[ "$(jq -r '.sessions[0].session_id' "$TF")" = "$_UUID" ] && [ "$(jq -r '.sessions[0].transcript' "$TF")" = "$_JF" ] \
    && ok "UC-3: session_id and transcript" || bad "UC-3" "$(jq '.sessions[0]' "$TF")"
[ "$(jq -r '.sessions[0].runtime' "$TF")" = "omp" ] && ok "UC-3: runtime is omp" || bad "UC-3 rt" "$(jq -r '.sessions[0].runtime' "$TF")"
unset _JF _UUID
printf '\nsessions: runtime_version from --version (UC-4)\n'
R="$WORK/sessions-uc4"; fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
TF="$(ls -1 "$R"/.aisdlc/tasks/*/task.json | head -1)"
[ "$(jq -r '.runtime_version' "$TF")" = "$(claude --version 2>/dev/null | head -1)" ] \
    && ok "UC-4: runtime_version correct" || bad "UC-4" "$(jq -r '.runtime_version' "$TF")"
_CF="$WORK/vc4"; printf '0' > "$_CF"
_SD="$(mktemp -d)"; _REAL="$STUB_DIR/claude"
printf '#!/bin/sh\n[ "${1:-}" = "--version" ] && { c=$(cat "%s"); printf "%%d" "$((c+1))" > "%s"; }\nexec "%s" "$@"\n' \
    "$_CF" "$_CF" "$_REAL" > "$_SD/claude"
chmod +x "$_SD/claude"
R="$WORK/sessions-uc4b"; fresh_repo "$R"
PATH="$_SD:$PATH" "$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
PATH="$_SD:$PATH" "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(cat "$_CF")" -eq 1 ] && ok "UC-4: --version called once for two-phase task" \
    || bad "UC-4 once" "--version called $(cat "$_CF") times, expected 1"
rm -rf "$_SD"; unset _CF _SD _REAL
printf '\nsessions: missing session_id records null (UC-5)\n'
R="$WORK/sessions-uc5"; fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --phase implement >/dev/null 2>&1
AISDLC_STUB=nosid "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
TF="$(ls -1 "$R"/.aisdlc/tasks/*/task.json | head -1)"
[ "$(jq -r '.sessions[0].session_id' "$TF")" = "null" ] && [ "$(jq -r '.sessions[0].transcript' "$TF")" = "null" ] \
    && ok "UC-5: null session_id and transcript" || bad "UC-5 nulls" "$(jq '.sessions[0]' "$TF")"
[ "$(jq '.sessions | length' "$TF")" -ge 1 ] && ok "UC-5: entry present" || bad "UC-5" "no entry"
[ "$(task_field "$R" .status)" = "done" ] && ok "UC-5: outcome unchanged" || bad "UC-5 status" "$(task_field "$R" .status)"

# --------------------------------------------------------------------------- #
printf '\nGH-53: depends-on enforcement at add and run time\n'

# Helper: write a spec with optional depends-on into a fresh repo and commit it.
fresh_repo_dep() {
    local dir="$1" dep="${2:-}"
    fresh_repo "$dir"
    {
        echo "---"
        echo "ticket: SBX-1"
        echo "title: Dep test"
        echo "status: approved"
        [ -n "$dep" ] && echo "depends-on: $dep"
        echo "---"
        echo
        echo "| id | actor | action | expected observable result | test |"
        echo "|----|-------|--------|----------------------------|------|"
        echo "| UC-1 | caller | calls Stub() | returns a non-empty string | unit |"
    } > "$dir/specs/SBX-1/spec.md"
    git -C "$dir" add -A >/dev/null
    git -C "$dir" commit -q -m "dep spec"
    git -C "$dir" update-ref refs/remotes/origin/master HEAD
}

# GH-53 UC-1: add refuses when verify-report.md is absent.
R="$WORK/dep-uc1"
fresh_repo_dep "$R" "DEP-a"
out="$("$AISDLC" add SBX-1 --repo "$R" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "GH-53 UC-1: add exits non-zero" || bad "GH-53 UC-1 exit" "expected non-zero, got $rc"
case "$out" in *DEP-a*) ok "GH-53 UC-1: output names DEP-a" ;; *) bad "GH-53 UC-1 output" "$out" ;; esac

# GH-53 UC-2: add --force queues; run refuses, sets status=refused, no implement.log.
R="$WORK/dep-uc2"
fresh_repo_dep "$R" "DEP-a"
out="$("$AISDLC" add SBX-1 --repo "$R" --no-pr --force 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "GH-53 UC-2: add --force exits 0" || bad "GH-53 UC-2 add exit" "rc=$rc"
case "$out" in *WARNING*) ok "GH-53 UC-2: WARNING in output" ;; *) bad "GH-53 UC-2 warning" "$out" ;; esac
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "refused" ] && ok "GH-53 UC-2: status refused" \
    || bad "GH-53 UC-2 status" "$(task_field "$R" .status)"
case "$(task_field "$R" .error)" in *DEP-a*) ok "GH-53 UC-2: error names DEP-a" ;; *) bad "GH-53 UC-2 error" "$(task_field "$R" .error)" ;; esac
D2="$(ls -d "$R"/.aisdlc/tasks/*/ 2>/dev/null | head -1)"
[ ! -f "${D2:-/nonexistent}/implement.log" ] && ok "GH-53 UC-2: no implement.log in task dir" \
    || bad "GH-53 UC-2 implement.log" "file exists in task dir"

# GH-53 UC-3: verify-report exists but first line is FAIL — add must refuse.
R="$WORK/dep-uc3"
fresh_repo_dep "$R" "DEP-a"
mkdir -p "$R/specs/DEP-a"
printf 'FAIL\n' > "$R/specs/DEP-a/verify-report.md"
git -C "$R" add -A >/dev/null
git -C "$R" commit -q -m "add FAIL verify-report"
git -C "$R" update-ref refs/remotes/origin/master HEAD
out="$("$AISDLC" add SBX-1 --repo "$R" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "GH-53 UC-3: add exits non-zero on FAIL report" || bad "GH-53 UC-3 exit" "rc=$rc"
case "$out" in *DEP-a*) ok "GH-53 UC-3: output names DEP-a" ;; *) bad "GH-53 UC-3 output" "$out" ;; esac

# GH-53 UC-4: two deps; DEP-a PASS, DEP-b absent — output names DEP-b but not DEP-a.
R="$WORK/dep-uc4"
fresh_repo_dep "$R" "DEP-a DEP-b"
mkdir -p "$R/specs/DEP-a"
printf 'PASS\n' > "$R/specs/DEP-a/verify-report.md"
git -C "$R" add -A >/dev/null
git -C "$R" commit -q -m "add DEP-a PASS verify-report"
git -C "$R" update-ref refs/remotes/origin/master HEAD
out="$("$AISDLC" add SBX-1 --repo "$R" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "GH-53 UC-4: add exits non-zero" || bad "GH-53 UC-4 exit" "rc=$rc"
case "$out" in *DEP-b*) ok "GH-53 UC-4: output names DEP-b" ;; *) bad "GH-53 UC-4 DEP-b" "$out" ;; esac
case "$out" in *DEP-a*) bad "GH-53 UC-4 DEP-a" "should not mention DEP-a: $out" ;; *) ok "GH-53 UC-4: output omits DEP-a" ;; esac

# GH-53 UC-5: dep PASS committed to base — add exits 0, run completes to done.
R="$WORK/dep-uc5"
fresh_repo_dep "$R" "DEP-a"
mkdir -p "$R/specs/DEP-a"
printf 'PASS\n' > "$R/specs/DEP-a/verify-report.md"
git -C "$R" add -A >/dev/null
git -C "$R" commit -q -m "add DEP-a PASS verify-report"
git -C "$R" update-ref refs/remotes/origin/master HEAD
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1 \
    && ok "GH-53 UC-5: add exits 0" || bad "GH-53 UC-5 add" "add failed"
"$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "done" ] && ok "GH-53 UC-5: status done" \
    || bad "GH-53 UC-5 status" "$(task_field "$R" .status)"
D5="$(ls -d "$R"/.aisdlc/tasks/*/ 2>/dev/null | head -1)"
[ -f "${D5:-/nonexistent}/implement.log" ] && ok "GH-53 UC-5: implement.log present in task dir" \
    || bad "GH-53 UC-5 implement.log" "missing from task dir ${D5:-none}"


# --------------------------------------------------------------------------- #
printf '\nGH-60: local tracker symlink — ship writes to repo tracker, not worktree\n'

# UC-1: symlink created and points correctly to repo canonical tracker (tested via retained worktree)
printf '\nGH-60 UC-1: symlink created and readlink resolves to repo tracker\n'
R="$WORK/gh60-uc1"; fresh_repo "$R"
mkdir -p "$R/.aisdlc/tracker" "$R/.claude"
printf '## Issue tracker\n- **Tracker descriptor:** `.claude/trackers/local.md`\n' >> "$R/.claude/sdlc.md"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_STUB=blocked "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
_TF1="$(ls -1 "$R"/.aisdlc/tasks/*/task.json 2>/dev/null | head -1)"
_WT1="$(jq -r '.worktree' "$_TF1")"
[ -L "$_WT1/.aisdlc/tracker" ] && [ "$(readlink "$_WT1/.aisdlc/tracker")" = "$R/.aisdlc/tracker" ] \
    && ok "GH-60 UC-1: symlink exists and readlink resolves to $R/.aisdlc/tracker" \
    || bad "GH-60 UC-1" "symlink missing or points elsewhere: $(readlink "$_WT1/.aisdlc/tracker" 2>/dev/null || echo 'not a symlink')"
unset _TF1 _WT1

# UC-2 + UC-3: localpr stub writes prs.jsonl at repo tracker, inbox sees PR, clean preserves exact record contents
printf '\nGH-60 UC-2,3: localpr writes prs.jsonl, inbox lists PR, clean preserves exact record contents\n'
R="$WORK/gh60-uc23"; fresh_repo "$R"
mkdir -p "$R/.aisdlc/tracker" "$R/.claude"
printf '## Issue tracker\n- **Tracker descriptor:** `.claude/trackers/local.md`\n' >> "$R/.claude/sdlc.md"
"$AISDLC" add SBX-1 --repo "$R" >/dev/null 2>&1
AISDLC_STUB=localpr "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
# UC-2 behavioral assertion: aisdlc inbox lists the shipped PR — capture once to avoid SIGPIPE race
_INBOX60="$("$AISDLC" inbox --repo "$R" 2>&1)"
grep -q 'local#1' <<< "$_INBOX60" \
    && ok "GH-60 UC-2: aisdlc inbox lists PR local#1" \
    || bad "GH-60 UC-2" "$_INBOX60"
unset _INBOX60
jq -e '.number == 1 and .url == "local#1" and .title == "SBX-1"' "$R/.aisdlc/tracker/prs.jsonl" >/dev/null \
    && ok "GH-60 UC-3: prs.jsonl record contents correct before clean" \
    || bad "GH-60 UC-3 before" "$(cat "$R/.aisdlc/tracker/prs.jsonl" 2>/dev/null)"
_WT_23="$(jq -r '.worktree' "$(ls -1 "$R"/.aisdlc/tasks/*/task.json | head -1)")"
"$AISDLC" clean --all --repo "$R" >/dev/null 2>&1
[ ! -d "$_WT_23" ] \
    && ok "GH-60 UC-3: worktree removed after clean" \
    || bad "GH-60 UC-3 wt" "worktree still exists: $_WT_23"
jq -e '.number == 1 and .url == "local#1" and .title == "SBX-1"' "$R/.aisdlc/tracker/prs.jsonl" >/dev/null \
    && ok "GH-60 UC-3: prs.jsonl exact record contents retained at repo tracker after clean" \
    || bad "GH-60 UC-3 after" "$(cat "$R/.aisdlc/tracker/prs.jsonl" 2>/dev/null)"
unset _WT_23

# UC-4: tracker dir absent — mkdir creates it, then symlinked (verified via readlink on retained worktree)
printf '\nGH-60 UC-4: tracker dir absent → created by runner and symlinked\n'
R="$WORK/gh60-uc4"; fresh_repo "$R"
mkdir -p "$R/.claude"
printf '## Issue tracker\n- **Tracker descriptor:** `.claude/trackers/local.md`\n' >> "$R/.claude/sdlc.md"
# Intentionally no $R/.aisdlc/tracker yet
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_STUB=blocked "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ -d "$R/.aisdlc/tracker" ] \
    && ok "GH-60 UC-4: $R/.aisdlc/tracker/ created by runner" \
    || bad "GH-60 UC-4 mkdir" "directory absent after run"
_TF4="$(ls -1 "$R"/.aisdlc/tasks/*/task.json 2>/dev/null | head -1)"
_WT4="$(jq -r '.worktree' "$_TF4")"
[ -L "$_WT4/.aisdlc/tracker" ] && [ "$(readlink "$_WT4/.aisdlc/tracker")" = "$R/.aisdlc/tracker" ] \
    && ok "GH-60 UC-4: absent tracker dir created and symlinked correctly" \
    || bad "GH-60 UC-4 link" "symlink missing or incorrect"
unset _TF4 _WT4

# UC-5: symlink creation step fails → task=failed, .error set, run.log records it, worktree kept
printf '\nGH-60 UC-5: symlink failure → task failed, error set, worktree retained\n'
R="$WORK/gh60-uc5"; fresh_repo "$R"
mkdir -p "$R/.aisdlc/tracker" "$R/.claude"
printf '## Issue tracker\n- **Tracker descriptor:** `.claude/trackers/local.md`\n' >> "$R/.claude/sdlc.md"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
# Inject a failing ln wrapper (fails only when called as ln -sfn)
_LN_BIN="$WORK/gh60-uc5-bin"
mkdir -p "$_LN_BIN"
printf '#!/bin/sh\nif [ "${1:-}" = "-sfn" ]; then exit 1; fi\nexec /bin/ln "$@"\n' > "$_LN_BIN/ln"
chmod +x "$_LN_BIN/ln"
AISDLC_ARCHIVE="$WORK/gh60-archive" PATH="$_LN_BIN:$PATH" "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "failed" ] \
    && ok "GH-60 UC-5: task status is failed" \
    || bad "GH-60 UC-5 status" "$(task_field "$R" .status)"
jq -e '.status == "failed"' "$WORK/gh60-archive/index.jsonl" >/dev/null 2>&1 \
    && ok "GH-60 UC-5: tracker-link failure archived" || bad "GH-60 archive" "terminal record missing"
_TF5="$(ls -1 "$R"/.aisdlc/tasks/*/task.json 2>/dev/null | head -1)"
jq -e '.error' "$_TF5" 2>/dev/null | grep -qi 'symlink' \
    && ok "GH-60 UC-5: .error field mentions symlink failure" \
    || bad "GH-60 UC-5 error" "$(jq -r '.error // empty' "$_TF5" 2>/dev/null)"
_WT5="$(jq -r '.worktree' "$_TF5")"
[ -d "$_WT5" ] \
    && ok "GH-60 UC-5: worktree directory retained after symlink failure" \
    || bad "GH-60 UC-5 wt" "worktree absent: $_WT5"
_D5="$(dirname "$_TF5")/"
grep -q 'symlink failed' "$_D5/run.log" 2>/dev/null \
    && ok "GH-60 UC-5: run.log records symlink failure" \
    || bad "GH-60 UC-5 log" "$(cat "$_D5/run.log" 2>/dev/null | tail -3)"
[ ! -f "$_D5/implement.log" ] \
    && ok "GH-60 UC-5: implement phase never invoked" \
    || bad "GH-60 UC-5 nophase" "implement.log found — phase ran after symlink failure"
unset _LN_BIN _TF5 _WT5 _D5

# UC-6: github tracker → no symlink created in worktree, task proceeds normally
printf '\nGH-60 UC-6: github tracker → no symlink in worktree\n'
R="$WORK/gh60-uc6"; fresh_repo "$R"
mkdir -p "$R/.claude"
printf '## Issue tracker\n- **Tracker descriptor:** `.claude/trackers/github.md`\n' >> "$R/.claude/sdlc.md"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_STUB=blocked "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
_TF6="$(ls -1 "$R"/.aisdlc/tasks/*/task.json 2>/dev/null | head -1)"
_WT6="$(jq -r '.worktree' "$_TF6")"
[ ! -L "$_WT6/.aisdlc/tracker" ] && [ ! -e "$_WT6/.aisdlc/tracker" ] \
    && ok "GH-60 UC-6: no symlink or tracker dir created in worktree for github tracker" \
    || bad "GH-60 UC-6" "unexpected symlink or tracker dir at $_WT6/.aisdlc/tracker"
unset _TF6 _WT6
# archive tests — UC-6 through UC-13 (GH-43-b)
# --------------------------------------------------------------------------- #

# Helper: archive slug for a repo absolute path.
arc_slug() { local p; p="$(cd "$1" && pwd)"; printf '%s-%s' "$(basename "$p")" "$(printf '%s' "$p" | sha256sum | cut -c1-8)"; }

printf '\narchive: done task writes archive dir, manifest, task.json, phases, spec (UC-6)\n'
R_ARC6="$WORK/arc-uc6"; ARC6="$WORK/arc-uc6-root"
fresh_repo "$R_ARC6"
"$AISDLC" add SBX-1 --repo "$R_ARC6" --no-pr >/dev/null 2>&1
AISDLC_ARCHIVE="$ARC6" "$AISDLC" run --repo "$R_ARC6" --once >/dev/null 2>&1
[ "$(task_field "$R_ARC6" .status)" = "done" ] && ok "UC-6: task done" || bad "UC-6 pre" "status $(task_field "$R_ARC6" .status)"
_ARC6_ID="$(ls -1 "$R_ARC6/.aisdlc/tasks" | head -1)"
_ARC6_SLUG="$(arc_slug "$R_ARC6")"
_ARC6_DIR="$ARC6/$_ARC6_SLUG/$(date -u +%Y-%m)/$_ARC6_ID"
[ -d "$_ARC6_DIR" ] && ok "UC-6: archive dir created" || bad "UC-6 dir" "not found: $_ARC6_DIR"
[ -f "$_ARC6_DIR/manifest.json" ] && ok "UC-6: manifest.json present" || bad "UC-6 manifest" "missing"
[ -f "$_ARC6_DIR/task.json" ] && ok "UC-6: task.json present" || bad "UC-6 task.json" "missing"
[ -f "$_ARC6_DIR/phases/implement.log" ] && ok "UC-6: phases/implement.log present" || bad "UC-6 impl.log" "missing"
[ -f "$_ARC6_DIR/spec/spec.md" ] && ok "UC-6: spec/spec.md present" || bad "UC-6 spec.md" "missing"
[ -f "$_ARC6_DIR/spec/qa-report.md" ] && ok "UC-6: spec/qa-report.md present" || bad "UC-6 qa-report" "missing"
# Every file in manifest.files has sha256sum that matches.
_arc6_hash_ok=1; _arc6_bad=""
while IFS= read -r _ent; do
    _rel="$(printf '%s' "$_ent" | jq -r '.key')"; _exp="$(printf '%s' "$_ent" | jq -r '.value')"
    _act="$(sha256sum "$_ARC6_DIR/$_rel" 2>/dev/null | cut -c1-64)"
    [ "$_exp" = "$_act" ] || { _arc6_hash_ok=0; _arc6_bad="$_rel"; break; }
done < <(jq -c '.files | to_entries[]' "$_ARC6_DIR/manifest.json" 2>/dev/null)
[ "$_arc6_hash_ok" -eq 1 ] && ok "UC-6: sha256sum of every file matches manifest.files" \
    || bad "UC-6 sha256" "mismatch on $_arc6_bad"
# Verify individual manifest fields required by spec are present.
jq -e 'has("policy_fingerprint") and has("aisdlc_version") and has("archived_at") and
        has("runtime_version") and has("sessions") and has("attempts")' \
    "$_ARC6_DIR/manifest.json" >/dev/null 2>&1 \
    && ok "UC-6: manifest has required fields (policy_fingerprint, aisdlc_version, archived_at, runtime_version, sessions, attempts)" \
    || bad "UC-6 manifest-fields" "$(jq 'keys' "$_ARC6_DIR/manifest.json" 2>/dev/null)"


printf '\narchive: index.jsonl gains exactly one line with id, status, path (UC-7)\n'
[ -f "$ARC6/index.jsonl" ] && ok "UC-7: index.jsonl created" || bad "UC-7 index" "missing"
[ "$(wc -l < "$ARC6/index.jsonl" | tr -d ' ')" -eq 1 ] \
    && ok "UC-7: exactly one line" || bad "UC-7 lines" "$(wc -l < "$ARC6/index.jsonl" | tr -d ' ') lines"
jq -e --arg id "$_ARC6_ID" --arg p "$_ARC6_DIR" \
    'select(.id == $id and .status == "done" and .path == $p)' \
    "$ARC6/index.jsonl" >/dev/null 2>&1 \
    && ok "UC-7: index has id, status done, correct path" \
    || bad "UC-7 entry" "$(cat "$ARC6/index.jsonl" 2>/dev/null)"

printf '\narchive: anthropic key in phase log is redacted; live log unchanged (UC-8)\n'
R="$WORK/arc-uc8"; ARC8="$WORK/arc-uc8-root"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_ARCHIVE="$ARC8" AISDLC_STUB=keyleak "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "done" ] && ok "UC-8: task done" || bad "UC-8 pre" "status $(task_field "$R" .status)"
_ARC8_ID="$(ls -1 "$R/.aisdlc/tasks" | head -1)"
_ARC8_DIR="$ARC8/$(arc_slug "$R")/$(date -u +%Y-%m)/$_ARC8_ID"
grep -q '\[REDACTED:anthropic-key\]' "$_ARC8_DIR/phases/implement.log" 2>/dev/null \
    && ok "UC-8: archived log has [REDACTED:anthropic-key]" \
    || bad "UC-8 redacted" "$(grep 'sk-ant\|REDACT' "$_ARC8_DIR/phases/implement.log" 2>/dev/null | head -1)"
grep -q 'sk-ant-' "$R/.aisdlc/tasks/$_ARC8_ID/implement.log" 2>/dev/null \
    && ok "UC-8: live log unchanged (key still present)" \
    || bad "UC-8 live" "key not in live log"
jq -e '(.redactions["anthropic-key"] // 0) >= 1' "$_ARC8_DIR/manifest.json" >/dev/null 2>&1 \
    && ok "UC-8: manifest.redactions[anthropic-key] >= 1" \
    || bad "UC-8 count" "$(jq '.redactions' "$_ARC8_DIR/manifest.json" 2>/dev/null)"

printf '\narchive: failed task archived with status failed and BLOCKED.md (UC-9)\n'
R_ARC9="$WORK/arc-uc9"; ARC9="$WORK/arc-uc9-root"
fresh_repo "$R_ARC9"
"$AISDLC" add SBX-1 --repo "$R_ARC9" --no-pr >/dev/null 2>&1
AISDLC_ARCHIVE="$ARC9" AISDLC_STUB=blocked "$AISDLC" run --repo "$R_ARC9" --once >/dev/null 2>&1
[ "$(task_field "$R_ARC9" .status)" = "failed" ] && ok "UC-9: task failed" || bad "UC-9 pre" "status $(task_field "$R_ARC9" .status)"
_ARC9_ID="$(ls -1 "$R_ARC9/.aisdlc/tasks" | head -1)"
_ARC9_DIR="$ARC9/$(arc_slug "$R_ARC9")/$(date -u +%Y-%m)/$_ARC9_ID"
[ -d "$_ARC9_DIR" ] && ok "UC-9: archive dir created for failed task" || bad "UC-9 dir" "missing"
jq -e '.status == "failed"' "$_ARC9_DIR/manifest.json" >/dev/null 2>&1 \
    && ok "UC-9: manifest status is failed" || bad "UC-9 status" "$(jq -r '.status' "$_ARC9_DIR/manifest.json" 2>/dev/null)"
[ -f "$_ARC9_DIR/spec/BLOCKED.md" ] \
    && ok "UC-9: spec/BLOCKED.md in archive" || bad "UC-9 BLOCKED.md" "missing"
[ -f "$_ARC9_DIR/spec/spec.md" ] \
    && ok "UC-9: spec/spec.md in archive (worktree spec/ reports present)" \
    || bad "UC-9 spec.md" "spec/spec.md missing from archive"


printf '\narchive: refused task archives BLOCKED.md before worktree removal (UC-10)\n'
R="$WORK/arc-uc10"; ARC10="$WORK/arc-uc10-root"
fresh_repo "$R"
mkdir -p "$R/.aisdlc/tracker/issues" "$R/.claude"
cat > "$R/.aisdlc/tracker/issues/42.md" <<'ARCISSUE'
---
number: 42
title: archive test issue
state: open
labels: [bug]
assignees: []
---
## Comments
ARCISSUE
printf -- '- **Tracker descriptor:** `.claude/trackers/local.md`\n' > "$R/.claude/sdlc.md"
AISDLC_ARCHIVE="$ARC10" AISDLC_STUB=refuse-blocked "$AISDLC" add --issue 42 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_ARCHIVE="$ARC10" AISDLC_STUB=refuse-blocked "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "refused" ] \
    && ok "UC-10: task refused" || bad "UC-10 status" "$(task_field "$R" .status)"
_ARC10_ID="$(ls -1 "$R/.aisdlc/tasks" | head -1)"
_ARC10_DIR="$ARC10/$(arc_slug "$R")/$(date -u +%Y-%m)/$_ARC10_ID"
[ -d "$_ARC10_DIR" ] && ok "UC-10: archive dir for refused task" || bad "UC-10 dir" "missing"
[ -f "$_ARC10_DIR/spec/BLOCKED.md" ] \
    && ok "UC-10: spec/BLOCKED.md copied before worktree removal" || bad "UC-10 BLOCKED.md" "missing"

printf '\narchive: clean --all leaves archive byte-identical (UC-11)\n'
before_arc_lines="$(wc -l < "$ARC6/index.jsonl" | tr -d ' ')"
before_arc_files="$(find "$ARC6" -type f | sort | sha256sum)"
"$AISDLC" clean --all --repo "$R_ARC6" >/dev/null 2>&1
after_arc_lines="$(wc -l < "$ARC6/index.jsonl" | tr -d ' ')"
after_arc_files="$(find "$ARC6" -type f | sort | sha256sum)"
[ "$before_arc_lines" = "$after_arc_lines" ] \
    && ok "UC-11: index.jsonl unchanged after clean --all" || bad "UC-11 index" "changed"
[ "$before_arc_files" = "$after_arc_files" ] \
    && ok "UC-11: archive files unchanged after clean --all" || bad "UC-11 files" "changed"

printf '\narchive: AISDLC_ARCHIVE=off creates no archive and no index (UC-12)\n'
R="$WORK/arc-uc12"
fresh_repo "$R"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_ARCHIVE=off "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "done" ] && ok "UC-12: task completes" || bad "UC-12 pre" "status $(task_field "$R" .status)"
_ARC12_SLUG="$(arc_slug "$R")"
_ARC12_DEFAULT="${XDG_DATA_HOME:-$HOME/.local/share}/aisdlc/archive"
[ ! -d "$_ARC12_DEFAULT/$_ARC12_SLUG" ] \
    && ok "UC-12: no archive dir created with AISDLC_ARCHIVE=off" \
    || bad "UC-12 dir" "archive created at default root"
_ARC12_ID="$(ls -1 "$R/.aisdlc/tasks" | head -1)"
! grep -q "\"id\":\"$_ARC12_ID\"" "$_ARC12_DEFAULT/index.jsonl" 2>/dev/null \
    && ok "UC-12: no index.jsonl entry for task with AISDLC_ARCHIVE=off" \
    || bad "UC-12 index-entry" "index.jsonl contains task $_ARC12_ID despite AISDLC_ARCHIVE=off"
unset _ARC12_SLUG _ARC12_DEFAULT _ARC12_ID

printf '\narchive: retry creates <id>.<attempts> dir; first archive unchanged (UC-13)\n'
# Reuse UC-9 repo (failed task, worktree kept) — retry it so it reaches done.
_ARC13_FIRST="$_ARC9_DIR"
_first_snap="$(find "$_ARC13_FIRST" -type f | sort | sha256sum)"
"$AISDLC" retry "$_ARC9_ID" --repo "$R_ARC9" >/dev/null 2>&1
AISDLC_ARCHIVE="$ARC9" "$AISDLC" run --repo "$R_ARC9" --once >/dev/null 2>&1
[ "$(task_field "$R_ARC9" .status)" = "done" ] \
    && ok "UC-13: retried task reaches done" || bad "UC-13 status" "$(task_field "$R_ARC9" .status)"
_ARC13_SECOND="$ARC9/$(arc_slug "$R_ARC9")/$(date -u +%Y-%m)/${_ARC9_ID}.2"
[ -d "$_ARC13_SECOND" ] \
    && ok "UC-13: second archive dir <id>.2 created" || bad "UC-13 retry dir" "missing: $_ARC13_SECOND"
_after_snap="$(find "$_ARC13_FIRST" -type f | sort | sha256sum)"
[ "$_first_snap" = "$_after_snap" ] \
    && ok "UC-13: first archive dir unchanged after retry" || bad "UC-13 unchanged" "first archive modified"
_arc13_lines="$(jq -s --arg id "$_ARC9_ID" '[.[] | select(.id == $id)] | length' "$ARC9/index.jsonl" 2>/dev/null)"
[ "${_arc13_lines:-0}" -ge 2 ] \
    && ok "UC-13: two index.jsonl entries for the id" || bad "UC-13 index" "$_arc13_lines entries"

printf '\narchive: unwritable root is non-fatal — task still reaches done\n'
R="$WORK/arc-nonfatal"; fresh_repo "$R"
_ARC_CONFLICT="$WORK/arc-conflict-file"
printf 'not-a-dir\n' > "$_ARC_CONFLICT"   # file at archive root blocks mkdir
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_ARCHIVE="$_ARC_CONFLICT" "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
[ "$(task_field "$R" .status)" = "done" ] \
    && ok "non-fatal archive: task done despite unwritable archive root" \
    || bad "non-fatal archive" "status $(task_field "$R" .status)"
_nf_id="$(ls -1 "$R/.aisdlc/tasks" | head -1)"
grep -q 'archive failed' "$R/.aisdlc/tasks/$_nf_id/run.log" 2>/dev/null \
    && ok "non-fatal archive: failure logged to run.log" \
    || bad "non-fatal archive log" "no 'archive failed' in run.log"
unset _ARC_CONFLICT _nf_id
printf '\narchive: cancelled task creates archive dir and index entry (non-functional)\n'
R_CANCEL="$WORK/arc-cancel"; ARC_CANCEL="$WORK/arc-cancel-root"
fresh_repo "$R_CANCEL"
"$AISDLC" add SBX-1 --repo "$R_CANCEL" --no-pr >/dev/null 2>&1
_CANCEL_ID="$(ls -1 "$R_CANCEL/.aisdlc/tasks" | head -1)"
AISDLC_ARCHIVE="$ARC_CANCEL" "$AISDLC" cancel "$_CANCEL_ID" --repo "$R_CANCEL" >/dev/null 2>&1
[ "$(task_field "$R_CANCEL" .status)" = "cancelled" ] \
    && ok "archive/cancel: task status is cancelled" \
    || bad "archive/cancel status" "$(task_field "$R_CANCEL" .status)"
_CANCEL_SLUG="$(arc_slug "$R_CANCEL")"
_CANCEL_DIR="$ARC_CANCEL/$_CANCEL_SLUG/$(date -u +%Y-%m)/$_CANCEL_ID"
[ -d "$_CANCEL_DIR" ] \
    && ok "archive/cancel: archive dir created for cancelled task" \
    || bad "archive/cancel dir" "not found: $_CANCEL_DIR"
jq -e '.status == "cancelled"' "$_CANCEL_DIR/manifest.json" >/dev/null 2>&1 \
    && ok "archive/cancel: manifest status is cancelled" \
    || bad "archive/cancel manifest" "$(jq -r '.status' "$_CANCEL_DIR/manifest.json" 2>/dev/null)"
jq -e --arg id "$_CANCEL_ID" 'select(.id == $id and .status == "cancelled")' \
    "$ARC_CANCEL/index.jsonl" >/dev/null 2>&1 \
    && ok "archive/cancel: index.jsonl entry with status cancelled" \
    || bad "archive/cancel index" "$(cat "$ARC_CANCEL/index.jsonl" 2>/dev/null)"

printf '\narchive: retry after cancellation before first execution is append-only (UC-13)\n'
_cancel_hash="$(sha256sum "$_CANCEL_DIR/manifest.json")"
"$AISDLC" retry "$_CANCEL_ID" --repo "$R_CANCEL" >/dev/null 2>&1
AISDLC_ARCHIVE="$ARC_CANCEL" "$AISDLC" run --repo "$R_CANCEL" --once >/dev/null 2>&1
[ "$_cancel_hash" = "$(sha256sum "$_CANCEL_DIR/manifest.json")" ] \
    && ok "UC-13: attempt zero archive survives first execution" || bad "UC-13 zero" "original overwritten"
jq -e '.attempts == 1 and .status == "done"' "${_CANCEL_DIR}.1/manifest.json" >/dev/null 2>&1 \
    && ok "UC-13: first execution gets separate archive" || bad "UC-13 first" "missing attempt one"

printf '\narchive: missing seed spec is archived as failed (UC-9)\n'
R="$WORK/arc-missing-spec"; fresh_repo "$R"; _SEC_ROOT="$WORK/arc-missing-root"
"$AISDLC" add MISSING-1 --force --repo "$R" --no-pr >/dev/null 2>&1
AISDLC_ARCHIVE="$_SEC_ROOT" "$AISDLC" run --repo "$R" --once >/dev/null 2>&1
_missing_manifest="$(find "$_SEC_ROOT" -name manifest.json 2>/dev/null)"
jq -e '.status == "failed"' "$_missing_manifest" >/dev/null 2>&1 \
    && ok "UC-9: seed_spec failure archived" || bad "UC-9 seed" "failed task has no archive"

printf '\narchive: all built-in redaction forms and publication failures (UC-8)\n'
_SEC="$WORK/arc-security"; mkdir -p "$_SEC"
cat > "$_SEC/source" <<'SECRETS'
-----BEGIN PRIVATE KEY-----
fake-pem-body
-----END PRIVATE KEY-----
-----BEGIN RSA PRIVATE KEY-----
fake-rsa-body
-----END RSA PRIVATE KEY-----
TOKEN=fake-token-value
SECRET=fake-secret-value
PASSWORD=fake-password-value
API_KEY=fake-api-value
PRIVATE_KEY=fake-private-value
SECRETS
_sec_counts="$(bash -c 'source "$1"; _arc_redact "$2" "$3"' _ "$AISDLC" "$_SEC/source" "$_SEC/redacted")"
! grep -q 'fake-' "$_SEC/redacted" && jq -e '.["pem-private-key"] == 2 and .["env-secret"] == 5' <<< "$_sec_counts" >/dev/null 2>&1 \
    && ok "UC-8: PEM and bare secret assignments redacted and counted" || bad "UC-8 forms" "secret survived or count wrong"
printf 'sk-ant-api03-abcdefABCDEF0123456789abcdefABCDEF0123456789\n' > "$_SEC/token"
if bash -c 'source "$1"; sed() { return 1; }; _arc_redact "$2" "$3"' _ \
    "$AISDLC" "$_SEC/token" "$_SEC/failed" >/dev/null 2>&1; then
    bad "UC-8 fail closed" "redaction error reported success"
else
    [ ! -e "$_SEC/failed" ] && ok "UC-8: transform failure publishes no destination" || bad "UC-8 failed output" "destination exists"
fi
bash -c 'umask 022; source "$1"; marker="$4"; sed() { stat -c "%a" "${@: -1}" > "$marker"; command sed "$@"; }; _arc_redact "$2" "$3"' \
    _ "$AISDLC" "$_SEC/token" "$_SEC/private" "$_SEC/mode" >/dev/null 2>&1
[ "$(cat "$_SEC/mode")" = "600" ] && ok "UC-8: raw staging file is private" || bad "UC-8 permissions" "raw staging readable by others"

R="$WORK/arc-metadata"; fresh_repo "$R"; _META_ROOT="$WORK/arc-metadata-root"
"$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1
_meta_id="$(task_field "$R" .id)"; _meta_tf="$R/.aisdlc/tasks/$_meta_id/task.json"
jq '.pr_url = "https://ghp_abcdefghijklmnopqrst@github.com/example/repo/pull/1"' "$_meta_tf" > "$_meta_tf.tmp" && mv "$_meta_tf.tmp" "$_meta_tf"
AISDLC_ARCHIVE="$_META_ROOT" "$AISDLC" cancel "$_meta_id" --repo "$R" >/dev/null 2>&1
_meta_manifest="$(find "$_META_ROOT" -name manifest.json)"
! grep -q 'ghp_abcdefghijklmnopqrst' "$_meta_manifest" \
    && jq -e '.pr_url | contains("[REDACTED:github-token]")' "$_meta_manifest" >/dev/null 2>&1 \
    && ok "UC-8: manifest uses redacted metadata" || bad "UC-8 metadata" "manifest restored secret"
_FAILED_ROOT="$WORK/arc-transform-failed"
AISDLC_ARCHIVE="$_FAILED_ROOT" bash -c 'sed() { return 1; }; export -f sed; exec "$@"' \
    _ "$AISDLC" cancel "$_meta_id" --repo "$R" >/dev/null 2>&1
[ ! -e "$_FAILED_ROOT/index.jsonl" ] && [ -z "$(find "$_FAILED_ROOT" -type f)" ] \
    && [ "$(task_field "$R" .status)" = "cancelled" ] \
    && ok "UC-8: archive failure publishes nothing and preserves task outcome" \
    || bad "UC-8 publication" "failed redaction published files or changed task outcome"
unset R_CANCEL ARC_CANCEL _CANCEL_ID _CANCEL_SLUG _CANCEL_DIR

# --------------------------------------------------------------------------- #
# GH-40: readiness gate
# Helper: set readiness_min in repo config (one-line vs. repeated jq/mv).
rdy_setup() { local d="$1" v="$2"
    jq --argjson v "$v" '.readiness_min = $v' "$d/.aisdlc/config.json" > "$d/.aisdlc/config.json.tmp" \
        && mv "$d/.aisdlc/config.json.tmp" "$d/.aisdlc/config.json"; }

printf '\nGH-40 UC-1: absent and null readiness_min are no-ops\n'
R="$WORK/ready-off"; fresh_repo "$R"
AISDLC_STUB_READINESS='should-not-be-called' "$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1 \
    && ok "UC-1 absent: add succeeds" || bad "UC-1 absent" "add failed"
[ "$(task_field "$R" .readiness_score)" = "" ] \
    && ok "UC-1 absent: no readiness_score" || bad "UC-1 score" "$(task_field "$R" .readiness_score)"
rdy_setup "$R" null
AISDLC_STUB_READINESS='should-not-be-called' "$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1 \
    && ok "UC-1 null: add succeeds" || bad "UC-1 null" "add failed"

printf '\nGH-40 UC-2/3: below threshold blocks; --force bypasses with score\n'
R="$WORK/ready-fail"; fresh_repo "$R"; rdy_setup "$R" 80
_RDY_GAP='## Acceptance criteria: rows are not checkable'
AISDLC_STUB_READINESS="{\"score\":60,\"gaps\":[\"$_RDY_GAP\"]}" \
    "$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1 \
    && bad "UC-2" "should exit non-zero" || ok "UC-2: exits non-zero (60 < 80)"
[ "$(wc -l < "$R/.aisdlc/queue.jsonl" | tr -d ' ')" -eq 0 ] \
    && ok "UC-2: queue empty" || bad "UC-2 queue" "not empty"
[ -f "$R/specs/SBX-1/readiness.md" ] \
    && ok "UC-2: readiness.md created" || bad "UC-2 rmd" "not written"
grep -q "$_RDY_GAP" "$R/specs/SBX-1/readiness.md" 2>/dev/null \
    && ok "UC-2: gap in readiness.md" || bad "UC-2 gap" "not found"
out="$(AISDLC_STUB_READINESS="{\"score\":60,\"gaps\":[\"$_RDY_GAP\"]}" \
    "$AISDLC" add SBX-1 --repo "$R" --no-pr --force 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "UC-3: --force exits zero" || bad "UC-3 exit" "rc=$rc"
printf '%s' "$out" | grep -qi 'warning' && ok "UC-3: warning printed" || bad "UC-3 warn" "$out"
printf '%s' "$out" | grep -q '60' && ok "UC-3: warning names score" || bad "UC-3 score" "$out"
[ "$(wc -l < "$R/.aisdlc/queue.jsonl" | tr -d ' ')" -gt 0 ] \
    && ok "UC-3: task queued" || bad "UC-3 queue" "not queued"
[ "$(task_field "$R" .readiness_score)" = "60" ] \
    && ok "UC-3: readiness_score:60" || bad "UC-3 field" "$(task_field "$R" .readiness_score)"

printf '\nGH-40 UC-4/5: above threshold queues; status shows READY\n'
R="$WORK/ready-pass"; fresh_repo "$R"; rdy_setup "$R" 80
AISDLC_STUB_READINESS='{"score":85,"gaps":[]}' \
    "$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1 \
    && ok "UC-4: add succeeds (85 >= 80)" || bad "UC-4" "add failed"
[ "$(task_field "$R" .readiness_score)" = "85" ] \
    && ok "UC-4: readiness_score:85" || bad "UC-4 score" "$(task_field "$R" .readiness_score)"
[ ! -f "$R/specs/SBX-1/readiness.md" ] \
    && ok "UC-4: no readiness.md on pass" || bad "UC-4 rmd" "written"
_sts="$("$AISDLC" status --repo "$R" 2>/dev/null)"
printf '%s' "$_sts" | grep -q 'READY' && ok "UC-5: READY column in header" || bad "UC-5 hdr" "$_sts"
printf '%s' "$_sts" | grep -q '85' && ok "UC-5: score 85 in status" || bad "UC-5 score" "$_sts"

printf '\nGH-40 UC-6: non-JSON fails closed; --force queues without score\n'
R="$WORK/ready-bad"; fresh_repo "$R"; rdy_setup "$R" 80
AISDLC_STUB_READINESS='not valid json' "$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1 \
    && bad "UC-6" "should exit non-zero" || ok "UC-6: parse failure exits non-zero"
[ "$(wc -l < "$R/.aisdlc/queue.jsonl" | tr -d ' ')" -eq 0 ] \
    && ok "UC-6: queue empty" || bad "UC-6 queue" "not empty"
AISDLC_STUB_READINESS='not valid json' \
    "$AISDLC" add SBX-1 --repo "$R" --no-pr --force >/dev/null 2>&1 \
    && ok "UC-6: --force queues despite parse failure" || bad "UC-6 force" "failed"
[ "$(task_field "$R" .readiness_score)" = "" ] \
    && ok "UC-6: no readiness_score after parse failure" \
    || bad "UC-6 no-score" "$(task_field "$R" .readiness_score)"

printf '\nGH-40 UC-7: --issue route skips readiness\n'
R="$WORK/ready-issue"; fresh_repo "$R"; rdy_setup "$R" 80
mkdir -p "$R/.aisdlc/tracker/issues" "$R/.claude"
cat > "$R/.aisdlc/tracker/issues/42.md" <<'ISSUE'
---
number: 42
title: selftest bug
state: open
labels: [bug]
assignees: []
author: selftest
created: 2026-10-01T00:00:00Z
---
Test issue.

## Comments
ISSUE
printf '## Issue tracker\n- **Tracker descriptor:** `.claude/trackers/local.md`\n' > "$R/.claude/sdlc.md"
AISDLC_STUB_READINESS='invalid-would-fail' \
    "$AISDLC" add --issue 42 --repo "$R" >/dev/null 2>&1 \
    && ok "UC-7: --issue skips readiness" || bad "UC-7" "--issue failed"
[ ! -f "$R/specs/GH-42/readiness.md" ] \
    && ok "UC-7: no readiness.md for --issue" || bad "UC-7 rmd" "written"

printf '\nGH-40: fail-closed boundaries (fraction, non-string gap, process rc, error envelope)\n'
R="$WORK/ready-bounds"; fresh_repo "$R"; rdy_setup "$R" 80
AISDLC_STUB_READINESS='{"score":85.5,"gaps":[]}' \
    "$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1 \
    && bad "fraction" "85.5 should reject" || ok "fraction: 85.5 rejected"
[ "$(wc -l < "$R/.aisdlc/queue.jsonl" | tr -d ' ')" -eq 0 ] \
    && ok "fraction: queue empty" || bad "fraction queue" "queued"
AISDLC_STUB_READINESS='{"score":85,"gaps":[7]}' \
    "$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1 \
    && bad "nonstring gap" "[7] should reject" || ok "nonstring gap: [7] rejected"
[ "$(wc -l < "$R/.aisdlc/queue.jsonl" | tr -d ' ')" -eq 0 ] \
    && ok "nonstring gap: queue empty" || bad "nonstring gap queue" "queued"
AISDLC_STUB_READINESS='{"score":85,"gaps":[]}' READINESS_FAIL_EXIT=1 \
    "$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1 \
    && bad "failed-process" "rc=1 should reject" || ok "failed-process: rc=1 rejected"
[ "$(wc -l < "$R/.aisdlc/queue.jsonl" | tr -d ' ')" -eq 0 ] \
    && ok "failed-process: queue empty" || bad "failed-process queue" "queued"
AISDLC_STUB_READINESS='{"score":85,"gaps":[]}' READINESS_ERROR_ENVELOPE=true \
    "$AISDLC" add SBX-1 --repo "$R" --no-pr >/dev/null 2>&1 \
    && bad "error-envelope" "is_error:true should reject" || ok "error-envelope: is_error:true rejected"
[ "$(wc -l < "$R/.aisdlc/queue.jsonl" | tr -d ' ')" -eq 0 ] \
    && ok "error-envelope: queue empty" || bad "error-envelope queue" "queued"

printf '\nGH-40: omp runtime — readiness check via omp stub\n'
R="$WORK/ready-omp"; fresh_repo "$R"; rdy_setup "$R" 80
AISDLC_STUB_READINESS='{"score":82,"gaps":[]}' \
    "$AISDLC" add SBX-1 --repo "$R" --no-pr --runtime omp >/dev/null 2>&1 \
    && ok "omp: add succeeds (82 >= 80)" || bad "omp" "add failed"
[ "$(task_field "$R" .readiness_score)" = "82" ] \
    && ok "omp: readiness_score:82" || bad "omp score" "$(task_field "$R" .readiness_score)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
