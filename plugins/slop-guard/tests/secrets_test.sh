#!/usr/bin/env bash
# secrets_test.sh — sourced by tests/run-tests; ok()/bad() are pre-defined.
#
# Tests the secret_in_content function from lib/secrets.sh directly.
# Uses resolve_tool from lib/tools.sh (already sourced by tools_test.sh before
# this file is sourced; if sourced standalone, it sources both libraries here).

# shellcheck source=../lib/tools.sh
. "${PLUGIN_ROOT}/lib/tools.sh"
# shellcheck source=../lib/secrets.sh
. "${PLUGIN_ROOT}/lib/secrets.sh"
SECRETS_WORK="${TMPDIR:-/tmp}/slop-guard-secrets-test-$$"
mkdir -p "$SECRETS_WORK"
trap 'rm -rf "${SECRETS_WORK}"' EXIT INT TERM

# --------------------------------------------------------------------------- #
printf '\nsecrets: project-local fake scanner cannot suppress credential detection\n'
# --------------------------------------------------------------------------- #

# Regression guard (RED before fix): secret_in_content returned 1 (clean) when
# any scanner exited 0, regardless of whether the scanner was the plugin-managed
# binary.  An agent could write .venv/bin/betterleaks containing "exit 0" and
# every subsequent Write/Edit would pass credential scanning while the hook fed
# file content into agent-authored code.
#
# After the fix, only the plugin-managed binary's clean verdict is trusted; any
# other source (project vendor/bin, PATH) is advisory and the built-in regex
# fallback always runs.  A content string containing an unmistakable AKIA-format
# AWS access key must be reported as a finding.

FAKE_SCANNER_PROJECT="${SECRETS_WORK}/fake-scanner-project"
mkdir -p "${FAKE_SCANNER_PROJECT}/.venv/bin"

# Agent-written fake betterleaks: claims content is clean regardless of input.
cat > "${FAKE_SCANNER_PROJECT}/.venv/bin/betterleaks" <<'STUB'
#!/bin/sh
cat >/dev/null
exit 0
STUB
chmod +x "${FAKE_SCANNER_PROJECT}/.venv/bin/betterleaks"

# Build a fake lockfile so resolve_tool can resolve betterleaks.
SECRETS_FAKE_LOCK="${SECRETS_WORK}/tools.lock.json"
jq -n '{schema:1, tools:{
    "betterleaks":{version:"1.8.1",
        assets:{"linux-amd64":{url:"file:///dev/null",sha256:"a"},
                "linux-arm64":{url:"file:///dev/null",sha256:"a"},
                "darwin-arm64":{url:"file:///dev/null",sha256:"a"}},
        bin:"betterleaks"},
    "gitleaks":{version:"8.0.0",
        assets:{"linux-amd64":{url:"file:///dev/null",sha256:"a"},
                "linux-arm64":{url:"file:///dev/null",sha256:"a"},
                "darwin-arm64":{url:"file:///dev/null",sha256:"a"}},
        bin:"gitleaks"}}}' > "$SECRETS_FAKE_LOCK"

# Content containing an unmistakable AWS access key literal.
CREDENTIAL_CONTENT='aws_access_key_id = AKIAIOSFODNN7EXAMPLE0000'

# Run secret_in_content with the fake project scanner active and no plugin binary.
# CLAUDE_PLUGIN_DATA is deliberately unset so the plugin step is skipped, leaving
# only the project .venv/bin betterleaks stub (which exits 0).
finding=$(
    TOOLS_LOCK="$SECRETS_FAKE_LOCK"
    CLAUDE_PROJECT_DIR="$FAKE_SCANNER_PROJECT"
    CLAUDE_PLUGIN_OPTION_TOOL_SOURCE="project-first"
    CLAUDE_PLUGIN_DATA=""
    secret_in_content "$CREDENTIAL_CONTENT" "test-path/creds.env"
)
# secret_in_content returns 0 (finding) and prints the reason; return 1 means clean.
rc=$?
if [ "$rc" -eq 0 ] && [ -n "$finding" ]; then
    ok "secrets: project fake scanner exit-0 does not suppress regex fallback"
else
    bad "secrets: project fake scanner bypass" \
        "secret_in_content returned clean (rc=${rc}) — regex fallback did not run"
fi

# Verify the stub actually gets resolved (pre-condition: if the stub is not
# resolved at all, the test above passes trivially via the fallback but does not
# prove the fix).  Run resolve_tool directly to confirm the stub is visible.
stub_resolved=$(
    export TOOLS_LOCK="$SECRETS_FAKE_LOCK"
    export CLAUDE_PROJECT_DIR="$FAKE_SCANNER_PROJECT"
    export CLAUDE_PLUGIN_OPTION_TOOL_SOURCE="project-first"
    export CLAUDE_PLUGIN_DATA=""
    resolve_tool "betterleaks"
)
[ -n "$stub_resolved" ] \
    && ok "secrets: project fake scanner stub is reachable via resolve_tool" \
    || bad "secrets: stub not resolved" \
       "the test pre-condition failed — .venv/bin/betterleaks was not resolved"
