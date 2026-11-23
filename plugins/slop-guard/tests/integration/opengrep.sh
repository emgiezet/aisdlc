#!/usr/bin/env bash
# GH-65-a UC-1..4: real pinned OpenGrep, copied fixtures, per-rule contracts.
# Sourced by tool-integration; later language slices extend these assertions.
it_project opengrep-fixture-contract
_og_fixture_scan_ok=0
_og_fixture_json="${_IT_CUR_PROJ}/scan.json"
# UC-3: the shared helper records one skip; REQUIRE=1 rejects it in the runner.
if it_skip_unless_tool opengrep; then
    cp -R "${_IT_FIXTURES}" "${_IT_CUR_PROJ}/samples"
    _og_fixture_bin="${_IT_CUR_PROJ}/vendor/bin/$(lock_bin opengrep)"
    # UC-4: reject failed scans, invalid JSON, missing results and scan errors.
    if "$_og_fixture_bin" scan --json --no-rewrite-rule-ids \
        --config "${PLUGIN_ROOT}/rules/opengrep" "${_IT_CUR_PROJ}/samples" \
        > "$_og_fixture_json" 2> "${_IT_CUR_PROJ}/scan.stderr" &&
        jq -e 'type == "object" and (.results | type == "array") and
            (.errors | type == "array" and length == 0)' "$_og_fixture_json" >/dev/null; then
        _og_fixture_scan_ok=1
        it_ok 'GH-65-a UC-4: OpenGrep scan succeeds with valid error-free JSON'
    else
        it_bad 'GH-65-a UC-4: OpenGrep scan succeeds with valid error-free JSON' \
            "scan failed or malformed output; see ${_IT_CUR_PROJ}/scan.stderr"
    fi
    while read -r _og_id _og_ap; do
        if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" --arg ap "$_og_ap" '
            any(.results[]; .check_id == $id and
                (.path | endswith("/csharp/bad/" + $ap + ".cs")))
            ' "$_og_fixture_json" >/dev/null; then
            it_ok "GH-65-a UC-1: ${_og_id} detects its bad fixture"
        else
            it_bad "GH-65-a UC-1: ${_og_id} detects its bad fixture" 'missing own-rule result or failed scan'
        fi
        if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" '
            all(.results[]; .check_id != $id or (.path | contains("/good/") | not))
            ' "$_og_fixture_json" >/dev/null; then
            it_ok "GH-65-a UC-2: ${_og_id} is silent across all good fixtures"
        else
            it_bad "GH-65-a UC-2: ${_og_id} is silent across all good fixtures" 'good-fixture finding or failed scan'
        fi
    done <<'CONTRACTS'
slopguard.cs.process-start-user-input AP-CS-SEC-003
slopguard.cs.path-traversal AP-CS-SEC-004
slopguard.cs.crypto-weak-algorithm AP-CS-SEC-005
slopguard.cs.insecure-random AP-CS-SEC-006
slopguard.cs.xxe-xml AP-CS-SEC-007
slopguard.cs.ldap-injection AP-CS-SEC-008
CONTRACTS
    # GH-65-b UC-5/UC-6: preserve the C# contracts and enforce each Rust ID.
    while read -r _og_id _og_ap; do
        if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" --arg ap "$_og_ap" '
            any(.results[]; .check_id == $id and
                (.path | endswith("/rust/bad/" + $ap + ".rs")))
            ' "$_og_fixture_json" >/dev/null; then
            it_ok "GH-65-b UC-5: ${_og_id} detects its bad fixture"
        else
            it_bad "GH-65-b UC-5: ${_og_id} detects its bad fixture" 'missing own-rule result or failed scan'
        fi
        if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" '
            all(.results[]; .check_id != $id or (.path | contains("/good/") | not))
            ' "$_og_fixture_json" >/dev/null; then
            it_ok "GH-65-b UC-6: ${_og_id} is silent across all good fixtures"
        else
            it_bad "GH-65-b UC-6: ${_og_id} is silent across all good fixtures" 'good-fixture finding or failed scan'
        fi
    done <<'RUST_CONTRACTS'
slopguard.rs.unsafe-block AP-RS-SEC-001
slopguard.rs.raw-pointer-deref AP-RS-SEC-005
slopguard.rs.mem-transmute AP-RS-SEC-006
slopguard.rs.from-utf8-unchecked AP-RS-SEC-007
slopguard.rs.command-injection AP-RS-SEC-008
RUST_CONTRACTS
    if [ "$_og_fixture_scan_ok" = 1 ] && jq -e '
        any(.results[]; .check_id == "slopguard.rs.unsafe-block" and
            (.path | endswith("/rust/bad/AP-RS-SEC-001-string.rs")))
        ' "$_og_fixture_json" >/dev/null; then
        it_ok 'GH-65-b UC-5: SAFETY string does not suppress unsafe-block detection'
    else
        it_bad 'GH-65-b UC-5: SAFETY string does not suppress unsafe-block detection' 'missing unsafe-block result or failed scan'
    fi
fi
