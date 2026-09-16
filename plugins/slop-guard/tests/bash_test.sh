#!/usr/bin/env bash
# bash_test.sh — tests for plugins/slop-guard/hooks/pre-bash
PLUGIN_ROOT="plugins/slop-guard"
HOOK="${PLUGIN_ROOT}/hooks/pre-bash"

ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; exit 1; }

run_test() {
    local expected="$2"
    local output
    output="$(cat "plugins/slop-guard/tests/hook-contract/$1" | "$HOOK")"
    local decision
    decision="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision // "allow"')"
    
    if [ "$decision" = "$expected" ]; then
        ok "pre-bash: $1 → $expected"
    else
        bad "pre-bash: $1" "expected $expected, got $decision (output: $output)"
    fi
}

# 1. Pipe-to-shell deny
run_test "pre-bash-curl-pipe.json" "deny"

# 2. NPM install ask
run_test "pre-bash-npm-install.json" "ask"

# 3. NPM install -g deny
run_test "pre-bash-npm-global.json" "deny"

# 4. Lockfile delete deny
run_test "pre-bash-rm-lockfile.json" "deny"

# 5. Read secret file allow (default)
run_test "pre-bash-read-secret.json" "allow"

# 6. NPM ci allow
run_test "pre-bash-npm-ci.json" "allow"

echo "All tests passed"
