#!/usr/bin/env bash
# grok_hook_test.sh — Grok and Claude portability contract for plugins/sdlc hooks.
#
# Reads registered commands from hooks/hooks.json so the exact registered command
# string is under test, not a duplicated path.
#
# Standalone:  ./grok_hook_test.sh  — defines ok()/bad() and exits 1 on failure.
# Sourced:     test runner must define ok()/bad() before sourcing this file.
set -uo pipefail

_SDLC_GROK_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${_SDLC_GROK_TESTS_DIR}/.." && pwd)"
HOOKS_JSON="${PLUGIN_ROOT}/hooks/hooks.json"

# Standalone mode: define counters when not inherited from a test runner.
if ! declare -f ok >/dev/null 2>&1; then
    PASS=0; FAIL=0
    ok()  { printf '  ok    %s\n' "$1"; PASS=$((PASS + 1)); }
    bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }
    _SDLC_GROK_STANDALONE=1
fi

# Scratch space; cleaned on exit.
_SDLC_GROK_WORK="${TMPDIR:-/tmp}/sdlc-grok-test-$$"
mkdir -p "$_SDLC_GROK_WORK"
trap 'rm -rf "$_SDLC_GROK_WORK"' EXIT INT TERM

# _run_grok CMD PAYLOAD
#   Execute CMD via Grok env (CLAUDE_PLUGIN_ROOT unset, GROK_PLUGIN_ROOT set),
#   piping PAYLOAD to stdin.  Captures stdout into _run_out, stderr into _run_err,
#   and exit code into _run_rc.
_run_out=""
_run_err=""
_run_rc=0
_run_grok() {
    local cmd="$1" payload="$2"
    _run_out="$(printf '%s' "$payload" \
        | env -u CLAUDE_PLUGIN_ROOT GROK_PLUGIN_ROOT="${PLUGIN_ROOT}" bash -c "$cmd" \
            2>"${_SDLC_GROK_WORK}/run.err"
    )" && _run_rc=0 || _run_rc=$?
    _run_err="$(cat "${_SDLC_GROK_WORK}/run.err" 2>/dev/null || true)"
}

# _run_grok_in DIR CMD PAYLOAD — same as _run_grok but executes from DIR.
_run_grok_in() {
    local dir="$1" cmd="$2" payload="$3"
    _run_out="$(
        cd "$dir" || exit 1
        printf '%s' "$payload" \
        | env -u CLAUDE_PLUGIN_ROOT GROK_PLUGIN_ROOT="${PLUGIN_ROOT}" bash -c "$cmd" \
            2>"${_SDLC_GROK_WORK}/run.err"
    )" && _run_rc=0 || _run_rc=$?
    _run_err="$(cat "${_SDLC_GROK_WORK}/run.err" 2>/dev/null || true)"
}

# _run_claude CMD PAYLOAD
#   Execute CMD via Claude env (CLAUDE_PLUGIN_ROOT set, GROK_PLUGIN_ROOT unset),
#   piping PAYLOAD to stdin.  Captures stdout into _run_out, stderr into _run_err,
#   and exit code into _run_rc.
_run_claude() {
    local cmd="$1" payload="$2"
    _run_out="$(printf '%s' "$payload" \
        | env -u GROK_PLUGIN_ROOT CLAUDE_PLUGIN_ROOT="${PLUGIN_ROOT}" bash -c "$cmd" \
            2>"${_SDLC_GROK_WORK}/run.err"
    )" && _run_rc=0 || _run_rc=$?
    _run_err="$(cat "${_SDLC_GROK_WORK}/run.err" 2>/dev/null || true)"
}

# ─── Grok camelCase fixtures ─────────────────────────────────────────────────

_FX_GROK_FORCE_PUSH='{"hookEventName":"PreToolUse","sessionId":"grok-fp-001","cwd":"/repo","workspaceRoot":"/repo","toolName":"Bash","toolInput":{"command":"git push --force origin main"}}'

_FX_CLAUDE_FORCE_PUSH='{"tool_input":{"command":"git push --force origin main"}}'

_FX_GROK_SAFE_BASH='{"hookEventName":"PreToolUse","sessionId":"grok-sb-001","cwd":"/repo","workspaceRoot":"/repo","toolName":"Bash","toolInput":{"command":"echo hello world"}}'

_FX_CLAUDE_SAFE_BASH='{"tool_input":{"command":"echo hello world"}}'

_FX_GROK_STOP='{"hookEventName":"Stop","sessionId":"grok-stop-001","stopHookActive":false}'

_FX_CLAUDE_STOP='{"stop_hook_active":false}'

# ─── Git fixture for Stop tests ──────────────────────────────────────────────
# Creates a repo with one committed test file, then stages its deletion.
# guard stop_check detects the deletion via git diff --name-status.
_STOP_REPO="${_SDLC_GROK_WORK}/stop-repo"
mkdir -p "$_STOP_REPO"
(
    cd "$_STOP_REPO" || exit 1
    git init -q -b main
    git config user.email stop-test@localhost
    git config user.name "sdlc stop test"
    printf 'def test_sample():\n    pass\n' > test_sample.py
    git add test_sample.py
    git commit -q -m "add test_sample"
    git rm -q test_sample.py          # staged deletion — matches TEST_PATH_RE
)

# ─────────────────────────────────────────────────────────────────────────────
# Test 1 — PreToolUse (Grok): camelCase force-push payload blocked with Grok envelope
#
# Grok sends camelCase toolInput.command; guard normalizes it to tool_input.command
# before field access.  On Grok, blocking requires exit 0 plus
# {"decision":"deny","reason":"..."} on stdout.
# ─────────────────────────────────────────────────────────────────────────────
_cmd="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOOKS_JSON")"
_run_grok "$_cmd" "$_FX_GROK_FORCE_PUSH"
_decision="$(printf '%s' "$_run_out" | jq -r '.decision // empty' 2>/dev/null)"
[ "$_run_rc" -eq 0 ] && [ "$_decision" = "deny" ] \
    && ok  "PreToolUse (Grok): force-push camelCase payload blocked with {decision:deny}" \
    || bad "PreToolUse (Grok): force-push camelCase payload blocked with {decision:deny}" \
           "exit=${_run_rc} decision='${_decision:-<empty>}' stdout='${_run_out:-<empty>}'"
unset _cmd _decision

# ─────────────────────────────────────────────────────────────────────────────
# Test 2 — PreToolUse (Claude): snake_case force-push payload blocked with exit 2
#
# On Claude, blocking uses exit 2 with the deny reason on stderr; stdout is empty.
# ─────────────────────────────────────────────────────────────────────────────
_cmd="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOOKS_JSON")"
_run_claude "$_cmd" "$_FX_CLAUDE_FORCE_PUSH"
[ "$_run_rc" -eq 2 ] && [ -z "$_run_out" ] && printf '%s' "$_run_err" | grep -qF 'guard: force push blocked' \
    && ok  "PreToolUse (Claude): force-push blocked with exit 2 and reason on stderr" \
    || bad "PreToolUse (Claude): force-push blocked with exit 2 and reason on stderr" \
           "exit=${_run_rc} stdout='${_run_out:-<empty>}' stderr='${_run_err:-<empty>}'"
unset _cmd

# ─────────────────────────────────────────────────────────────────────────────
# Test 3 — PreToolUse (Grok): safe command allows silently (exit 0, no stdout)
# ─────────────────────────────────────────────────────────────────────────────
_cmd="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOOKS_JSON")"
_run_grok "$_cmd" "$_FX_GROK_SAFE_BASH"
[ "$_run_rc" -eq 0 ] && [ -z "$_run_out" ] \
    && ok  "PreToolUse (Grok): safe command allows silently (exit 0, no stdout)" \
    || bad "PreToolUse (Grok): safe command allows silently" \
           "exit=${_run_rc} stdout='${_run_out:-<empty>}'"
unset _cmd

# ─────────────────────────────────────────────────────────────────────────────
# Test 4 — PreToolUse (Claude): safe command allows silently (exit 0, no stdout)
# ─────────────────────────────────────────────────────────────────────────────
_cmd="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOOKS_JSON")"
_run_claude "$_cmd" "$_FX_CLAUDE_SAFE_BASH"
[ "$_run_rc" -eq 0 ] && [ -z "$_run_out" ] \
    && ok  "PreToolUse (Claude): safe command allows silently (exit 0, no stdout)" \
    || bad "PreToolUse (Claude): safe command allows silently" \
           "exit=${_run_rc} stdout='${_run_out:-<empty>}'"
unset _cmd

# ─────────────────────────────────────────────────────────────────────────────
# Test 5 — Stop (Grok): deleted test file → advisory, exits 0, no blocking JSON
#
# Grok sends camelCase stopHookActive; guard normalizes it to stop_hook_active.
# Stop hooks on Grok are passive: exit 0, advisory to stderr, no stdout JSON.
# ─────────────────────────────────────────────────────────────────────────────
_cmd="$(jq -r '.hooks.Stop[0].hooks[0].command' "$HOOKS_JSON")"
_run_grok_in "$_STOP_REPO" "$_cmd" "$_FX_GROK_STOP"
_decision="$(printf '%s' "$_run_out" | jq -r '.decision // empty' 2>/dev/null)"
[ "$_run_rc" -eq 0 ] \
    && [ -z "$_decision" ] \
    && printf '%s' "$_run_err" | grep -qF 'guard [advisory]' \
    && printf '%s' "$_run_err" | grep -qF 'test_sample.py' \
    && ok  "Stop (Grok): deleted test file → advisory on stderr, exits 0, no block" \
    || bad "Stop (Grok): deleted test file → advisory on stderr, exits 0, no block" \
           "exit=${_run_rc} decision='${_decision:-<empty>}' stderr='${_run_err:-<empty>}'"
unset _cmd _decision

# ─────────────────────────────────────────────────────────────────────────────
# Test 6 — Stop (Claude): deleted test file → blocks with exit 2
#
# On Claude/Codex, Stop hooks are blocking: exit 2 with the deny reason on stderr.
# ─────────────────────────────────────────────────────────────────────────────
_cmd="$(jq -r '.hooks.Stop[0].hooks[0].command' "$HOOKS_JSON")"
_run_claude_in() {
    local dir="$1" cmd="$2" payload="$3"
    _run_out="$(
        cd "$dir" || exit 1
        printf '%s' "$payload" \
        | env -u GROK_PLUGIN_ROOT CLAUDE_PLUGIN_ROOT="${PLUGIN_ROOT}" bash -c "$cmd" \
            2>"${_SDLC_GROK_WORK}/run.err"
    )" && _run_rc=0 || _run_rc=$?
    _run_err="$(cat "${_SDLC_GROK_WORK}/run.err" 2>/dev/null || true)"
}
_run_claude_in "$_STOP_REPO" "$_cmd" "$_FX_CLAUDE_STOP"
[ "$_run_rc" -eq 2 ] && [ -z "$_run_out" ] && printf '%s' "$_run_err" | grep -qF 'guard: this session weakened' \
    && ok  "Stop (Claude): deleted test file → blocks with exit 2 and reason on stderr" \
    || bad "Stop (Claude): deleted test file → blocks with exit 2 and reason on stderr" \
           "exit=${_run_rc} stdout='${_run_out:-<empty>}' stderr='${_run_err:-<empty>}'"
unset _cmd

# ─────────────────────────────────────────────────────────────────────────────
# Test 7 — SessionStart (Grok): registered command resolves and exits 0
#
# hooks.json registers ${CLAUDE_PLUGIN_ROOT:-${GROK_PLUGIN_ROOT}}/hooks/run-hook.cmd
# so on Grok (CLAUDE_PLUGIN_ROOT unset), GROK_PLUGIN_ROOT is used as the root.
# SessionStart stdout is ignored by Grok; hook must exit 0.
# ─────────────────────────────────────────────────────────────────────────────
_cmd="$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$HOOKS_JSON")"
_FX_GROK_SESSION='{"hookEventName":"SessionStart","sessionId":"grok-ss-001"}'
_run_grok "$_cmd" "$_FX_GROK_SESSION"
[ "$_run_rc" -eq 0 ] \
    && ok  "SessionStart (Grok): registered command resolves via GROK_PLUGIN_ROOT, exits 0" \
    || bad "SessionStart (Grok): registered command resolves via GROK_PLUGIN_ROOT, exits 0" \
           "exit=${_run_rc}; stdout='${_run_out:-<empty>}'"
unset _cmd _FX_GROK_SESSION

# ─────────────────────────────────────────────────────────────────────────────
# Test 8 — hooks.json: all registered hook files exist and are executable
# ─────────────────────────────────────────────────────────────────────────────
_hooks_ok=1
while IFS= read -r _hook_file; do
    _path="${PLUGIN_ROOT}/hooks/${_hook_file}"
    if [ ! -f "$_path" ]; then
        bad "hooks.json: ${_hook_file} not found at ${_path}" "file missing"
        _hooks_ok=0
    elif [ ! -x "$_path" ]; then
        bad "hooks.json: ${_hook_file} not executable" "chmod +x required"
        _hooks_ok=0
    fi
done <<EOF_HOOK_FILES
run-hook.cmd
session-start
guard
EOF_HOOK_FILES
[ "$_hooks_ok" -eq 1 ] \
    && ok "hooks.json: all referenced hook files exist and are executable"
unset _hooks_ok _hook_file _path

# ─── Standalone summary ──────────────────────────────────────────────────────
if [ "${_SDLC_GROK_STANDALONE:-0}" = "1" ]; then
    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ] || exit 1
fi
