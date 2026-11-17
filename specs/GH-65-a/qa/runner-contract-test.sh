#!/usr/bin/env bash
# Integration fault injection: run the unchanged shipped runner with only its
# OpenGrep case installed; fake only the external scanner's failure modes.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN="$ROOT/plugins/slop-guard"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/plugin/tests/integration" "$WORK/path" "$WORK/data"
cp "$PLUGIN/tests/tool-integration" "$WORK/plugin/tests/tool-integration"
cp "$PLUGIN/tests/integration/opengrep.sh" "$WORK/plugin/tests/integration/opengrep.sh"
for item in lib tools rules configs bin; do ln -s "$PLUGIN/$item" "$WORK/plugin/$item"; done
ln -s "$PLUGIN/tests/fixtures" "$WORK/plugin/tests/fixtures"
# No scanner is reachable through this PATH unless this test installs one.
for cmd in bash jq git mkdir rm cp dirname basename grep tee readlink date uname cat sed awk head cut tr; do
    target="$(command -v "$cmd")"
    ln -s "$target" "$WORK/path/$cmd"
done
PASS=0 FAIL=0
run_case() {
    local label="$1" mode="$2" require="$3" rc=0
    rm -f "$WORK/path/opengrep"
    if [ "$mode" != absent ]; then
        cat > "$WORK/path/opengrep" <<'SCANNER'
#!/usr/bin/env bash
if [ "${1:-}" = --version ]; then printf '1.30.0\n'; exit 0; fi
case "$QA_SCAN_MODE" in
    failure) printf '{"results":[],"errors":[]}\n'; exit 2 ;;
    invalid) printf 'not json\n' ;;
    missing) printf '{"errors":[]}\n' ;;
    parse) printf '{"results":[],"errors":[{"type":"Parse error"}]}\n' ;;
esac
SCANNER
        chmod +x "$WORK/path/opengrep"
    fi
    PATH="$WORK/path" CLAUDE_PLUGIN_ROOT="$WORK/plugin" CLAUDE_PLUGIN_DATA="$WORK/data" \
        CLAUDE_PLUGIN_OPTION_TOOL_SOURCE=plugin-only QA_SCAN_MODE="$mode" \
        SLOPGUARD_IT_REQUIRE="$require" SLOPGUARD_IT_DEBUG=0 \
        /bin/bash "$WORK/plugin/tests/tool-integration" > "$WORK/output" 2>&1 || rc=$?
    if { [ "$mode" = absent ] && grep -q '0 passed, 0 failed, 1 skipped, 0 known' "$WORK/output" &&
        { { [ "$require" = 0 ] && [ "$rc" = 0 ]; } || { [ "$require" = 1 ] && [ "$rc" != 0 ] && grep -q 'SLOPGUARD_IT_REQUIRE=1: 1 tool(s) skipped' "$WORK/output"; }; }; } ||
       { [ "$mode" != absent ] && [ "$rc" != 0 ] && grep -q 'FAIL  GH-65-a UC-4:' "$WORK/output" && grep -q '0 passed, 13 failed, 0 skipped, 0 known' "$WORK/output"; }; then
        printf 'ok %s (runner exit %s)\n' "$label" "$rc"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s (runner exit %s)\n' "$label" "$rc"; cat "$WORK/output"; FAIL=$((FAIL + 1))
    fi
}
run_case 'UC-3: absent binary records exactly one skip' absent 0
run_case 'UC-3: required absent binary rejects suite' absent 1
run_case 'UC-4: nonzero scan with otherwise valid JSON fails' failure 1
run_case 'UC-4: malformed scan JSON fails' invalid 1
run_case 'UC-4: missing results fails' missing 1
run_case 'UC-4: parse errors fail' parse 1
printf '%s passed, %s failed, 0 skipped\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
