#!/usr/bin/env bash
# structure_test.sh — SlopCodeBench erosion checks in bin/aisdlc: formula verification,
# hotspot detection, threshold overrides.
#
# Sourced by tests/run-tests, which defines ok()/bad(). Runs standalone too.

if ! declare -F ok > /dev/null 2>&1; then
    _standalone=1
    PASS=0; FAIL=0
    ok()  { printf '  ok    %s\n' "$1"; PASS=$((PASS + 1)); }
    bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }
fi

_ST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=../bin/aisdlc
. "${_ST_DIR}/../bin/aisdlc"

printf 'structure\n'

# ----------- helpers ---------------------------------------------------------

# Extract value from _struct_analyze output: first record of given type.
_st_field() { printf '%s\n' "$1" | awk -F'|' -v t="$2" 'index($0, t "|") == 1 {print $2; exit}'; }

# Count records of given type in _struct_analyze output.
_st_count() { printf '%s\n' "$1" | awk -v t="$2" 'index($0,t"|")==1{n++} END{print n+0}'; }

# Round a raw float to 2 decimal places.
_st_r2() { awk -v v="$1" 'BEGIN { printf "%.2f\n", v+0 }'; }

# --------------------------------------------------------------------------- #
# UC-2 — erosion formula (SlopCodeBench §2.3): named values, erosion finding
# --------------------------------------------------------------------------- #
#
# Two functions in foo.go:
#   Before: FuncA CC=5 NLOC=4,  FuncB CC=5  NLOC=9
#   After:  FuncA CC=5 NLOC=4,  FuncB CC=12 NLOC=9  ← crosses CC 10
#
# Before erosion:
#   mass(A)=5*sqrt(4)=10, mass(B)=5*sqrt(9)=15; total=25, hot=0  →  0/25 = 0.00
# After erosion:
#   mass(A)=5*sqrt(4)=10, mass(B)=12*sqrt(9)=36; total=46, hot=36 → 36/46 = 0.78
# Delta = 0.78 > 0.05 (default max) → erosion finding naming both values

_UC2_BEFORE='NLOC,CCN,token,PARAM,length,location,file,function,long_name,start,end
4,5,50,0,10,foo.go:FuncA,foo.go,FuncA,FuncA,1,10
9,5,80,1,20,foo.go:FuncB,foo.go,FuncB,FuncB,11,30'

_UC2_AFTER='NLOC,CCN,token,PARAM,length,location,file,function,long_name,start,end
4,5,50,0,10,foo.go:FuncA,foo.go,FuncA,FuncA,1,10
9,12,100,1,20,foo.go:FuncB,foo.go,FuncB,FuncB,11,30'

_UC2_RECORDS="$(_struct_analyze "$_UC2_BEFORE" "$_UC2_AFTER" "" "")"

_UC2_BE="$(_st_field "$_UC2_RECORDS" erosion_before)"
_UC2_AE="$(_st_field "$_UC2_RECORDS" erosion_after)"

[ "$(_st_r2 "$_UC2_BE")" = "0.00" ] \
    && ok "UC-2: before erosion equals 0.00 (formula)" \
    || bad "UC-2: before erosion" "expected 0.00, got $(_st_r2 "$_UC2_BE") (raw: $_UC2_BE)"

[ "$(_st_r2 "$_UC2_AE")" = "0.78" ] \
    && ok "UC-2: after erosion equals 0.78 (formula)" \
    || bad "UC-2: after erosion" "expected 0.78, got $(_st_r2 "$_UC2_AE") (raw: $_UC2_AE)"

# erosion finding with default threshold (delta 0.78 > 0.05)
_UC2_SECTION="$(_struct_text "$_UC2_RECORDS" "$BUILTIN_STRUCT_EROSION_MAX" "$BUILTIN_STRUCT_HOTSPOT_MAX")"
case "$_UC2_SECTION" in
    *"erosion:"*"0.00"*"0.78"*) ok "UC-2: erosion finding names before (0.00) and after (0.78)" ;;
    *) bad "UC-2: erosion finding" "expected 'erosion: 0.00 -> 0.78' in section; got: $(printf '%s' "$_UC2_SECTION" | grep erosion)"  ;;
esac

# --------------------------------------------------------------------------- #
# UC-5 — function absent at merge base appears with CC 27
# --------------------------------------------------------------------------- #
#
# BigFunc: absent before → CC=27 after
# Newly crosses CC 10 → new_hotspot record
# Newly crosses CC 25 → hotspot25 record
# Default thresholds: count 1 > max 0 → new hotspot finding; hotspot25 always → hotspot over 25 finding

_UC5_BEFORE=''   # no functions before this revision

_UC5_AFTER='NLOC,CCN,token,PARAM,length,location,file,function,long_name,start,end
100,27,300,3,50,bar.go:BigFunc,bar.go,BigFunc,BigFunc,1,50'

_UC5_RECORDS="$(_struct_analyze "$_UC5_BEFORE" "$_UC5_AFTER" "" "")"

[ "$(_st_count "$_UC5_RECORDS" new_hotspot)" -ge 1 ] \
    && ok "UC-5: new_hotspot record for CC-27 function absent before" \
    || bad "UC-5: new_hotspot" "expected >=1, got $(_st_count "$_UC5_RECORDS" new_hotspot)"

[ "$(_st_count "$_UC5_RECORDS" hotspot25)" -ge 1 ] \
    && ok "UC-5: hotspot25 record for CC-27 function" \
    || bad "UC-5: hotspot25" "expected >=1, got $(_st_count "$_UC5_RECORDS" hotspot25)"

_UC5_SECTION="$(_struct_text "$_UC5_RECORDS" "$BUILTIN_STRUCT_EROSION_MAX" "$BUILTIN_STRUCT_HOTSPOT_MAX")"
case "$_UC5_SECTION" in
    *"new hotspot:"*) ok "UC-5: new hotspot finding emitted" ;;
    *) bad "UC-5: new hotspot finding" "not found; section: $(printf '%s' "$_UC5_SECTION" | grep -i hotspot)" ;;
esac
case "$_UC5_SECTION" in
    *"hotspot over 25:"*) ok "UC-5: hotspot over 25 finding emitted" ;;
    *) bad "UC-5: hotspot over 25 finding" "not found; section: $(printf '%s' "$_UC5_SECTION" | grep -i hotspot)" ;;
esac

# --------------------------------------------------------------------------- #
# UC-6 — function at CC 30 before and after (negative: no new findings)
# --------------------------------------------------------------------------- #
#
# BigOld: CC=30 before AND CC=30 after — NOT newly crossing any threshold.
# Also: erosion before = after (same mass) → delta = 0 → no erosion finding.

_UC6_BEFORE='NLOC,CCN,token,PARAM,length,location,file,function,long_name,start,end
80,30,200,2,40,baz.go:BigOld,baz.go,BigOld,BigOld,1,40'

_UC6_AFTER='NLOC,CCN,token,PARAM,length,location,file,function,long_name,start,end
80,30,200,2,40,baz.go:BigOld,baz.go,BigOld,BigOld,1,40'

_UC6_RECORDS="$(_struct_analyze "$_UC6_BEFORE" "$_UC6_AFTER" "" "")"

[ "$(_st_count "$_UC6_RECORDS" new_hotspot)" -eq 0 ] \
    && ok "UC-6: no new_hotspot for function already at CC 30" \
    || bad "UC-6: no new_hotspot" "got $(_st_count "$_UC6_RECORDS" new_hotspot)"

[ "$(_st_count "$_UC6_RECORDS" hotspot25)" -eq 0 ] \
    && ok "UC-6: no hotspot25 for function already above CC 25" \
    || bad "UC-6: no hotspot25" "got $(_st_count "$_UC6_RECORDS" hotspot25)"

_UC6_SECTION="$(_struct_text "$_UC6_RECORDS" "$BUILTIN_STRUCT_EROSION_MAX" "$BUILTIN_STRUCT_HOTSPOT_MAX")"
case "$_UC6_SECTION" in
    *"### Findings"*) bad "UC-6: no findings" "findings section unexpectedly present" ;;
    *)                ok "UC-6: no structure findings for stable CC 30 function" ;;
esac

# --------------------------------------------------------------------------- #
# UC-7 — custom thresholds (0.5 / 1) suppress finding; section still lists function
# --------------------------------------------------------------------------- #
#
# Scenario: one large stable function (FuncHuge) and GoFunc going CC 8 -> CC 14.
#
#   FuncHuge: CC=2 NLOC=10000 (unchanged)
#   GoFunc:   CC=8 NLOC=100  before; CC=14 NLOC=100 after
#
# Before erosion:
#   mass(Huge)=2*sqrt(10000)=200, mass(Go)=8*sqrt(100)=80; total=280, hot=0 → 0.0000
# After erosion:
#   mass(Huge)=2*sqrt(10000)=200, mass(Go)=14*sqrt(100)=140; total=340, hot=140 → 140/340=0.4118
#
# Delta ≈ 0.41
#   Default thresholds (0.05 / 0): delta > 0.05 → erosion finding; count=1 > 0 → new hotspot finding
#   Custom thresholds (0.5  / 1): delta 0.41 < 0.5 → no erosion finding; count=1 ≤ 1 → no new hotspot

_UC7_BEFORE='NLOC,CCN,token,PARAM,length,location,file,function,long_name,start,end
10000,2,500,0,200,qux.go:FuncHuge,qux.go,FuncHuge,FuncHuge,1,200
100,8,150,2,40,qux.go:GoFunc,qux.go,GoFunc,GoFunc,201,240'

_UC7_AFTER='NLOC,CCN,token,PARAM,length,location,file,function,long_name,start,end
10000,2,500,0,200,qux.go:FuncHuge,qux.go,FuncHuge,FuncHuge,1,200
100,14,200,2,50,qux.go:GoFunc,qux.go,GoFunc,GoFunc,201,250'

_UC7_RECORDS="$(_struct_analyze "$_UC7_BEFORE" "$_UC7_AFTER" "" "")"

# With DEFAULT thresholds: should have findings
_UC7_DEFAULT_S="$(_struct_text "$_UC7_RECORDS" "$BUILTIN_STRUCT_EROSION_MAX" "$BUILTIN_STRUCT_HOTSPOT_MAX")"
case "$_UC7_DEFAULT_S" in
    *"### Findings"*) ok "UC-7 baseline: findings present with default thresholds" ;;
    *) bad "UC-7 baseline" "no findings with default thresholds; section: $(printf '%s' "$_UC7_DEFAULT_S" | head -3)" ;;
esac

# With CUSTOM thresholds (0.5 / 1): no findings
_UC7_CUSTOM_S="$(_struct_text "$_UC7_RECORDS" "0.5" "1")"
case "$_UC7_CUSTOM_S" in
    *"### Findings"*) bad "UC-7: relaxed thresholds" "unexpected findings; section: $(printf '%s' "$_UC7_CUSTOM_S" | grep -A2 Findings)" ;;
    *)                ok "UC-7: no finding with relaxed thresholds (0.5 / 1)" ;;
esac

# Section still lists GoFunc with 8 -> 14 even when no findings
case "$_UC7_CUSTOM_S" in
    *"GoFunc"*"8 -> 14"*) ok "UC-7: section lists GoFunc with CC 8 -> 14 despite no findings" ;;
    *) bad "UC-7: section content" "GoFunc 8 -> 14 not in section; got: $(printf '%s' "$_UC7_CUSTOM_S" | head -6)" ;;
esac

if [ "${_standalone:-0}" = "1" ]; then
    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ] || exit 1
fi
