#!/usr/bin/env bash
# tests/session_test.sh — tests for hooks/session-start and rules/policies/always-on.yaml.
#
# Standalone: cd plugins/slop-guard && bash tests/session_test.sh
# The ok()/bad() helpers are defined locally so this file runs independently.
# It intentionally does NOT source run-tests counters (run in isolation per
# the acceptance criteria: "run only this task's tests").

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"

# Isolated data dir so we never collide with a real session.
_TEST_DATA="${TMPDIR:-/tmp}/slop-guard-session-test-$$"
export CLAUDE_PLUGIN_ROOT="${PLUGIN_ROOT}"
export CLAUDE_PLUGIN_DATA="${_TEST_DATA}"

PASS=0; FAIL=0
ok()  { printf '  ok    %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

HOOK="${PLUGIN_ROOT}/hooks/session-start"
POLICY="${PLUGIN_ROOT}/rules/policies/always-on.yaml"
WORK="${TMPDIR:-/tmp}/slop-guard-session-work-$$"
mkdir -p "${WORK}" "${_TEST_DATA}"

_cleanup() { rm -rf "${WORK}" "${_TEST_DATA}"; }
trap '_cleanup' EXIT INT TERM

# Minimal SessionStart JSON payload (all fields Claude Code provides).
SESSION_JSON='{"session_id":"test-sess-001","cwd":"/tmp","hook_event_name":"SessionStart","agent_id":null,"agent_type":null}'

printf 'session-start tests\n\n'

# --------------------------------------------------------------------------- #
# 1. Artefacts exist and are executable
# --------------------------------------------------------------------------- #

[ -f "${HOOK}" ] \
    && ok  "hook script exists: hooks/session-start" \
    || bad "hook script exists" "not found: ${HOOK}"

[ -x "${HOOK}" ] \
    && ok  "hook script is executable" \
    || bad "hook script is executable" "not executable: ${HOOK}"

[ -f "${POLICY}" ] \
    && ok  "policy file exists: rules/policies/always-on.yaml" \
    || bad "policy file exists" "not found: ${POLICY}"

# --------------------------------------------------------------------------- #
# 2. always-on.yaml — content checks
# --------------------------------------------------------------------------- #

for _id in AP-AGENT-001 AP-AGENT-002 AP-AGENT-003 AP-AGENT-004 \
           AP-AGENT-005 AP-AGENT-006 AP-AGENT-007; do
    grep -q "${_id}" "${POLICY}" \
        && ok  "always-on.yaml: contains ${_id}" \
        || bad "always-on.yaml: contains ${_id}" "missing from ${POLICY}"
done

grep -q 'skill_reference' "${POLICY}" \
    && ok  "always-on.yaml: has skill_reference field" \
    || bad "always-on.yaml: has skill_reference field" "missing skill_reference"

grep -q 'digest_max_lines' "${POLICY}" \
    && ok  "always-on.yaml: has digest_max_lines field" \
    || bad "always-on.yaml: has digest_max_lines field" "missing digest_max_lines"

# --------------------------------------------------------------------------- #
# 3. session-start output: empty project
# --------------------------------------------------------------------------- #

_empty="${WORK}/empty"
mkdir -p "${_empty}"

_out="$(printf '%s\n' "${SESSION_JSON}" \
    | CLAUDE_PROJECT_DIR="${_empty}" "${HOOK}" 2>/dev/null)"

printf '%s\n' "${_out}" | grep -q 'stacks detected:' \
    && ok  "empty project: outputs stacks-detected line" \
    || bad "empty project: outputs stacks-detected line" "missing in: ${_out}"

printf '%s\n' "${_out}" | grep -q 'AP-AGENT-001' \
    && ok  "empty project: digest contains AP-AGENT-001" \
    || bad "empty project: digest contains AP-AGENT-001" "missing in: ${_out}"

printf '%s\n' "${_out}" | grep -q 'AP-AGENT-007' \
    && ok  "empty project: digest contains AP-AGENT-007" \
    || bad "empty project: digest contains AP-AGENT-007" "missing in: ${_out}"

printf '%s\n' "${_out}" | grep -q 'agent-discipline' \
    && ok  "empty project: digest references agent-discipline skill" \
    || bad "empty project: digest references agent-discipline skill" "missing in: ${_out}"

# --------------------------------------------------------------------------- #
# 4. Output budget: ≤ 15 AP-AGENT lines, < 1500 chars total (§8.8)
# --------------------------------------------------------------------------- #

_digest_lines="$(printf '%s\n' "${_out}" | grep -c 'AP-AGENT-' 2>/dev/null || printf '0')"
[ "${_digest_lines}" -le 15 ] \
    && ok  "digest line budget: AP-AGENT lines ≤ 15 (got ${_digest_lines})" \
    || bad "digest line budget: AP-AGENT lines ≤ 15" "got ${_digest_lines}"

_chars="${#_out}"
[ "${_chars}" -lt 1500 ] \
    && ok  "output char budget: < 1500 chars (got ${_chars})" \
    || bad "output char budget: < 1500 chars" "got ${_chars}"

# --------------------------------------------------------------------------- #
# 5. Stack detection: Go project
# --------------------------------------------------------------------------- #

_go="${WORK}/go-proj"
mkdir -p "${_go}"
printf 'module example.com/demo\n\ngo 1.23\n' > "${_go}/go.mod"

_out_go="$(printf '%s\n' "${SESSION_JSON}" \
    | CLAUDE_PROJECT_DIR="${_go}" "${HOOK}" 2>/dev/null)"

printf '%s\n' "${_out_go}" | grep -q 'go' \
    && ok  "stack detection: go.mod → detects go" \
    || bad "stack detection: go.mod → detects go" "${_out_go}"

# --------------------------------------------------------------------------- #
# 6. Stack detection: Laravel project (composer.json + artisan)
# --------------------------------------------------------------------------- #

_laravel="${WORK}/laravel-proj"
mkdir -p "${_laravel}"
printf '{"require":{"laravel/framework":"^11.0"}}' > "${_laravel}/composer.json"
touch "${_laravel}/artisan"

_out_laravel="$(printf '%s\n' "${SESSION_JSON}" \
    | CLAUDE_PROJECT_DIR="${_laravel}" "${HOOK}" 2>/dev/null)"

printf '%s\n' "${_out_laravel}" | grep -q 'php' \
    && ok  "stack detection: composer.json → detects php" \
    || bad "stack detection: composer.json → detects php" "${_out_laravel}"

printf '%s\n' "${_out_laravel}" | grep -q 'laravel' \
    && ok  "stack detection: artisan + laravel/framework → detects laravel" \
    || bad "stack detection: artisan + laravel/framework → detects laravel" "${_out_laravel}"

# --------------------------------------------------------------------------- #
# 7. Stack detection: Python + project-config config wins (§Z1 negative case)
# --------------------------------------------------------------------------- #

_py="${WORK}/py-proj"
mkdir -p "${_py}"
printf '[tool.ruff]\nline-length = 100\n' > "${_py}/pyproject.toml"

_out_py="$(printf '%s\n' "${SESSION_JSON}" \
    | CLAUDE_PROJECT_DIR="${_py}" "${HOOK}" 2>/dev/null)"

printf '%s\n' "${_out_py}" | grep -q 'python' \
    && ok  "stack detection: pyproject.toml → detects python" \
    || bad "stack detection: pyproject.toml → detects python" "${_out_py}"

# --------------------------------------------------------------------------- #
# 8. Stack detection: Node + TypeScript
# --------------------------------------------------------------------------- #

_ts="${WORK}/ts-proj"
mkdir -p "${_ts}"
printf '{"dependencies":{"typescript":"^5.0"},"devDependencies":{"react":"^18"}}' \
    > "${_ts}/package.json"
touch "${_ts}/tsconfig.json"

_out_ts="$(printf '%s\n' "${SESSION_JSON}" \
    | CLAUDE_PROJECT_DIR="${_ts}" "${HOOK}" 2>/dev/null)"

printf '%s\n' "${_out_ts}" | grep -q 'node' \
    && ok  "stack detection: package.json → detects node" \
    || bad "stack detection: package.json → detects node" "${_out_ts}"

printf '%s\n' "${_out_ts}" | grep -q 'typescript' \
    && ok  "stack detection: tsconfig.json → detects typescript" \
    || bad "stack detection: tsconfig.json → detects typescript" "${_out_ts}"

printf '%s\n' "${_out_ts}" | grep -q 'react' \
    && ok  "stack detection: react in package.json → detects react" \
    || bad "stack detection: react in package.json → detects react" "${_out_ts}"

# --------------------------------------------------------------------------- #
# 9. Session state: profile.json written with stacks
# --------------------------------------------------------------------------- #

_sess_dir="${_TEST_DATA}/sessions/test-sess-001"
[ -f "${_sess_dir}/profile.json" ] \
    && ok  "session state: profile.json created" \
    || bad "session state: profile.json created" "missing: ${_sess_dir}/profile.json"

if [ -f "${_sess_dir}/profile.json" ]; then
    _stacks_val="$(jq -r '.stacks | type' "${_sess_dir}/profile.json" 2>/dev/null || printf 'ERROR')"
    [ "${_stacks_val}" = "array" ] \
        && ok  "session state: profile.json .stacks is an array" \
        || bad "session state: profile.json .stacks is an array" "got type: ${_stacks_val}"
fi

[ -f "${_sess_dir}/findings.json" ] \
    && ok  "session state: findings.json created" \
    || bad "session state: findings.json created" "missing: ${_sess_dir}/findings.json"

# --------------------------------------------------------------------------- #
# 10. plugin-validate passes
# --------------------------------------------------------------------------- #

if command -v claude >/dev/null 2>&1; then
    _val_out="$(claude plugin validate "${PLUGIN_ROOT}" --strict 2>&1)"
    _val_exit=$?
    [ "${_val_exit}" -eq 0 ] \
        && ok  "claude plugin validate --strict: passes" \
        || bad "claude plugin validate --strict: passes" "${_val_out}"
else
    printf '  skip  claude plugin validate: claude CLI not available\n'
fi

# --------------------------------------------------------------------------- #

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
