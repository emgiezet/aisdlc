#!/usr/bin/env bash
# write_test.sh — sourced by tests/run-tests; ok()/bad() are pre-defined.

WRITE_HOOK="${PLUGIN_ROOT}/hooks/pre-write"

run_write_policy() {
    local tool="$1" file="$2" new_content="$3" old_content="$4" expected="$5" label="$6"
    local output decision
    output="$(jq -n \
        --arg tool "$tool" --arg file "$file" --arg new "$new_content" --arg old "$old_content" \
        '{tool_name:$tool,tool_input:{file_path:$file,content:$new,new_string:$new,old_string:$old}}' \
        | "$WRITE_HOOK")"
    if [ -n "$output" ]; then
        decision="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision // "allow"')"
    else
        decision="allow"
    fi
    [ "$decision" = "$expected" ] \
        && ok "pre-write: $label" \
        || bad "pre-write: $label" "expected $expected, got $decision"
}

run_write_policy Write app.go '//nolint:gosec' '' deny 'suppression without reason denied'
run_write_policy Write app.go '//nolint:gosec // reason: input validated upstream' '' allow 'suppression with configured reason allowed'
run_write_policy Edit app.go '//nolint:gosec' '//nolint:gosec' allow 'unchanged suppression remains editable'
run_write_policy Write app.py 'api_key = "1234567890abcdef"' '' deny 'obvious secret denied'
run_write_policy Edit phpstan-baseline.neon 'parameters: {}' 'parameters: {}' ask 'protected baseline asks'
run_write_policy Edit sample.test.ts 'it.skip("works", fn)' 'it("works", fn)' ask 'added test skip asks'

output="$(jq -n --arg file 'eslint.config.js' --arg new 'export default {}' \
    '{tool_name:"Write",tool_input:{file_path:$file,content:$new}}' \
    | AISDLC_HEADLESS=1 "$WRITE_HOOK")"
decision="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision')"
reason="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason')"
[ "$decision" = deny ] && printf '%s' "$reason" | grep -qF 'no human in this session' \
    && ok 'pre-write: headless protected edit becomes reasoned deny' \
    || bad 'pre-write: headless protected edit' "decision=${decision}, reason=${reason}"
