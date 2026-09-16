#!/usr/bin/env bash
# grok_hook_test.sh — Grok portability contract for plugins/sdlc hooks.
#
# Reads every command under test from hooks/hooks.json so the exact registered
# command string is what is under test, not a duplicated path.  All four
# assertions are currently RED; each comment states the production change
# required to make it GREEN.
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

# _run CMD PAYLOAD
#   Execute CMD via Grok env (CLAUDE_PLUGIN_ROOT unset, GROK_PLUGIN_ROOT set),
#   piping PAYLOAD to stdin.  Captures stdout into _run_out, exit code into
#   _run_rc.  Stderr is discarded: assertions target only the contract surface.
_run_out=""
_run_rc=0
_run() {
    local cmd="$1" payload="$2"
    _run_out="$(printf '%s' "$payload" \
        | env -u CLAUDE_PLUGIN_ROOT GROK_PLUGIN_ROOT="${PLUGIN_ROOT}" bash -c "$cmd" 2>/dev/null
    )" && _run_rc=0 || _run_rc=$?
}

# _run_in DIR CMD PAYLOAD — same as _run but executes from DIR.
_run_in() {
    local dir="$1" cmd="$2" payload="$3"
    _run_out="$(
        cd "$dir" || exit 1
        printf '%s' "$payload" \
        | env -u CLAUDE_PLUGIN_ROOT GROK_PLUGIN_ROOT="${PLUGIN_ROOT}" bash -c "$cmd" 2>/dev/null
    )" && _run_rc=0 || _run_rc=$?
}

# ─── Grok camelCase fixtures ─────────────────────────────────────────────────

_FX_SESSION='{"hookEventName":"SessionStart","sessionId":"grok-ss-001"}'

_FX_FORCE_PUSH='{"hookEventName":"PreToolUse","sessionId":"grok-fp-001","cwd":"/repo","workspaceRoot":"/repo","toolName":"Bash","toolInput":{"command":"git push --force origin main"}}'

_FX_SAFE_BASH='{"hookEventName":"PreToolUse","sessionId":"grok-sb-001","cwd":"/repo","workspaceRoot":"/repo","toolName":"Bash","toolInput":{"command":"echo hello world"}}'

_FX_STOP='{"hookEventName":"Stop","sessionId":"grok-stop-001","stopHookActive":false}'

# ─── Git fixture for Stop test ───────────────────────────────────────────────
# Creates a repo with one committed test file, then stages its deletion.
# guard stop_check detects the deletion via git diff --name-status.
_STOP_REPO="${_SDLC_GROK_WORK}/stop-repo"
mkdir -p "$_STOP_REPO"
(
    cd "$_STOP_REPO"
    git init -q -b main
    git config user.email stop-test@localhost
    git config user.name "sdlc stop test"
    printf 'def test_sample():\n    pass\n' > test_sample.py
    git add test_sample.py
    git commit -q -m "add test_sample"
    git rm -q test_sample.py          # staged deletion — matches TEST_PATH_RE
)

# ─────────────────────────────────────────────────────────────────────────────
# Test 1 — SessionStart: registered command resolves with GROK_PLUGIN_ROOT only
#
# Defect: hooks.json registers
#   "${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd" session-start
# On Grok, CLAUDE_PLUGIN_ROOT is unset.  Bash expands it to the empty string,
# producing the literal path "/hooks/run-hook.cmd" which does not exist — the
# hook cannot be invoked at all.
#
# Fix required: replace ${CLAUDE_PLUGIN_ROOT} in the hooks.json command string
# with ${GROK_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}} (or a runtime-agnostic shim)
# so the command resolves from whichever root variable the runtime supplies.
# ─────────────────────────────────────────────────────────────────────────────
_cmd="$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$HOOKS_JSON")"
_run "$_cmd" "$_FX_SESSION"
[ "$_run_rc" -eq 0 ] \
    && ok  "SessionStart: registered command resolves and exits 0 with GROK_PLUGIN_ROOT (CLAUDE_PLUGIN_ROOT unset)" \
    || bad "SessionStart: registered command resolves and exits 0 with GROK_PLUGIN_ROOT" \
           "exit=${_run_rc}; command expands CLAUDE_PLUGIN_ROOT to empty string on Grok, producing a nonexistent path"
unset _cmd

# ─────────────────────────────────────────────────────────────────────────────
# Test 2 — PreToolUse: camelCase force-push payload returns native Grok deny
#
# Defects:
#   a) Registered command uses ${CLAUDE_PLUGIN_ROOT} — hook is not invokable
#      on Grok (same root as Test 1).
#   b) guard reads .tool_input.command (snake_case); Grok sends
#      toolInput.command (camelCase).  The jq path resolves to null so guard
#      exits 0 — force push is silently allowed.
#   c) guard's deny() writes the reason to stderr and exits 2.  Grok's
#      PreToolUse blocking contract requires exit 0 + stdout JSON
#      {"decision":"deny","reason":"<text>"}.
#
# Fix required (all three):
#   a) Resolve command via GROK_PLUGIN_ROOT (same fix as Test 1).
#   b) Normalise camelCase toolInput → .tool_input before field access in guard.
#   c) Detect Grok runtime in guard and emit native stdout JSON deny instead of
#      exiting 2 with stderr output.
# ─────────────────────────────────────────────────────────────────────────────
_cmd="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOOKS_JSON")"
_run "$_cmd" "$_FX_FORCE_PUSH"
_decision="$(printf '%s' "$_run_out" | jq -r '.decision // empty' 2>/dev/null)"
[ "$_decision" = "deny" ] \
    && ok  "PreToolUse: force-push camelCase payload blocked with native Grok {decision:deny}" \
    || bad "PreToolUse: force-push camelCase payload blocked with native Grok {decision:deny}" \
           "decision='${_decision:-<empty>}' stdout='${_run_out:-<empty>}' exit=${_run_rc}"
unset _cmd _decision

# ─────────────────────────────────────────────────────────────────────────────
# Test 3 — PreToolUse: safe Grok Bash command allows silently (exit 0, no stdout)
#
# Defect: same as Test 1 defect (a) — the registered command cannot be invoked
# on Grok because it uses ${CLAUDE_PLUGIN_ROOT}.  Once the invocation fix
# lands, no additional change is needed: guard already exits 0 with empty
# stdout when cmd is null, so the allow path works without further changes.
#
# Fix required: resolve command via GROK_PLUGIN_ROOT (same fix as Test 1).
# ─────────────────────────────────────────────────────────────────────────────
_cmd="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOOKS_JSON")"
_run "$_cmd" "$_FX_SAFE_BASH"
[ "$_run_rc" -eq 0 ] && [ -z "$_run_out" ] \
    && ok  "PreToolUse: safe Grok Bash command allows silently (exit 0, no stdout)" \
    || bad "PreToolUse: safe Grok Bash command allows silently" \
           "exit=${_run_rc} stdout='${_run_out:-<empty>}'"
unset _cmd

# ─────────────────────────────────────────────────────────────────────────────
# Test 4 — Stop: deleted test file triggers advisory warning, exits 0, no block
#
# The git fixture above stages the deletion of test_sample.py, which matches
# guard's TEST_PATH_RE ('test_[^/]*\.py').  The Grok Stop payload uses
# camelCase field names.
#
# Defects:
#   a) Registered command uses ${CLAUDE_PLUGIN_ROOT} — hook is not invokable on Grok.
#   b) guard reads .stop_hook_active (snake_case); Grok sends stopHookActive
#      (camelCase).  The reentered flag always resolves false on Grok, so the
#      guard always proceeds to deny() regardless of prior stop_hook_active state.
#   c) guard's stop_check() calls deny() which exits 2 with stderr output.  On
#      Grok, Stop hooks are passive: the hook MUST exit 0, MUST NOT emit a
#      blocking decision, and advisory output MUST go to stderr only.
#
# Fix required (all three):
#   a) Resolve command via GROK_PLUGIN_ROOT (same fix as Test 1).
#   b) Normalise camelCase stopHookActive → .stop_hook_active before reading
#      the reentered flag.
#   c) Detect Grok runtime in stop_check and, when running on Grok, emit an
#      advisory warning to stderr then exit 0 instead of calling deny().
# ─────────────────────────────────────────────────────────────────────────────
_cmd="$(jq -r '.hooks.Stop[0].hooks[0].command' "$HOOKS_JSON")"
_run_in "$_STOP_REPO" "$_cmd" "$_FX_STOP"
_decision="$(printf '%s' "$_run_out" | jq -r '.decision // empty' 2>/dev/null)"
[ "$_run_rc" -eq 0 ] && [ -z "$_decision" ] \
    && ok  "Stop: deleted test file is advisory on Grok — exits 0 and emits no blocking decision" \
    || bad "Stop: deleted test file is advisory on Grok" \
           "exit=${_run_rc} decision='${_decision:-<empty>}' (Stop must exit 0 on Grok; guard must not block)"
unset _cmd _decision

# ─── Standalone summary ──────────────────────────────────────────────────────
if [ "${_SDLC_GROK_STANDALONE:-0}" = "1" ]; then
    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ] || exit 1
fi
