#!/usr/bin/env bash
# run_test.sh — the eval's measurement spine, tested offline. No aisdlc, no claude, no API cost.
#
# Sources run.sh for its functions (main does not run when sourced) and points the run log, the
# ledger and the baseline at scratch files, so the committed results.jsonl is never touched.
# shellcheck disable=SC2034  # MODELS, SCENARIOS, HARNESS_FP are read by the sourced functions
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$TEST_DIR/run.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/aisdlc-run-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
RUN_LOG="$WORK/run.jsonl"
LEDGER="$WORK/ledger.jsonl"
BASELINE="$WORK/baseline.jsonl"
HARNESS_FP="cccccccccccccccc"

PASS=0
FAIL=0
ok()   { printf '  ok    %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  FAIL  %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# A minimal tree carrying every harness path, one file each.
make_tree() {
    local root="$1" p
    for p in $HARNESS_PATHS; do
        case "$p" in
            *.md) mkdir -p "$root/$(dirname "$p")"; printf 'policy\n' > "$root/$p" ;;
            *)    mkdir -p "$root/$p"; printf 'x\n' > "$root/$p/file.md" ;;
        esac
    done
}

# --------------------------------------------------------------------------- #
printf 'harness_fingerprint\n'
make_tree "$WORK/tree"
fp1="$(harness_fingerprint "$WORK/tree")"
fp2="$(harness_fingerprint "$WORK/tree")"
printf 'policy!\n' > "$WORK/tree/evals/fixtures/sandbox/CLAUDE.md"
fp3="$(harness_fingerprint "$WORK/tree")"
if [ "${#fp1}" -eq 16 ] && [ "$fp1" = "$fp2" ] && [ "$fp1" != "$fp3" ]; then
    ok "stable across calls, moves when the sandbox CLAUDE.md changes"
else
    bad "fingerprint stability" "fp1=$fp1 fp2=$fp2 fp3=$fp3"
fi

make_tree "$WORK/partial"
rm -rf "$WORK/partial/plugins/sdlc/skills"
err="$( (harness_fingerprint "$WORK/partial") 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$err" | grep -q 'harness surface missing: plugins/sdlc/skills'; then
    ok "a missing harness path stops with its name"
else
    bad "missing path" "rc=$rc err=$err"
fi

# --------------------------------------------------------------------------- #
printf '\ninputs_fingerprint\n'
mkdir -p "$WORK/scen-a" "$WORK/other/scen-b"
printf '{"ticket":"SBX-1"}\n' | tee "$WORK/scen-a/scenario.json" > "$WORK/other/scen-b/scenario.json"
printf 'spec\n' | tee "$WORK/scen-a/spec.md" > "$WORK/other/scen-b/spec.md"
ia="$(inputs_fingerprint "$WORK/scen-a")"
ib="$(inputs_fingerprint "$WORK/other/scen-b")"
[ -n "$ia" ] && [ "$ia" = "$ib" ] \
    && ok "same files in differently named directories digest identically" \
    || bad "inputs path independence" "a=$ia b=$ib"

# --------------------------------------------------------------------------- #
printf '\nrecord_cell\n'
: > "$RUN_LOG"; : > "$LEDGER"
record_cell go-endpoint haiku 1111111111111111 no-task ERROR false "" "" 0 7 ""
jq -e '.gradeable == false and .assertions_passed == null and .assertions_failed == null' \
    "$RUN_LOG" >/dev/null \
    && ok "an ungradeable cell records null assertions, never 0" \
    || bad "ungradeable nulls" "$(cat "$RUN_LOG")"

: > "$RUN_LOG"; : > "$LEDGER"
printf '{"old":true}\n' > "$LEDGER"
record_cell go-endpoint haiku 1111111111111111 "done" FAIL true 3 2 0.25 41 claude
keys='["aisdlc_version","assertions_failed","assertions_passed","cost_usd","gradeable","harness",
       "inputs","model","runtime","scenario","seconds","status","ts","verdict"]'
if [ "$(wc -l < "$RUN_LOG")" -eq 1 ] && [ "$(wc -l < "$LEDGER")" -eq 2 ] \
    && [ "$(sed -n 2p "$LEDGER")" = "$(cat "$RUN_LOG")" ] \
    && jq -e --argjson k "$keys" \
        '(keys == $k) and .harness == "cccccccccccccccc" and .assertions_passed == 3
         and .assertions_failed == 2 and .cost_usd == 0.25 and .seconds == 41' \
        "$RUN_LOG" >/dev/null; then
    ok "one line appended to run log and ledger, history kept, every key present"
else
    bad "record_cell append" "run=$(cat "$RUN_LOG") ledger=$(cat "$LEDGER")"
fi

# --------------------------------------------------------------------------- #
printf '\nassert_run_identity\n'
MODELS="haiku"
SCENARIOS="go-endpoint ui-flow"
printf '{"scenario":"go-endpoint","model":"haiku"}\n' > "$RUN_LOG"
out="$(assert_run_identity)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'missing cell: ui-flow × haiku' \
    && ok "a cell that never ran fails the run and is named" \
    || bad "identity missing" "rc=$rc out=$out"

printf '{"scenario":"go-endpoint","model":"haiku"}\n{"scenario":"go-endpoint","model":"haiku"}\n' > "$RUN_LOG"
SCENARIOS="go-endpoint"
out="$(assert_run_identity)"; rc=$?
[ "$rc" -ne 0 ] \
    && printf '%s' "$out" | grep -q 'duplicate cell: go-endpoint × haiku — one record overwrote another' \
    && ok "a duplicated cell fails the run and is named" \
    || bad "identity duplicate" "rc=$rc out=$out"

printf '{"scenario":"go-endpoint","model":"haiku"}\n{"scenario":"ui-flow","model":"haiku"}\n' > "$RUN_LOG"
SCENARIOS="go-endpoint ui-flow"
out="$(assert_run_identity)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] \
    && ok "one record per requested cell passes silently" \
    || bad "identity complete" "rc=$rc out=$out"

# --------------------------------------------------------------------------- #
printf '\nbaseline_delta\n'
I=1111111111111111; A=aaaaaaaaaaaaaaaa; B=bbbbbbbbbbbbbbbb
prior() { # inputs harness verdict [gradeable]
    printf '{"scenario":"go-endpoint","model":"haiku","inputs":"%s","harness":"%s","gradeable":%s,"verdict":"%s"}\n' \
        "$1" "$2" "${4:-true}" "$3"
}
check_delta() { # label expected current-verdict [current-gradeable]
    local got
    got="$(baseline_delta go-endpoint haiku "$I" "$B" "$3" "${4:-true}")"
    [ "$got" = "$2" ] && ok "$1" || bad "$1" "expected '$2', got '$got'"
}

prior "$I" "$A" FAIL > "$BASELINE"
check_delta "FAIL on another harness, PASS now → improved" 'FAIL→PASS improved' PASS
prior "$I" "$A" PASS > "$BASELINE"
check_delta "PASS on another harness, FAIL now → regressed" 'PASS→FAIL REGRESSED' FAIL
check_delta "same verdict on another harness → unchanged arrow" 'PASS→PASS' PASS
prior "2222222222222222" "$A" FAIL > "$BASELINE"
check_delta "a prior on edited inputs is not comparable" 'new' PASS
prior "$I" "$B" FAIL > "$BASELINE"
check_delta "a prior on this harness is a rerun, not a comparison" 'same harness' PASS
{ prior "$I" "$A" FAIL; prior "$I" "$B" PASS; } > "$BASELINE"
check_delta "a newer rerun does not hide the older different-harness baseline" 'FAIL→PASS improved' PASS
{ prior "$I" "$A" PASS; prior "$I" "$A" FAIL; } > "$BASELINE"
check_delta "the newest different-harness record is the baseline" 'FAIL→PASS improved' PASS
prior "$I" "$A" ERROR false > "$BASELINE"
check_delta "an ungradeable prior is no baseline" 'new' PASS
: > "$BASELINE"
check_delta "an empty ledger → new" 'new' PASS
prior "$I" "$A" PASS > "$BASELINE"
check_delta "an ungradeable current cell has no delta" '—' ERROR false

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
