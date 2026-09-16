#!/usr/bin/env bash
# lib/hook.sh — hook I/O contract: stdin decode, response encode, exit codes.
#
# §3.2: a hook receives JSON on stdin exactly once; read it here and cache it so
# nothing downstream consumes the stream (aisdlc:318-320 exists for this reason).
#
# Public interface:
#   hook_input               — read stdin once into _HOOK_INPUT (call at entry)
#   hook_field  <jq-path>    — extract a field; empty for null/missing
#   hook_deny   <reason>     — print permissionDecision:deny JSON to stdout
#   hook_ask    <reason>     — print permissionDecision:ask JSON to stdout
#   hook_allow               — print permissionDecision:allow JSON to stdout
#   hook_context <text>      — print additionalContext JSON to stdout
#   hook_message <text>      — print systemMessage JSON to stdout
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

# Cache for the hook's stdin payload.
_HOOK_INPUT=""

# hook_input — read stdin once into _HOOK_INPUT.
# A hook gets exactly one shot at stdin; cache it immediately so later helpers
# can still call hook_field without a live stream.
hook_input() {
    _HOOK_INPUT="$(cat)"
}

# hook_field <jq-path>
# Extract a field from the cached hook payload.  Returns empty string for
# null or missing values so callers can use [ -z "$(hook_field .x)" ].
hook_field() {
    printf '%s' "$_HOOK_INPUT" | jq -r "${1} // empty"
}

# hook_deny <reason>
# Emit a structured deny decision (exit 0 path).  The reason is safe for
# double-quotes and dollar signs because it passes through jq --arg.
hook_deny() {
    jq -n --arg reason "$1" \
        '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":$reason}}'
}

# hook_ask <reason>
# Ask interactively, or deny explicitly when the queue has no human to answer.
hook_ask() {
    local decision="ask" reason="$1"
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
hook_allow() {
    jq -n '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
}

# hook_context <text>
# Add context that Claude sees alongside the tool result (PreToolUse,
# PostToolUse, PostToolBatch) or at turn end (Stop).
# Write as a statement of fact, not as a command (§3.2).
hook_context() {
    jq -n --arg text "$1" \
        '{"hookSpecificOutput":{"additionalContext":$text}}'
}

# hook_message <text>
# Surface a warning visible to the user (systemMessage).
hook_message() {
    jq -n --arg text "$1" \
        '{"systemMessage":$text}'
}
