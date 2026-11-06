#!/usr/bin/env bash
# guard_write_test.sh — guard pre-write: the planning-mode marker a decision map holds.
#
# Each case builds a throwaway repo and runs hooks/guard pre-write from inside it.
#
# Standalone:  ./guard_write_test.sh  — defines ok()/bad() and exits 1 on failure.
# Sourced:     test runner must define ok()/bad() before sourcing this file.
set -uo pipefail

_SDLC_GW_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_SDLC_GW_GUARD="$(cd "${_SDLC_GW_TESTS_DIR}/.." && pwd)/hooks/guard"

if ! declare -f ok >/dev/null 2>&1; then
    PASS=0; FAIL=0
    ok()  { printf '  ok    %s\n' "$1"; PASS=$((PASS + 1)); }
    bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }
    _SDLC_GW_STANDALONE=1
fi

# No EXIT trap: sibling suites sourced by run-tests own theirs. Cleaned at the end.
_SDLC_GW_WORK="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-guard-write-XXXXXX")"

# _gw_repo NAME [MARKER] — fresh repo with specs/briefs/ and src/; MARKER set → planning mode on.
_gw_repo() {
    local dir="${_SDLC_GW_WORK}/$1"
    mkdir -p "$dir/specs/briefs" "$dir/src"
    git -C "$dir" init -q -b main
    if [ -n "${2:-}" ]; then
        mkdir -p "$dir/.aisdlc"
        printf 'map: specs/briefs/map-x.md\nsince: %s\nallow: specs/ .aisdlc/\n' \
            "$(date -u +%FT%TZ)" > "$dir/.aisdlc/planning-mode"
    fi
    printf '%s' "$dir"
}

# _gw_write DIR PATH [grok] — run guard pre-write in DIR; sets _gw_rc, _gw_out, _gw_err.
_gw_rc=0
_gw_out=""
_gw_err=""
_gw_write() {
    local dir="$1" path="$2" grok="${3:-}"
    _gw_out="$( (
        cd "$dir" || exit 1
        if [ -n "$grok" ]; then
            printf '{"toolInput":{"file_path":"%s"}}' "$path" | env -u CLAUDE_PLUGIN_ROOT \
                GROK_PLUGIN_ROOT=/unused bash "$_SDLC_GW_GUARD" pre-write
        else
            printf '{"tool_input":{"file_path":"%s"}}' "$path" | env -u GROK_PLUGIN_ROOT \
                CLAUDE_PLUGIN_ROOT=/unused bash "$_SDLC_GW_GUARD" pre-write
        fi
    ) 2>"${_SDLC_GW_WORK}/err" )" && _gw_rc=0 || _gw_rc=$?
    _gw_err="$(cat "${_SDLC_GW_WORK}/err")"
}

_d="$(_gw_repo no-marker)"
_gw_write "$_d" src/app.py
[ "$_gw_rc" -eq 0 ] \
    && ok  "guard pre-write UC-1: no marker — writes pass" \
    || bad "guard pre-write UC-1" "rc=${_gw_rc} err=${_gw_err}"

_d="$(_gw_repo marker-src on)"
_gw_write "$_d" src/app.py
[ "$_gw_rc" -eq 2 ] && printf '%s' "$_gw_err" | grep -qF 'planning mode' \
    && ok  "guard pre-write UC-2: marker present — a write outside allow: is denied" \
    || bad "guard pre-write UC-2" "rc=${_gw_rc} err=${_gw_err}"

_d="$(_gw_repo marker-map on)"
_gw_write "$_d" specs/briefs/map-x.md
[ "$_gw_rc" -eq 0 ] \
    && ok  "guard pre-write UC-3: marker present — the map file under allow: passes" \
    || bad "guard pre-write UC-3" "rc=${_gw_rc} err=${_gw_err}"

_d="$(_gw_repo marker-self on)"
_gw_write "$_d" "$_d/.aisdlc/planning-mode"
[ "$_gw_rc" -eq 0 ] \
    && ok  "guard pre-write UC-4: marker present — the marker itself (absolute path) passes" \
    || bad "guard pre-write UC-4" "rc=${_gw_rc} err=${_gw_err}"

_d="$(_gw_repo marker-stale on)"
touch -d '13 hours ago' "$_d/.aisdlc/planning-mode"
_gw_write "$_d" src/app.py
[ "$_gw_rc" -eq 0 ] && printf '%s' "$_gw_err" | grep -qF 'stale' \
    && ok  "guard pre-write UC-5: marker older than 12 h — allowed with a stale advisory" \
    || bad "guard pre-write UC-5" "rc=${_gw_rc} err=${_gw_err}"

_d="$(_gw_repo marker-grok on)"
_gw_write "$_d" src/app.py grok
[ "$_gw_rc" -eq 0 ] && printf '%s' "$_gw_out" | jq -e '.decision=="deny"' >/dev/null 2>&1 \
    && ok  "guard pre-write UC-6: Grok camelCase payload — deny decision on stdout" \
    || bad "guard pre-write UC-6" "rc=${_gw_rc} out=${_gw_out} err=${_gw_err}"

_d="$(_gw_repo marker-dotdot on)"
_gw_write "$_d" specs/../src/app.py
[ "$_gw_rc" -eq 2 ] \
    && ok  "guard pre-write UC-7: 'specs/../src' does not pass as an allow: prefix" \
    || bad "guard pre-write UC-7" "rc=${_gw_rc} err=${_gw_err}"

# _gw_payload DIR JSON [grok] — run guard pre-write in DIR with a full tool_input object.
_gw_payload() {
    local dir="$1" ti="$2" grok="${3:-}"
    _gw_out="$( (
        cd "$dir" || exit 1
        if [ -n "$grok" ]; then
            jq -n --argjson t "$ti" '{toolInput: $t}' | env -u CLAUDE_PLUGIN_ROOT \
                GROK_PLUGIN_ROOT=/unused bash "$_SDLC_GW_GUARD" pre-write
        else
            jq -n --argjson t "$ti" '{tool_input: $t}' | env -u GROK_PLUGIN_ROOT \
                CLAUDE_PLUGIN_ROOT=/unused bash "$_SDLC_GW_GUARD" pre-write
        fi
    ) 2>"${_SDLC_GW_WORK}/err" )" && _gw_rc=0 || _gw_rc=$?
    _gw_err="$(cat "${_SDLC_GW_WORK}/err")"
}

_d="$(_gw_repo approve-edit)"
_gw_payload "$_d" '{"file_path":"specs/X-1/spec.md","old_string":"status: draft","new_string":"status: approved"}'
[ "$_gw_rc" -eq 2 ] && printf '%s' "$_gw_err" | grep -qF "approval is the human's signature" \
    && ok  "guard pre-write UC-8: an Edit flipping a spec to approved is denied" \
    || bad "guard pre-write UC-8" "rc=${_gw_rc} err=${_gw_err}"

_d="$(_gw_repo approve-multiedit)"
_gw_payload "$_d" '{"file_path":"specs/X-1/spec.md","edits":[{"old_string":"a","new_string":"b"},{"old_string":"status: draft","new_string":"status: \"approved\""}]}'
[ "$_gw_rc" -eq 2 ] \
    && ok  "guard pre-write UC-9: a quoted approval in a later MultiEdit edit is denied" \
    || bad "guard pre-write UC-9" "rc=${_gw_rc} err=${_gw_err}"

_d="$(_gw_repo approve-draft)"
_gw_payload "$_d" '{"file_path":"specs/X-1/spec.md","content":"---\nticket: X-1\nstatus: draft\n---\n"}'
[ "$_gw_rc" -eq 0 ] \
    && ok  "guard pre-write UC-10: writing a draft spec passes" \
    || bad "guard pre-write UC-10" "rc=${_gw_rc} err=${_gw_err}"

_d="$(_gw_repo approve-notspec)"
_gw_payload "$_d" '{"file_path":"specs/X-1/qa-report.md","content":"status: approved\n"}'
[ "$_gw_rc" -eq 0 ] \
    && ok  "guard pre-write UC-11: the same line outside a spec.md passes" \
    || bad "guard pre-write UC-11" "rc=${_gw_rc} err=${_gw_err}"

_d="$(_gw_repo approve-specsdir)"
mkdir -p "$_d/.aisdlc" && printf '{"specs_dir":"docs/specs"}\n' > "$_d/.aisdlc/config.json"
_gw_payload "$_d" '{"file_path":"docs/specs/X-1/spec.md","content":"status: approved\n"}'
[ "$_gw_rc" -eq 2 ] \
    && ok  "guard pre-write UC-12: a configured specs_dir is fenced too" \
    || bad "guard pre-write UC-12" "rc=${_gw_rc} err=${_gw_err}"

_d="$(_gw_repo approve-dotdot)"
_gw_payload "$_d" '{"file_path":"src/../specs/X-1/spec.md","content":"status: approved\n"}'
[ "$_gw_rc" -eq 2 ] \
    && ok  "guard pre-write UC-13: 'src/../specs/X/spec.md' is resolved before the fence" \
    || bad "guard pre-write UC-13" "rc=${_gw_rc} err=${_gw_err}"

_d="$(_gw_repo approve-grok)"
_gw_payload "$_d" '{"file_path":"specs/X-1/spec.md","content":"status: approved\n"}' grok
[ "$_gw_rc" -eq 0 ] && printf '%s' "$_gw_out" | jq -e '.decision=="deny"' >/dev/null 2>&1 \
    && ok  "guard pre-write UC-14: Grok — the approval deny is a decision on stdout" \
    || bad "guard pre-write UC-14" "rc=${_gw_rc} out=${_gw_out} err=${_gw_err}"

_d="$(_gw_repo approve-planning on)"
_gw_payload "$_d" '{"file_path":"specs/X-1/spec.md","content":"status: approved\n"}'
[ "$_gw_rc" -eq 2 ] && printf '%s' "$_gw_err" | grep -qF "approval is the human's signature" \
    && ok  "guard pre-write UC-15: a planning map's allow: specs/ does not let an approval through" \
    || bad "guard pre-write UC-15" "rc=${_gw_rc} err=${_gw_err}"

rm -rf "$_SDLC_GW_WORK"
unset _d _gw_rc _gw_out _gw_err

if [ "${_SDLC_GW_STANDALONE:-0}" = "1" ]; then
    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ] || exit 1
fi
