#!/usr/bin/env bash
# write_test.sh — standalone tests for the pre-write hook policy.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
: "${CLAUDE_PLUGIN_ROOT:=$PLUGIN_ROOT}"

HOOK="${PLUGIN_ROOT}/hooks/pre-write"
CONTRACT="${TESTS_DIR}/hook-contract"

# Mock betterleaks: detect "hunter2" and output a dummy finding.
# We expect betterleaks to be in PATH or local directory.
export PATH="${TESTS_DIR}:${PATH}"

[ -x "$HOOK" ] || { printf 'FATAL: %s is not executable\n' "$HOOK" >&2; exit 1; }

PASS=0
FAIL=0

ok()  { printf '  ok    %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# run_hook <fixture-path>
run_hook() {
    HOOK_OUTPUT="$("$HOOK" < "$1" 2>/dev/null)"
    HOOK_EXIT=$?
}

last_decision() {
    if [ -z "$HOOK_OUTPUT" ]; then
        printf 'allow'
    else
        printf '%s' "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision // "allow"'
    fi
}

assert_deny() {
    local label="$1" fixture="$2"
    run_hook "$fixture"
    local got; got="$(last_decision)"
    [ "$got" = "deny" ] \
        && ok  "deny: $label" \
        || bad "deny: $label" "expected deny, got '${got}' (exit=${HOOK_EXIT})"
}

assert_ask() {
    local label="$1" fixture="$2"
    run_hook "$fixture"
    local got; got="$(last_decision)"
    [ "$got" = "ask" ] \
        && ok  "ask: $label" \
        || bad "ask: $label" "expected ask, got '${got}' (exit=${HOOK_EXIT})"
}

assert_allow() {
    local label="$1" fixture="$2"
    run_hook "$fixture"
    local got; got="$(last_decision)"
    [ $HOOK_EXIT -eq 0 ] && [ "$got" = "allow" ] \
        && ok  "allow: $label" \
        || bad "allow: $label" "expected allow (exit 0, no deny/ask), got '${got}' exit=${HOOK_EXIT}"
}

printf 'pre-write hook tests\n\n'

assert_deny "secret content" "${CONTRACT}/pre-write-secret-content.json"
assert_deny "secret edit"    "${CONTRACT}/pre-write-secret-edit.json"
assert_deny "suppression no reason" "${CONTRACT}/pre-write-suppression-added-no-reason.json"
assert_allow "suppression with reason" "${CONTRACT}/pre-write-suppression-added-reason.json"
assert_ask   "protected file" "${CONTRACT}/pre-write-protected-file-edit.json"
assert_ask   "test skip added" "${CONTRACT}/pre-write-test-skip-added.json"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
