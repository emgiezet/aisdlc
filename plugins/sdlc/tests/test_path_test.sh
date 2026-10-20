#!/usr/bin/env bash
# test_path_test.sh — which changed paths the verify gate counts as tests (_is_test_path in
# bin/aisdlc). A test file it misses makes every UC read as untested; a source file it
# accepts lets an untested UC through.
#
# Sourced by tests/run-tests, which defines ok()/bad(). Runs standalone too.

if ! declare -F ok > /dev/null 2>&1; then
    PASS=0; FAIL=0
    ok()  { printf '  ok    %s\n' "$1"; PASS=$((PASS + 1)); }
    bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }
    _standalone=1
fi

_TP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=../bin/aisdlc
. "${_TP_DIR}/../bin/aisdlc"

printf 'verify: test file detection\n'

for p in evals/harness/selftest.sh selftest.sh scripts/deploy_test.sh lib/test_parse.sh \
         hooks/guard.bats plugins/x/tests/run-tests pkg/stub_test.go src/a.test.ts app/test_api.py; do
    _is_test_path "$p" && ok "test path: $p" || bad "test path: $p" "not counted as a test"
done

for p in evals/harness/run.sh scripts/latest.sh lib/contest.sh plugins/sdlc/bin/aisdlc \
         src/testing.ts docs/test-plan.md; do
    _is_test_path "$p" && bad "source path: $p" "counted as a test" || ok "source path: $p"
done

if [ "${_standalone:-0}" = "1" ]; then
    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ] || exit 1
fi
