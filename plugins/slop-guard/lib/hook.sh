#!/usr/bin/env bash
# lib/hook.sh — hook I/O contract: stdin decode, response encode, exit codes.
#
# §3.2: a hook receives JSON on stdin exactly once; read it here and cache it so
# nothing downstream consumes the stream (aisdlc:318-320 exists for this reason).
#
# Public interface:
#   hook_input               — read stdin once into _HOOK_INPUT (call at entry)
#   hook_field  <jq-path>    — extract a field; empty for null/missing
#   hook_deny   <reason>     — deny, or add context in advisory mode
#   hook_secret_deny <reason> — always deny secret access/content
#   hook_allow               — permit explicitly; silent on Grok (exit 0 = allow)
#   hook_context <text>      — print additionalContext JSON to stdout (silent on Grok)
#   hook_message <text>      — print systemMessage JSON to stdout (no-op on Grok)
#
# Exit-code contract (§3.2):
#   exit 0 + JSON on stdout  — structured decision (use these helpers)
#   exit 2                   — blocking error; reason on stderr
#   exit 1 / other           — non-blocking; action proceeds
#
# All JSON is built with jq -n --arg; never by string-concatenating, because a
# reason containing a double-quote would emit invalid JSON and Claude would
# silently ignore the decision.
#
# additionalContext is written as a statement of fact, never as a system-style
# order — prompt-injection defences may trigger on imperative text (§3.2).

# Runtime detection — set once when this library is sourced.
# Grok injects GROK_PLUGIN_ROOT (and GROK_PLUGIN_DATA, GROK_WORKSPACE_ROOT).
# It does not set CLAUDE_PLUGIN_ROOT; slopguard normalizes that before invoking hooks.
_SLOPGUARD_RUNTIME=""
[ -n "${GROK_PLUGIN_ROOT:-}" ] && _SLOPGUARD_RUNTIME="grok"

# jq bootstrap: SessionStart installs jq into plugin data; hook processes do not
# inherit that environment, so find the managed binary explicitly.
# Check GROK_PLUGIN_DATA first; fall back to CLAUDE_PLUGIN_DATA (Claude/Codex).
if ! command -v jq >/dev/null 2>&1; then
    _sg_jq_data="${GROK_PLUGIN_DATA:-${CLAUDE_PLUGIN_DATA:-}}"
    if [ -x "${_sg_jq_data}/tools/jq/current/jq" ]; then
        PATH="${_sg_jq_data}/tools/jq/current:${PATH}"
        export PATH
    fi
    unset _sg_jq_data
fi

# Cache for the hook's stdin payload.
_HOOK_INPUT=""

# hook_input — read stdin once into _HOOK_INPUT.
# A hook gets exactly one shot at stdin; cache it immediately so later helpers
# can still call hook_field without a live stream.
# On Grok, camelCase event fields are normalized to snake_case after reading
# so all downstream policy code uses the same field paths.
hook_input() {
    _HOOK_INPUT="$(cat)"
    [ "$_SLOPGUARD_RUNTIME" = "grok" ] && _hook_normalize_grok
}

# _hook_normalize_grok — map Grok camelCase fields to canonical snake_case.
# Grok sends sessionId, hookEventName, toolName, toolInput alongside cwd and
# workspaceRoot.  Policies reference snake_case names throughout; normalize once
# at the boundary rather than adding fallbacks to every hook script.
_hook_normalize_grok() {
    _HOOK_INPUT="$(printf '%s' "$_HOOK_INPUT" | jq -c '
        if (.sessionId != null) and (.session_id == null)
            then .session_id = .sessionId else . end
        | if (.hookEventName != null) and (.hook_event_name == null)
            then .hook_event_name = .hookEventName else . end
        | if (.toolName != null) and (.tool_name == null)
            then .tool_name = .toolName else . end
        | if (.toolInput != null) and (.tool_input == null)
            then .tool_input = .toolInput else . end
    ')"
}

# hook_field <jq-path>
# Extract a field from the cached hook payload.  Returns empty string for
# null or missing values so callers can use [ -z "$(hook_field .x)" ].
hook_field() {
    printf '%s' "$_HOOK_INPUT" | jq -r "${1} // empty"
}

# hook_deny <reason>
# Policy denial in balanced/strict mode; advisory mode reports context instead.
hook_deny() {
    if [ "${CLAUDE_PLUGIN_OPTION_ENFORCEMENT_MODE:-balanced}" = "advisory" ]; then
        hook_context "$1"
    else
        hook_secret_deny "$1"
    fi
}

# hook_secret_deny <reason>
# Secrets are the sole advisory-mode exception and always fail closed.
# Claude/Codex: hookSpecificOutput envelope.  Grok: native {"decision","reason"}.
hook_secret_deny() {
    if [ "$_SLOPGUARD_RUNTIME" = "grok" ]; then
        jq -n --arg reason "$1" '{"decision":"deny","reason":$reason}'
    else
        jq -n --arg reason "$1" \
            '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":$reason}}'
    fi
}

# hook_ask <reason>
# Ask interactively, deny when headless, or report context in advisory mode.
# On Grok there is no interactive ask response; the decision becomes deny with
# the same reason so the fail-closed contract is preserved.
hook_ask() {
    local reason="$1"
    if [ "${CLAUDE_PLUGIN_OPTION_ENFORCEMENT_MODE:-balanced}" = "advisory" ]; then
        hook_context "$reason"
        return
    fi
    if [ "$_SLOPGUARD_RUNTIME" = "grok" ]; then
        jq -n --arg reason "$reason" '{"decision":"deny","reason":$reason}'
        return
    fi
    local decision="ask"
    if [ "${AISDLC_HEADLESS:-0}" = "1" ]; then
        decision="deny"
        reason="${reason} — no human in this session"
    fi
    jq -n --arg decision "$decision" --arg reason "$reason" \
        '{"hookSpecificOutput":{"permissionDecision":$decision,"permissionDecisionReason":$reason}}'
}

# hook_allow
# Emit an explicit allow.  Usually omitted (default), but useful when a hook
# wants to record context without interfering.
# On Grok, exit 0 with no output is the allow signal; no JSON envelope needed.
hook_allow() {
    [ "$_SLOPGUARD_RUNTIME" = "grok" ] && return 0
    jq -n '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
}

# hook_context <text>
# Add context that Claude sees alongside the tool result (PreToolUse,
# PostToolUse, PostToolBatch) or at turn end (Stop).
# Write as a statement of fact, not as a command (§3.2).
# On Grok, passive context has no equivalent; return silently (fail-open).
hook_context() {
    [ "$_SLOPGUARD_RUNTIME" = "grok" ] && return 0
    jq -n --arg text "$1" \
        '{"hookSpecificOutput":{"additionalContext":$text}}'
}

# hook_message <text>
# Surface a warning visible to the user (systemMessage).
# No equivalent on Grok; return silently.
hook_message() {
    [ "$_SLOPGUARD_RUNTIME" = "grok" ] && return 0
    jq -n --arg text "$1" \
        '{"systemMessage":$text}'
}
