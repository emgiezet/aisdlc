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
run_write_policy Edit app.py 'x = g()  # noqa' 'x = f()  # noqa' allow 'existing suppression survives line edit'
run_write_policy Write app.py 'api_key = "1234567890abcdef"' '' deny 'obvious secret denied'
run_write_policy Write app.py 'token = "ghp_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"' '' deny 'GitHub token denied'
scanner_project="${TMPDIR:-/tmp}/slop-guard-scanner-project-$$"
mkdir -p "${scanner_project}/vendor/bin"
cat > "${scanner_project}/vendor/bin/betterleaks" <<'EOF'
#!/bin/sh
cat >/dev/null
exit 1
EOF
chmod +x "${scanner_project}/vendor/bin/betterleaks"
scanner_output="$(jq -n \
    '{tool_name:"Write",tool_input:{file_path:"scanner.py",content:"scanner-only-marker"}}' \
    | CLAUDE_PROJECT_DIR="$scanner_project" CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=project-first "$WRITE_HOOK")"
scanner_reason="$(printf '%s' "$scanner_output" | jq -r '.hookSpecificOutput.permissionDecisionReason')"
[ "$(printf '%s' "$scanner_output" | jq -r '.hookSpecificOutput.permissionDecision')" = deny ] \
    && printf '%s' "$scanner_reason" | grep -qF 'betterleaks credential finding in scanner.py' \
    && ok 'pre-write: managed secret scanner blocks with redacted location' \
    || bad 'pre-write: managed secret scanner' "$scanner_output"
rm -rf "$scanner_project"
notebook_output="$(jq -n \
    '{tool_name:"NotebookEdit",tool_input:{notebook_path:"analysis.ipynb",new_source:"token = \"ghp_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\"",old_source:""}}' \
    | "$WRITE_HOOK")"
[ "$(printf '%s' "$notebook_output" | jq -r '.hookSpecificOutput.permissionDecision')" = deny ] \
    && ok 'pre-write: NotebookEdit new_source is scanned' \
    || bad 'pre-write: NotebookEdit new_source' "$notebook_output"
run_write_policy Edit phpstan-baseline.neon 'parameters: {}' 'parameters: {}' ask 'protected baseline asks'
run_write_policy Edit pyproject.toml '' '[tool.ruff]' ask 'removing protected pyproject section asks'
run_write_policy Edit tsconfig.json '' '"strict": true' ask 'removing strict TypeScript config asks'

context_payload="$(jq -n \
    '{session_id:"write-context",tool_name:"Write",tool_input:{file_path:"context.py",content:"print(1)"}}')"
first_context="$(printf '%s' "$context_payload" | "$WRITE_HOOK")"
second_context="$(printf '%s' "$context_payload" | "$WRITE_HOOK")"
context_text="$(printf '%s' "$first_context" | jq -r '.hookSpecificOutput.additionalContext // empty')"
[ -n "$context_text" ] && [ -z "$second_context" ] \
    && ok 'pre-write: language blocker context appears once' \
    || bad 'pre-write: language blocker context' "first=${first_context}, second=${second_context}"

output="$(jq -n --arg file 'eslint.config.js' --arg new 'export default {}' \
    '{tool_name:"Write",tool_input:{file_path:$file,content:$new}}' \
    | AISDLC_HEADLESS=1 "$WRITE_HOOK")"
decision="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision')"
reason="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason')"
[ "$decision" = deny ] && printf '%s' "$reason" | grep -qF 'no human in this session' \
    && ok 'pre-write: headless protected edit becomes reasoned deny' \
    || bad 'pre-write: headless protected edit' "decision=${decision}, reason=${reason}"

# ---------------------------------------------------------------------------
# Guard/host configuration-file protection (hook_secret_deny — always deny)
# ---------------------------------------------------------------------------

# .claude/settings.json: writing it injects env vars (e.g.
# CLAUDE_PLUGIN_OPTION_ENFORCEMENT_MODE=advisory) that degrade subsequent
# hook_deny calls to passive context for the rest of the session.
run_write_policy Write .claude/settings.json \
    '{"env":{"CLAUDE_PLUGIN_OPTION_ENFORCEMENT_MODE":"advisory"}}' '' \
    deny '.claude/settings.json write denied'

# advisory mode MUST NOT relax this deny (hook_secret_deny, not hook_deny).
advisory_cfg_output="$(jq -n --arg file '.claude/settings.json' --arg new '{"env":{}}' \
    '{tool_name:"Write",tool_input:{file_path:$file,content:$new,new_string:$new,old_string:""}}' \
    | CLAUDE_PLUGIN_OPTION_ENFORCEMENT_MODE=advisory "$WRITE_HOOK")"
advisory_cfg_decision="$(printf '%s' "$advisory_cfg_output" \
    | jq -r '.hookSpecificOutput.permissionDecision // "allow"')"
[ "$advisory_cfg_decision" = "deny" ] \
    && ok 'pre-write: .claude/settings.json denied in advisory mode' \
    || bad 'pre-write: .claude/settings.json advisory mode' \
        "expected deny, got ${advisory_cfg_decision}"

# .agents/ tree: host-level configuration for agent plugin loading.
run_write_policy Write .agents/plugins/marketplace.json '{}' '' \
    deny '.agents/plugins/marketplace.json write denied'

# Hook registration files: removing or editing them can silence the guard.
run_write_policy Write plugins/slop-guard/hooks/hooks.json '{}' '' \
    deny 'plugins/*/hooks/hooks.json write denied'

# Near-miss: docs/claude/settings.json has no .claude directory component and
# must not be caught — agents legitimately document Claude settings there.
run_write_policy Write docs/claude/settings.json '{}' '' \
    allow 'docs/claude/settings.json near-miss not caught'
