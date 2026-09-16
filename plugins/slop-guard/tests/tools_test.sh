#!/usr/bin/env bash
# tools_test.sh — installer and resolver tests.
#
# Sourced by tests/run-tests; ok() and bad() are pre-defined there.
# Needs no network: assets are served from file:// URLs.
# Asserts on the filesystem, not on log text.

# --------------------------------------------------------------------------- #
# Setup: fake asset and lockfile
# --------------------------------------------------------------------------- #

TEST_WORK="${TMPDIR:-/tmp}/slop-guard-tools-test-$$"
mkdir -p "$TEST_WORK"

# Source the library with CLAUDE_PLUGIN_ROOT pointing at the real plugin root.
# TOOLS_LOCK can be overridden per-test inside subshells.
# shellcheck source=../lib/tools.sh
. "${PLUGIN_ROOT}/lib/tools.sh"

# Build a fake tar.gz asset: fake-tool-9.9.9/fake-tool (one directory level
# so --strip-components=1 lands the binary directly in the version dir).
FAKE_TARDIR="${TEST_WORK}/tardir/fake-tool-9.9.9"
mkdir -p "$FAKE_TARDIR"
printf '#!/bin/sh\nprintf "fake-tool 9.9.9\\n"\n' > "${FAKE_TARDIR}/fake-tool"
chmod +x "${FAKE_TARDIR}/fake-tool"
FAKE_TAR="${TEST_WORK}/fake-tool-9.9.9-linux-amd64.tar.gz"
tar -czf "$FAKE_TAR" -C "${TEST_WORK}/tardir" "fake-tool-9.9.9"

GOOD_HASH="$(_sha256 "$FAKE_TAR")"
BAD_HASH="0000000000000000000000000000000000000000000000000000000000000000"

# Fake lockfile — platform keys cover linux-amd64 so tests run on this machine.
FAKE_LOCK="${TEST_WORK}/tools.lock.json"
jq -n \
    --arg url "file://${FAKE_TAR}" \
    --arg good "$GOOD_HASH" \
    '{
        schema: 1,
        tools: {
            "fake-tool": {
                version: "9.9.9",
                assets: {
                    "linux-amd64":  { url: $url, sha256: $good },
                    "linux-arm64":  { url: $url, sha256: $good },
                    "darwin-arm64": { url: $url, sha256: $good }
                },
                bin: "fake-tool"
            }
        }
    }' > "$FAKE_LOCK"

BAD_LOCK="${TEST_WORK}/bad.lock.json"
jq -n \
    --arg url "file://${FAKE_TAR}" \
    --arg bad "$BAD_HASH" \
    '{
        schema: 1,
        tools: {
            "fake-tool": {
                version: "9.9.9",
                assets: {
                    "linux-amd64":  { url: $url, sha256: $bad },
                    "linux-arm64":  { url: $url, sha256: $bad },
                    "darwin-arm64": { url: $url, sha256: $bad }
                },
                bin: "fake-tool"
            }
        }
    }' > "$BAD_LOCK"

# --------------------------------------------------------------------------- #
printf 'installer: good hash installs and points current at the version dir\n'
# --------------------------------------------------------------------------- #

FAKE_DATA_GOOD="${TEST_WORK}/plugin-data-good"
(
    TOOLS_LOCK="$FAKE_LOCK"
    CLAUDE_PLUGIN_DATA="$FAKE_DATA_GOOD"
    install_tool "fake-tool" >/dev/null 2>&1
); rc_good=$?

[ "$rc_good" -eq 0 ] && ok "exits zero on good hash" || bad "exit code (good hash)" "expected 0, got $rc_good"

version_dir_good="${FAKE_DATA_GOOD}/tools/fake-tool/9.9.9"
current_link_good="${FAKE_DATA_GOOD}/tools/fake-tool/current"

[ -d "$version_dir_good" ] && ok "version dir created" || bad "version dir" "missing: $version_dir_good"
[ -L "$current_link_good" ] && ok "current is a symlink" || bad "current symlink" "not a symlink: $current_link_good"
[ -x "${version_dir_good}/fake-tool" ] && ok "binary is executable" || bad "binary" "not executable in $version_dir_good"
[ "$(readlink "$current_link_good")" = "$version_dir_good" ] \
    && ok "current points at version dir" \
    || bad "current target" "$(readlink "$current_link_good" 2>/dev/null) != $version_dir_good"

# --------------------------------------------------------------------------- #
printf '\ninstaller: bad hash leaves no version dir, removes download, exits non-zero\n'
# --------------------------------------------------------------------------- #

FAKE_DATA_BAD="${TEST_WORK}/plugin-data-bad"
(
    TOOLS_LOCK="$BAD_LOCK"
    CLAUDE_PLUGIN_DATA="$FAKE_DATA_BAD"
    install_tool "fake-tool" >/dev/null 2>&1
); rc_bad=$?

[ "$rc_bad" -ne 0 ] && ok "exits non-zero on bad hash" || bad "exit code (bad hash)" "expected non-zero, got $rc_bad"

version_dir_bad="${FAKE_DATA_BAD}/tools/fake-tool/9.9.9"
[ ! -d "$version_dir_bad" ] && ok "no version dir on hash mismatch" || bad "version dir" "exists but should not: $version_dir_bad"

# No leftover downloads: the only temp files created by install_tool are under
# mktemp -d, which install_tool itself removes before returning.
leftover_count="$(find "${FAKE_DATA_BAD}" -name "asset" 2>/dev/null | wc -l)"
[ "$leftover_count" -eq 0 ] && ok "no leftover download" || bad "leftover download" "${leftover_count} file(s) found"

# --------------------------------------------------------------------------- #
printf '\nresolver: project binary wins over plugin-installed binary\n'
# --------------------------------------------------------------------------- #

# Pre-build a plugin-installed tree so the resolver actually has a plugin binary
# to skip over.
FAKE_DATA_PREC="${TEST_WORK}/plugin-data-prec"
mkdir -p "${FAKE_DATA_PREC}/tools/fake-tool/9.9.9"
printf '#!/bin/sh\nprintf "plugin-fake-tool 9.9.9\\n"\n' \
    > "${FAKE_DATA_PREC}/tools/fake-tool/9.9.9/fake-tool"
chmod +x "${FAKE_DATA_PREC}/tools/fake-tool/9.9.9/fake-tool"
ln -s "${FAKE_DATA_PREC}/tools/fake-tool/9.9.9" "${FAKE_DATA_PREC}/tools/fake-tool/current"

# A fake project-local binary.
PROJECT_DIR="${TEST_WORK}/project"
mkdir -p "${PROJECT_DIR}/vendor/bin"
printf '#!/bin/sh\nprintf "project-fake-tool 9.9.9\\n"\n' \
    > "${PROJECT_DIR}/vendor/bin/fake-tool"
chmod +x "${PROJECT_DIR}/vendor/bin/fake-tool"

# resolve_tool in a subshell: env changes stay local.
resolved=$(
    TOOLS_LOCK="$FAKE_LOCK"
    CLAUDE_PLUGIN_DATA="$FAKE_DATA_PREC"
    CLAUDE_PROJECT_DIR="$PROJECT_DIR"
    resolve_tool "fake-tool"
)
expected_resolved="${PROJECT_DIR}/vendor/bin/fake-tool"
[ "$resolved" = "$expected_resolved" ] \
    && ok "project binary wins over plugin binary" \
    || bad "resolver precedence" "got '${resolved}', want '${expected_resolved}'"

# --------------------------------------------------------------------------- #
# Cleanup
# --------------------------------------------------------------------------- #

rm -rf "$TEST_WORK"
