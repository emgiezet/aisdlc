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
    # GH-65-c UC-7/UC-8: retain C#/Rust checks and enforce the Ruby fixtures.
    while read -r _og_id _og_ap; do
        if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" --arg ap "$_og_ap" '
            any(.results[]; .check_id == $id and
                (.path | endswith("/ruby/bad/" + $ap + ".rb")))
            ' "$_og_fixture_json" >/dev/null; then
            it_ok "GH-65-c UC-7: ${_og_id} detects its bad fixture"
        else
            it_bad "GH-65-c UC-7: ${_og_id} detects its bad fixture" 'missing own-rule result or failed scan'
        fi
        if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" '
            all(.results[]; .check_id != $id or (.path | contains("/good/") | not))
            ' "$_og_fixture_json" >/dev/null; then
            it_ok "GH-65-c UC-8: ${_og_id} is silent across all good fixtures"
        else
            it_bad "GH-65-c UC-8: ${_og_id} is silent across all good fixtures" 'good-fixture finding or failed scan'
        fi
    done <<'RUBY_CONTRACTS'
slopguard.ruby.send-user-input AP-RB-SEC-001
slopguard.ruby.mass-assignment-without-permit AP-RB-SEC-005
slopguard.ruby.sql-string-interpolation AP-RB-SEC-006
slopguard.ruby.insecure-random AP-RB-SEC-007
RUBY_CONTRACTS
    # GH-65-d UC-9/UC-10: preserve earlier slices and enforce JVM/Go/Node.
    while read -r _og_id _og_fixture; do
        if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" --arg fixture "$_og_fixture" '
            any(.results[]; .check_id == $id and
                (.path | endswith("/" + $fixture)))
            ' "$_og_fixture_json" >/dev/null; then
            it_ok "GH-65-d UC-9: ${_og_id} detects its bad fixture"
        else
            it_bad "GH-65-d UC-9: ${_og_id} detects its bad fixture" 'missing own-rule result or failed scan'
        fi
        if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" '
            all(.results[]; .check_id != $id or (.path | contains("/good/") | not))
            ' "$_og_fixture_json" >/dev/null; then
            it_ok "GH-65-d UC-10: ${_og_id} is silent across all good fixtures"
        else
            it_bad "GH-65-d UC-10: ${_og_id} is silent across all good fixtures" 'good-fixture finding or failed scan'
        fi
    done <<'RUNTIME_CONTRACTS'
slopguard.jvm.jackson-default-typing java/bad/AP-JVM-SEC-005.java
slopguard.jvm.xml-external-entity java/bad/AP-JVM-SEC-007.java
slopguard.go.http-client-without-timeout go/bad/AP-GO-PERF-001.go
slopguard.node.prototype-pollution-merge node/bad/AP-NODE-SEC-001.js
RUNTIME_CONTRACTS
    # GH-65-e UC-11/UC-12: enforce the named React and Laravel repairs.
    while read -r _og_id _og_ap; do
        if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" --arg ap "$_og_ap" '
            any(.results[]; .check_id == $id and
                (.path | test("/bad/" + $ap + "\\.[^/]+$")))
            ' "$_og_fixture_json" >/dev/null; then
            it_ok "GH-65-e UC-11: ${_og_id} detects its bad fixture"
        else
            it_bad "GH-65-e UC-11: ${_og_id} detects its bad fixture" 'missing own-rule result or failed scan'
        fi
        if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" '
            all(.results[]; .check_id != $id or (.path | contains("/good/") | not))
            ' "$_og_fixture_json" >/dev/null; then
            it_ok "GH-65-e UC-12: ${_og_id} is silent across all good fixtures"
        else
            it_bad "GH-65-e UC-12: ${_og_id} is silent across all good fixtures" 'good-fixture finding or failed scan'
        fi
    done <<'REACT_LARAVEL_CONTRACTS'
slopguard.react.href-js-scheme AP-TS-SEC-004
slopguard.php.laravel.mass-assignment-request-all AP-PHP-SEC-005
slopguard.php.laravel.unbounded-all AP-PHP-PERF-002
REACT_LARAVEL_CONTRACTS

    # UC-13/UC-14 discover every rule, accepting indentation and trailing comments.
    # Reject missing AP metadata instead of silently dropping an untested rule.
    if ! _og_rules="$(awk '
        /^[[:space:]]*-[[:space:]]+id:[[:space:]]/ {
            if (id != "") { print "missing metadata.ap_id for " id > "/dev/stderr"; failed = 1 }
            id = $3; gsub(/["\047]/, "", id)
            if (id !~ /^slopguard[.]/) failed = 1
            next
        }
        /^[[:space:]]+ap_id:[[:space:]]/ {
            if (id != "") {
                ap = $2; gsub(/["\047]/, "", ap)
                if (ap !~ /^AP-([A-Z]+-)+[0-9]+$/) failed = 1
                print id, ap; id = ""
            }
        }
        END { if (id != "") failed = 1; exit failed }
        ' "${PLUGIN_ROOT}"/rules/opengrep/*.yaml)" || [ -z "$_og_rules" ]; then
        it_bad 'GH-65-e UC-13: discover every rule and AP binding' 'invalid or empty rule metadata'
    else
        while read -r _og_id _og_ap; do
            if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" --arg ap "$_og_ap" '
                any(.results[]; .check_id == $id and
                    (.path | test("/bad/" + $ap + "\\.[^/]+$")))
                ' "$_og_fixture_json" >/dev/null; then
                it_ok "GH-65-e UC-13: ${_og_id} detects its own ${_og_ap} fixture"
            else
                it_bad "GH-65-e UC-13: ${_og_id} detects its own ${_og_ap} fixture" 'missing own-rule result or failed scan'
            fi
            if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" '
                all(.results[]; .check_id != $id or (.path | contains("/good/") | not))
                ' "$_og_fixture_json" >/dev/null; then
                it_ok "GH-65-e UC-14: ${_og_id} is silent across all good fixtures"
            else
                it_bad "GH-65-e UC-14: ${_og_id} is silent across all good fixtures" 'good-fixture finding or invalid results'
            fi
            # Each adversarial variant must independently match its AP-bound rule.
            for _og_variant in "${_IT_CUR_PROJ}"/samples/*/bad/"${_og_ap}"-*.*; do
                [ -f "$_og_variant" ] || continue
                if [ "$_og_fixture_scan_ok" = 1 ] && jq -e --arg id "$_og_id" --arg path "$_og_variant" '
                    any(.results[]; .check_id == $id and .path == $path)
                    ' "$_og_fixture_json" >/dev/null; then
                    it_ok "GH-65-e UC-13: ${_og_id} detects variant ${_og_variant##*/}"
                else
                    it_bad "GH-65-e UC-13: ${_og_id} detects variant ${_og_variant##*/}" 'missing variant result or failed scan'
                fi
            done
        done <<< "$_og_rules"
    fi
fi
