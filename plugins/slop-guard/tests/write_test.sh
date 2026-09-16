#!/usr/bin/env bash
# write_test.sh — tests for plugins/slop-guard/hooks/pre-write

PLUGIN_ROOT="${PLUGIN_ROOT:-plugins/slop-guard}"
HOOK="${PLUGIN_ROOT}/hooks/pre-write"

ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; exit 1; }

run_hook() {
    jq -n --arg tool "$1" --arg file "$2" --arg new "$3" \
        '{tool_name: $tool, tool_input: {file_path: $file, content: $new}}' \
        | "$HOOK"
}

# 1. Deny: Suppression marker without reason
    # Run the hook, capture decision from JSON output
    local output
    output="$(cat "$fixture" | "$HOOK" 2>/dev/null)"
    local decision
    decision="$(printf '%s' "$output" | tr -d '[:space:]' | jq -r '.hookSpecificOutput.permissionDecision // "allow"')"
    
    if [ "$decision" = "$expected" ]; then

# 2. Allow: Suppression marker with reason
result=$(run_hook "Write" "app.php" "<?php // @phpstan-ignore (reason: this is valid)" "")
if [[ -z "$result" ]]; then ok "allow: suppression with reason"; else bad "allow: suppression with reason" "$result"; fi

# 3. Sabotage: Suppression marker on line 1, reason on line 2 (Should be denied)
new_content=$'//nolint:rule\n// reason: this is a valid reason'
result=$(run_hook "Write" "app.go" "$new_content" "")
if echo "$result" | grep -q "permissionDecision\":\"deny"; then ok "sabotage: reason on different line denied"; else bad "sabotage: reason on different line denied" "$result"; fi

echo "All tests passed"
