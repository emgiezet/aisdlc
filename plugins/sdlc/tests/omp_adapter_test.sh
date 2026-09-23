#!/usr/bin/env bash
# omp_adapter_test.sh — shell wrapper for the sdlc omp adapter node:test suite.
#
# Runs node --test and parses TAP output into ok()/bad() calls so the results
# integrate with the sdlc test runner's PASS/FAIL counters.
#
# Standalone:  ./omp_adapter_test.sh — defines ok()/bad() and exits 1 on failure.
# Sourced:     test runner must define ok()/bad() before sourcing this file.
set -uo pipefail

_SDLC_OMP_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Standalone mode: define counters when not inherited from a test runner.
if ! declare -f ok >/dev/null 2>&1; then
    PASS=0; FAIL=0
    ok()  { printf '  ok    %s\n' "$1"; PASS=$((PASS + 1)); }
    bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }
    _SDLC_OMP_STANDALONE=1
fi

# Run node:test with TAP reporter; suppress non-TAP diagnostic output.
_omp_tap=""
_omp_rc=0
_omp_tap="$(node --test-reporter=tap --test \
    "${_SDLC_OMP_TESTS_DIR}/omp_adapter_test.mjs" 2>/dev/null)" \
    || _omp_rc=$?

# Parse TAP lines and emit ok()/bad() per test case.
_omp_parsed=0
while IFS= read -r _line; do
    case "$_line" in
        "ok "[0-9]*" - "*)
            _tname="${_line#ok [0-9]* - }"
            _tname="${_tname%%#*}"
            _tname="$(printf '%s' "$_tname" | sed 's/[[:space:]]*$//')"
            ok "omp adapter: ${_tname}"
            _omp_parsed=$((_omp_parsed + 1))
            ;;
        "not ok "[0-9]*" - "*)
            _tname="${_line#not ok [0-9]* - }"
            _tname="${_tname%%#*}"
            _tname="$(printf '%s' "$_tname" | sed 's/[[:space:]]*$//')"
            bad "omp adapter: ${_tname}" "node --test reported failure (rc=${_omp_rc})"
            _omp_parsed=$((_omp_parsed + 1))
            ;;
    esac
done <<< "$_omp_tap"

# Guard against silent failure (syntax error, import error, etc.)
if [ "$_omp_parsed" -eq 0 ]; then
    bad "omp adapter: test suite" \
        "no TAP output from node --test (rc=${_omp_rc}) — check omp_adapter_test.mjs"
fi

unset _omp_tap _omp_rc _omp_parsed _line _tname _SDLC_OMP_TESTS_DIR

if [ "${_SDLC_OMP_STANDALONE:-0}" = "1" ]; then
    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ] || exit 1
fi
