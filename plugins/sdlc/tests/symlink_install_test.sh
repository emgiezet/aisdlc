#!/usr/bin/env bash
# symlink_install_test.sh — aisdlc invoked through a symlink finds its own plugin root.
#
# The README installs the runner as a link in ~/.local/bin. omp phases resolve
# $PLUGIN_ROOT/commands/<phase>.md, so a root taken from the link's directory fails every
# omp task before it starts.
#
# Standalone:  ./symlink_install_test.sh — defines ok()/bad() and exits 1 on failure.
# Sourced:     test runner must define ok()/bad() before sourcing this file.
set -uo pipefail

_SL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_SL_ROOT="$(cd "${_SL_DIR}/.." && pwd)"

if ! declare -f ok >/dev/null 2>&1; then
    PASS=0; FAIL=0
    ok()  { printf '  ok    %s\n' "$1"; PASS=$((PASS + 1)); }
    bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }
    _SL_STANDALONE=1
fi

_SL_TMP="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-symlink-test.XXXXXX")"
mkdir -p "$_SL_TMP/bin" "$_SL_TMP/other"

# The plugin root the runner computes when started as $1.
# shellcheck source=/dev/null
_sl_root_via() { ( . "$1" >/dev/null 2>&1; printf '%s' "$PLUGIN_ROOT" ); }

ln -s "$_SL_ROOT/bin/aisdlc" "$_SL_TMP/bin/aisdlc"
_got="$(_sl_root_via "$_SL_TMP/bin/aisdlc")"
if [ "$_got" = "$_SL_ROOT" ] && [ -f "$_got/commands/implement.md" ]; then
    ok "symlink install: absolute link resolves PLUGIN_ROOT to the plugin"
else
    bad "symlink install: absolute link resolves PLUGIN_ROOT to the plugin" "got '$_got', want '$_SL_ROOT'"
fi

# A relative link pointing at another link: each hop is relative to its own directory.
ln -s ../bin/aisdlc "$_SL_TMP/other/aisdlc"
_got="$(_sl_root_via "$_SL_TMP/other/aisdlc")"
if [ "$_got" = "$_SL_ROOT" ]; then
    ok "symlink install: relative link chain resolves PLUGIN_ROOT to the plugin"
else
    bad "symlink install: relative link chain resolves PLUGIN_ROOT to the plugin" "got '$_got', want '$_SL_ROOT'"
fi

rm -rf "$_SL_TMP"
unset _SL_DIR _SL_ROOT _SL_TMP _got
unset -f _sl_root_via

if [ "${_SL_STANDALONE:-0}" = "1" ]; then
    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ] || exit 1
fi
