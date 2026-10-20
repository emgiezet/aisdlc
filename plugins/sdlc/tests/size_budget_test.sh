#!/usr/bin/env bash
# size_budget_test.sh — change-budget arithmetic in bin/aisdlc: what counts as review
# surface, how a budget resolves, and when the verdict escalates.
#
# Sourced by tests/run-tests, which defines ok()/bad(). Runs standalone too.

if ! declare -F ok > /dev/null 2>&1; then
    PASS=0; FAIL=0
    ok()  { printf '  ok    %s\n' "$1"; PASS=$((PASS + 1)); }
    bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }
    _standalone=1
fi

_SB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=../bin/aisdlc
. "${_SB_DIR}/../bin/aisdlc"

printf 'change budget\n'

# --------------------------------------------------------------------------- #
# _size_stats — measured against a real repository, not a string fixture
# --------------------------------------------------------------------------- #

_sb_repo="$(mktemp -d)"
(
    cd "$_sb_repo" || exit 1
    git init -q -b main
    git config user.email t@localhost; git config user.name t
    mkdir -p services/api services/worker web/app vendor/lib specs/T-1
    printf 'keep\n%.0s' {1..40} > services/api/old.go
    printf 'old\n'                > vendor/lib/dep.go
    printf '{"a":1}\n'            > package-lock.json
    git add -A && git commit -q -m base
    git update-ref refs/remotes/origin/main HEAD

    git checkout -q -b work
    printf 'new\n%.0s' {1..30} > services/api/new.go          # 30 added, counts
    printf 'new\n%.0s' {1..5}  > services/worker/job.go       # 5 added, counts
    printf 'new\n%.0s' {1..7}  > web/app/page.tsx             # 7 added, counts
    printf 'new\n%.0s' {1..99} > vendor/lib/generated.go      # vendored, excluded
    printf '{"a":2,"b":3}\n'   > package-lock.json            # lock file, excluded
    printf 'dep\n%.0s' {1..20} > uv.lock                       # GH-50 UC-1: uv lock file excluded, 20 lines must not appear in added total
    printf 'spec\n%.0s' {1..50} > specs/T-1/spec.md           # spec artefact, excluded
    : > services/api/old.go                                    # 40 deletions, never counted
    git add -A && git commit -q -m work
) > /dev/null 2>&1

_sb_stats="$(_size_stats "$_sb_repo" "origin/main" "specs")"
read -r _sb_added _sb_files _sb_mods _sb_modlist <<< "$_sb_stats"

[ "$_sb_added" = "42" ] \
    && ok "GH-50 UC-2: size: added lines count code only (30+5+7)" \
    || bad "GH-50 UC-2: size: added lines" "expected 42, got '$_sb_added' (stats: $_sb_stats)"

[ "$_sb_files" = "4" ] \
    && ok "GH-50 UC-2: size: files touched include the emptied file, exclude vendor/lock/specs" \
    || bad "GH-50 UC-2: size: files touched" "expected 4, got '$_sb_files' (stats: $_sb_stats)"

[ "$_sb_mods" = "3" ] \
    && ok "GH-50 UC-2: size: module = first two path segments" \
    || bad "GH-50 UC-2: size: modules touched" "expected 3, got '$_sb_mods' (list: $_sb_modlist)"

case "$_sb_modlist" in
    *services/api*) ok "size: module list names the real directories" ;;
    *) bad "size: module list" "services/api missing from '$_sb_modlist'" ;;
esac

case "$_sb_modlist" in
    *vendor*|*specs*) bad "size: exclusions" "excluded path leaked into '$_sb_modlist'" ;;
    *) ok "size: vendored and spec paths never reach the module list" ;;
esac

rm -rf "$_sb_repo"

# --------------------------------------------------------------------------- #
# _size_eval — the boundary, the escalation, and the shotgun-surgery signal
# --------------------------------------------------------------------------- #

_size_eval 400 10 2 "a/b" 400 20 4 3000 0 > /dev/null; _sb_rc=$?
[ "$_sb_rc" -eq 0 ] \
    && ok "eval: exactly at budget is clean" \
    || bad "eval: at budget" "expected rc 0, got $_sb_rc"

_size_eval 401 10 2 "a/b" 400 20 4 3000 0 > /dev/null; _sb_rc=$?
[ "$_sb_rc" -eq 1 ] \
    && ok "eval: one line over budget is GAPS" \
    || bad "eval: over budget" "expected rc 1, got $_sb_rc"

_size_eval 3001 40 6 "a/b" 400 20 4 3000 0 > /dev/null; _sb_rc=$?
[ "$_sb_rc" -eq 2 ] \
    && ok "eval: past the hard ceiling is BLOCKED" \
    || bad "eval: ceiling" "expected rc 2, got $_sb_rc"

_sb_out="$(_size_eval 60 12 6 "a/b,c/d" 400 20 4 3000 0)"
case "$_sb_out" in
    *"shotgun surgery"*) ok "eval: thin edits across many modules are named as shotgun surgery" ;;
    *) bad "eval: shotgun surgery" "not reported for 6 modules at 5 lines/file: '$_sb_out'" ;;
esac

_sb_out="$(_size_eval 390 10 3 "a/b" 400 20 4 3000 0)"
[ -z "$_sb_out" ] \
    && ok "eval: a focused change produces no findings" \
    || bad "eval: false positive" "unexpected findings: '$_sb_out'"

_sb_out="$(_size_eval 900 6 2 "a/b" 400 20 4 3000 0)"
case "$_sb_out" in
    *"shotgun surgery"*) bad "eval: shotgun surgery" "fired on a deep change in 2 modules" ;;
    *) ok "eval: a large change inside two modules is over budget but not shotgun surgery" ;;
esac

# --------------------------------------------------------------------------- #
# GH-59: tolerance — boundary, precedence, ceiling, shotgun, display
# --------------------------------------------------------------------------- #

# UC-2a: tolerance=0 explicitly — bare budget limit, no tolerance suffix
_sb_out="$(_size_eval 401 10 2 "a/b" 400 20 4 3000 0)"
case "$_sb_out" in
    *"401 added lines > 400"*) ok "GH-59 UC-2a: tolerance=0 shows bare budget limit" ;;
    *) bad "GH-59 UC-2a: tolerance=0" "unexpected finding: '$_sb_out'" ;;
esac
case "$_sb_out" in
    *"tolerance"*) bad "GH-59 UC-2a" "finding should not mention tolerance: '$_sb_out'" ;;
    *) ok "GH-59 UC-2a: no tolerance suffix when tolerance=0" ;;
esac

# UC-2b, UC-10 (native): real run_scope_check — Tolerance is profile-only;
# profile wins; absent profile Tolerance defaults to 0.
# Fixture: git repo with 181 added lines in src/; spec has budget 120 and an
# attempted Tolerance: 1000% in ## Change budget (parseable, never read by
# run_scope_check); profile has Tolerance: 50%.
_sc_wt="$(mktemp -d)"
git -C "$_sc_wt" init -q
git -C "$_sc_wt" config user.email "test@test"
git -C "$_sc_wt" config user.name "test"
mkdir -p "$_sc_wt/specs/GH-59T" "$_sc_wt/.claude"
printf '## Scope\n\nChange budget: 120 added lines, 20 files, 4 modules\n\nIn:\n- src/\n\n## Change budget\n\n- **Tolerance:** 1000%%\n' \
    > "$_sc_wt/specs/GH-59T/spec.md"
printf '## Change budget\n\n- **Tolerance:** 50%%\n' > "$_sc_wt/.claude/sdlc.md"
git -C "$_sc_wt" add specs/ .claude/
git -C "$_sc_wt" commit -q -m "base"
_sc_base="$(git -C "$_sc_wt" rev-parse HEAD)"
mkdir -p "$_sc_wt/src"
awk 'BEGIN{for(i=1;i<=181;i++) print "x"i}' > "$_sc_wt/src/code.sh"
git -C "$_sc_wt" add src/
git -C "$_sc_wt" commit -q -m "branch: 181 added lines"
# UC-10: run_scope_check reads Tolerance from profile (50), not spec (1000)
mkdir -p "$_sc_wt/.aisdlc/tasks/sc-10"
printf '{}' > "$_sc_wt/.aisdlc/tasks/sc-10/task.json"
run_scope_check "$_sc_wt" "sc-10" "$_sc_wt" "GH-59T" "specs" "$_sc_base" > /dev/null 2>&1
_sc_verdict="$(jq -r '.scope_verdict' "$_sc_wt/.aisdlc/tasks/sc-10/task.json")"
[ "$_sc_verdict" = "GAPS" ] \
    && ok "GH-59 UC-10a: verdict GAPS — profile tolerance=50 → limit 180, 181 is over" \
    || bad "GH-59 UC-10a" "expected GAPS, got '$_sc_verdict'"
_sc_rpt="$(cat "$_sc_wt/specs/GH-59T/scope-report.md")"
case "$_sc_rpt" in
    *"181 added lines > 180 (120 + 50% tolerance)"*) ok "GH-59 UC-10b: scope report uses profile tolerance=50 → effective limit 180" ;;
    *) bad "GH-59 UC-10b" "expected limit 180; got: $(printf '%s' "$_sc_rpt" | grep 'over budget' || echo not found)" ;;
esac
case "$_sc_rpt" in
    *"1320"*|*"1000"*) bad "GH-59 UC-10c: spec Tolerance=1000 not used" "report shows spec-side value" ;;
    *) ok "GH-59 UC-10c: spec-side Tolerance 1000% absent from scope report" ;;
esac
# UC-2b: reuse branch; remove Tolerance from profile → run_scope_check defaults to 0 → bare finding
git -C "$_sc_wt" reset --hard HEAD~1
printf '## Change budget\n\n- **Added lines:** 400\n' > "$_sc_wt/.claude/sdlc.md"
mkdir -p "$_sc_wt/.aisdlc/tasks/sc-2b"
printf '{}' > "$_sc_wt/.aisdlc/tasks/sc-2b/task.json"
run_scope_check "$_sc_wt" "sc-2b" "$_sc_wt" "GH-59T" "specs" "$_sc_base" > /dev/null 2>&1
_sc_rpt2="$(cat "$_sc_wt/specs/GH-59T/scope-report.md")"
case "$_sc_rpt2" in
    *"tolerance"*) bad "GH-59 UC-2b: absent profile Tolerance" "finding mentions tolerance: $(printf '%s' "$_sc_rpt2" | grep -i tolerance || true)" ;;
    *"over budget"*) ok "GH-59 UC-2b: absent profile Tolerance → run_scope_check defaults 0 → bare over-budget finding" ;;
    *) bad "GH-59 UC-2b" "no over-budget finding in scope report" ;;
esac
rm -rf "$_sc_wt"

# --------------------------------------------------------------------------- #
# budget_value — spec beats profile beats built-in default
# --------------------------------------------------------------------------- #

_sb_tmp="$(mktemp -d)"
cat > "$_sb_tmp/spec.md" <<'EOF'
## Scope

Change budget: 120 added lines, 6 files, 2 modules

In:
- something
EOF
cat > "$_sb_tmp/sdlc.md" <<'EOF'
## Change budget

- **Added lines:** 250
- **Files:** 12
- **Modules:** 3
- **Hard ceiling:** 2000
- **Tolerance:** 75%
EOF

[ "$(budget_value "$_sb_tmp/spec.md" "$_sb_tmp/sdlc.md" 'added lines' 'Added lines' 400)" = "120" ] \
    && ok "budget: the spec's own budget wins" \
    || bad "budget: spec precedence" "got '$(budget_value "$_sb_tmp/spec.md" "$_sb_tmp/sdlc.md" 'added lines' 'Added lines' 400)'"

[ "$(budget_value "$_sb_tmp/missing.md" "$_sb_tmp/sdlc.md" 'files' 'Files' 20)" = "12" ] \
    && ok "budget: the profile answers when the spec is silent" \
    || bad "budget: profile fallback" "got '$(budget_value "$_sb_tmp/missing.md" "$_sb_tmp/sdlc.md" 'files' 'Files' 20)'"

[ "$(budget_value "$_sb_tmp/missing.md" "$_sb_tmp/none.md" 'modules' 'Modules' 4)" = "4" ] \
    && ok "budget: the built-in default is the last resort" \
    || bad "budget: default fallback" "got '$(budget_value "$_sb_tmp/missing.md" "$_sb_tmp/none.md" 'modules' 'Modules' 4)'"

[ "$(_budget_profile "$_sb_tmp/sdlc.md" 'Hard ceiling')" = "2000" ] \
    && ok "budget: the repo may lower its own hard ceiling" \
    || bad "budget: ceiling override" "got '$(_budget_profile "$_sb_tmp/sdlc.md" 'Hard ceiling')'"

# UC-9: _budget_profile reads Tolerance; returns empty when label absent
[ "$(_budget_profile "$_sb_tmp/sdlc.md" 'Tolerance')" = "75" ] \
    && ok "GH-59 UC-9a: _budget_profile returns 75 for Tolerance: 75%" \
    || bad "GH-59 UC-9a" "got '$(_budget_profile "$_sb_tmp/sdlc.md" 'Tolerance')'"
[ -z "$(_budget_profile "$_sb_tmp/sdlc.md" 'MissingLabel')" ] \
    && ok "GH-59 UC-9b: _budget_profile returns empty when label absent" \
    || bad "GH-59 UC-9b" "expected empty, got '$(_budget_profile "$_sb_tmp/sdlc.md" 'MissingLabel')'"

rm -rf "$_sb_tmp"

if [ "${_standalone:-0}" = "1" ]; then
    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ] || exit 1
fi
