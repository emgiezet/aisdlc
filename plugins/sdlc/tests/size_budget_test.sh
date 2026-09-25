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
    printf 'spec\n%.0s' {1..50} > specs/T-1/spec.md           # spec artefact, excluded
    : > services/api/old.go                                    # 40 deletions, never counted
    git add -A && git commit -q -m work
) > /dev/null 2>&1

_sb_stats="$(_size_stats "$_sb_repo" "origin/main" "specs")"
read -r _sb_added _sb_files _sb_mods _sb_modlist <<< "$_sb_stats"

[ "$_sb_added" = "42" ] \
    && ok "size: added lines count code only (30+5+7)" \
    || bad "size: added lines" "expected 42, got '$_sb_added' (stats: $_sb_stats)"

[ "$_sb_files" = "4" ] \
    && ok "size: files touched include the emptied file, exclude vendor/lock/specs" \
    || bad "size: files touched" "expected 4, got '$_sb_files' (stats: $_sb_stats)"

[ "$_sb_mods" = "3" ] \
    && ok "size: module = first two path segments" \
    || bad "size: modules touched" "expected 3, got '$_sb_mods' (list: $_sb_modlist)"

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

_size_eval 400 10 2 "a/b" 400 20 4 3000 > /dev/null; _sb_rc=$?
[ "$_sb_rc" -eq 0 ] \
    && ok "eval: exactly at budget is clean" \
    || bad "eval: at budget" "expected rc 0, got $_sb_rc"

_size_eval 401 10 2 "a/b" 400 20 4 3000 > /dev/null; _sb_rc=$?
[ "$_sb_rc" -eq 1 ] \
    && ok "eval: one line over budget is GAPS" \
    || bad "eval: over budget" "expected rc 1, got $_sb_rc"

_size_eval 3001 40 6 "a/b" 400 20 4 3000 > /dev/null; _sb_rc=$?
[ "$_sb_rc" -eq 2 ] \
    && ok "eval: past the hard ceiling is BLOCKED" \
    || bad "eval: ceiling" "expected rc 2, got $_sb_rc"

_sb_out="$(_size_eval 60 12 6 "a/b,c/d" 400 20 4 3000)"
case "$_sb_out" in
    *"shotgun surgery"*) ok "eval: thin edits across many modules are named as shotgun surgery" ;;
    *) bad "eval: shotgun surgery" "not reported for 6 modules at 5 lines/file: '$_sb_out'" ;;
esac

_sb_out="$(_size_eval 390 10 3 "a/b" 400 20 4 3000)"
[ -z "$_sb_out" ] \
    && ok "eval: a focused change produces no findings" \
    || bad "eval: false positive" "unexpected findings: '$_sb_out'"

_sb_out="$(_size_eval 900 6 2 "a/b" 400 20 4 3000)"
case "$_sb_out" in
    *"shotgun surgery"*) bad "eval: shotgun surgery" "fired on a deep change in 2 modules" ;;
    *) ok "eval: a large change inside two modules is over budget but not shotgun surgery" ;;
esac

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

rm -rf "$_sb_tmp"

if [ "${_standalone:-0}" = "1" ]; then
    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ] || exit 1
fi
