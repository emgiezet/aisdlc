#!/usr/bin/env bash
# guard_stop_test.sh — guard stop: retired-tests ledger and skip-marker detection.
#
# Each case builds a throwaway repo (default branch 'main' with committed tests, then a
# feature branch) and runs hooks/guard stop from inside it.
#
# Standalone:  ./guard_stop_test.sh  — defines ok()/bad() and exits 1 on failure.
# Sourced:     test runner must define ok()/bad() before sourcing this file.
set -uo pipefail

_SDLC_GS_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_SDLC_GS_GUARD="$(cd "${_SDLC_GS_TESTS_DIR}/.." && pwd)/hooks/guard"

if ! declare -f ok >/dev/null 2>&1; then
    PASS=0; FAIL=0
    ok()  { printf '  ok    %s\n' "$1"; PASS=$((PASS + 1)); }
    bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }
    _SDLC_GS_STANDALONE=1
fi

# No EXIT trap: sibling suites sourced by run-tests own theirs. Cleaned at the end.
_SDLC_GS_WORK="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-guard-stop-XXXXXX")"

_gs_git() { git -c user.email=guard@localhost -c user.name=guard -c commit.gpgsign=false "$@"; }

# _gs_repo NAME [LEDGER_ON_MAIN] — fresh repo on a feature branch; prints its path.
_gs_repo() {
    local dir="${_SDLC_GS_WORK}/$1"
    mkdir -p "$dir/tests" "$dir/src"
    (
        cd "$dir" || exit 1
        _gs_git init -q -b main
        printf 'def test_a():\n    assert 1\n' > tests/test_a.py
        printf 'def test_b():\n    assert 1\n' > tests/test_b.py
        printf 'def main():\n    return 0\n' > src/app.py
        if [ -n "${2:-}" ]; then
            mkdir -p .claude && printf '%s\n' "$2" > .claude/retired-tests
        fi
        _gs_git add -A && _gs_git commit -q -m base
        _gs_git switch -q -c feature
    )
    printf '%s' "$dir"
}

# _gs_stop DIR [HEADLESS] — run guard stop in DIR; sets _gs_rc and _gs_err.
_gs_rc=0
_gs_err=""
_gs_stop() {
    local dir="$1" headless="${2:-}"
    (
        cd "$dir" || exit 1
        if [ -n "$headless" ]; then
            printf '{"stop_hook_active":false}' | env -u GROK_PLUGIN_ROOT \
                CLAUDE_PLUGIN_ROOT=/unused AISDLC_HEADLESS=1 bash "$_SDLC_GS_GUARD" stop
        else
            printf '{"stop_hook_active":false}' | env -u GROK_PLUGIN_ROOT -u AISDLC_HEADLESS \
                CLAUDE_PLUGIN_ROOT=/unused bash "$_SDLC_GS_GUARD" stop
        fi
    ) 2>"${_SDLC_GS_WORK}/err" && _gs_rc=0 || _gs_rc=$?
    _gs_err="$(cat "${_SDLC_GS_WORK}/err")"
}

_gs_ledger() { mkdir -p "$1/.claude" && printf '%s\n' "$2" > "$1/.claude/retired-tests"; }

# ─── Retired-tests ledger ────────────────────────────────────────────────────

_d="$(_gs_repo ledger-reason)"
_gs_git -C "$_d" rm -q tests/test_a.py
_gs_ledger "$_d" 'tests/test_a.py  folded into tests/test_b.py by the parser refactor'
_gs_stop "$_d"
[ "$_gs_rc" -eq 0 ] && printf '%s' "$_gs_err" | grep -qF 'retired via .claude/retired-tests' \
    && ok  "stop: deletion listed with a reason passes and is reported as retired" \
    || bad "stop: deletion listed with a reason passes" "rc=${_gs_rc} err=${_gs_err}"

_d="$(_gs_repo ledger-no-reason)"
_gs_git -C "$_d" rm -q tests/test_a.py
_gs_ledger "$_d" 'tests/test_a.py'
_gs_stop "$_d"
[ "$_gs_rc" -eq 2 ] && printf '%s' "$_gs_err" | grep -qF -- '- tests/test_a.py' \
    && ok  "stop: ledger entry without a reason does not retire the test" \
    || bad "stop: ledger entry without a reason" "rc=${_gs_rc} err=${_gs_err}"

_d="$(_gs_repo ledger-glob)"
_gs_git -C "$_d" rm -q tests/test_a.py tests/test_b.py
_gs_ledger "$_d" '# obsolete client tests
tests/test_*.py  the client they covered was removed in the same change'
_gs_stop "$_d"
[ "$_gs_rc" -eq 0 ] \
    && ok  "stop: glob entry retires every matching deletion; comment lines ignored" \
    || bad "stop: glob entry" "rc=${_gs_rc} err=${_gs_err}"

_d="$(_gs_repo ledger-partial)"
_gs_git -C "$_d" rm -q tests/test_a.py tests/test_b.py
_gs_ledger "$_d" 'tests/test_a.py  obsolete'
_gs_stop "$_d"
[ "$_gs_rc" -eq 2 ] && printf '%s' "$_gs_err" | grep -qF -- '- tests/test_b.py' \
    && ! printf '%s' "$_gs_err" | grep -qF -- '- tests/test_a.py' \
    && ok  "stop: only unlisted deletions are reported" \
    || bad "stop: partial ledger" "rc=${_gs_rc} err=${_gs_err}"

_d="$(_gs_repo headless-self-approved)"
_gs_git -C "$_d" rm -q tests/test_a.py
_gs_ledger "$_d" 'tests/test_a.py  obsolete'
_gs_stop "$_d" headless
[ "$_gs_rc" -eq 2 ] && printf '%s' "$_gs_err" | grep -qF 'cannot add that entry for itself' \
    && ok  "stop (headless): a ledger entry written during the run is ignored" \
    || bad "stop (headless): self-approved ledger" "rc=${_gs_rc} err=${_gs_err}"

_d="$(_gs_repo headless-approved-on-main 'tests/test_a.py  retired by the maintainer')"
_gs_git -C "$_d" rm -q tests/test_a.py
_gs_stop "$_d" headless
[ "$_gs_rc" -eq 0 ] \
    && ok  "stop (headless): a ledger entry committed on the default branch retires the test" \
    || bad "stop (headless): ledger on main" "rc=${_gs_rc} err=${_gs_err}"

# ─── Skip and focus markers ──────────────────────────────────────────────────

_d="$(_gs_repo skip-false-positives)"
printf 'import sys\n\ndef test_exit():\n    raise SystemExit(1)\n' >> "$_d/tests/test_b.py"
printf '    it.skip("not a test file")\n' >> "$_d/src/app.py"
_gs_stop "$_d"
[ "$_gs_rc" -eq 0 ] \
    && ok  "stop: SystemExit( in a test and a skip marker outside test files are not flagged" \
    || bad "stop: skip false positives" "rc=${_gs_rc} err=${_gs_err}"

_d="$(_gs_repo skip-focus)"
printf "xit('renders', () => {});\n" > "$_d/tests/app.test.js"
_gs_git -C "$_d" add tests/app.test.js
_gs_stop "$_d"
[ "$_gs_rc" -eq 2 ] && printf '%s' "$_gs_err" | grep -qF "+ xit('renders'" \
    && ok  "stop: xit( added to a test file is flagged" \
    || bad "stop: xit( in a test file" "rc=${_gs_rc} err=${_gs_err}"

_d="$(_gs_repo skip-not-retirable)"
printf '\nimport pytest\n\n@pytest.mark.skip\ndef test_c():\n    assert 0\n' >> "$_d/tests/test_b.py"
_gs_ledger "$_d" 'tests/test_b.py  refactor'
_gs_stop "$_d"
[ "$_gs_rc" -eq 2 ] && printf '%s' "$_gs_err" | grep -qF '@pytest.mark.skip' \
    && ok  "stop: the ledger does not excuse a skipped test" \
    || bad "stop: ledger vs skip" "rc=${_gs_rc} err=${_gs_err}"

rm -rf "$_SDLC_GS_WORK"
unset _d _gs_rc _gs_err

if [ "${_SDLC_GS_STANDALONE:-0}" = "1" ]; then
    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ] || exit 1
fi
