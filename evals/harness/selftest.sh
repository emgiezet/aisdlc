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
printf '\nartifacts_exist scorer: present file passes, missing file fails\n'
_AEDIR="$WORK/aexist"
mkdir -p "$_AEDIR"
_AEPNG="specs/SBX-4/qa/UC-1.png"
# absent → check must detect failure
if [ -f "$_AEDIR/$_AEPNG" ] && [ -s "$_AEDIR/$_AEPNG" ]; then
    bad "artifacts_exist absent" "file should not exist yet"
else
    ok "absent artifact correctly detected as missing"
fi
# present and non-empty → check must pass
mkdir -p "$_AEDIR/specs/SBX-4/qa"
printf 'PNG' > "$_AEDIR/$_AEPNG"
if [ -f "$_AEDIR/$_AEPNG" ] && [ -s "$_AEDIR/$_AEPNG" ]; then
    ok "present non-empty artifact correctly detected"
else
    bad "artifacts_exist present" "file exists but check failed"
fi
unset _AEDIR _AEPNG
# --------------------------------------------------------------------------- #
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
rm -rf "$WORK"
