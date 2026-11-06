#!/usr/bin/env bash
# tests/integration/opengrep.sh — whole-ruleset OpenGrep fixture gate.
# Sourced by tests/tool-integration after the helper API (it_* functions) is
# defined.
#
# UC-1/UC-2   C# rules: bad fixture ≥1 hit / zero good hits.
# UC-3        absent binary → skip; SLOPGUARD_IT_REQUIRE=1 makes that fatal.
# UC-4        failed scan or invalid JSON → failure, never an empty-success pass.
# UC-5/UC-6   Rust rules: bad fixture ≥1 hit / zero good hits.
# UC-7/UC-8   Ruby rules: bad fixture ≥1 hit / zero good hits.
# UC-9/UC-10  JVM, Go and Node rules: bad fixture ≥1 hit / zero good hits.
# UC-11/UC-12 React and Laravel rules: bad fixture ≥1 hit / zero good hits.
# UC-13/UC-14 whole-ruleset gate: every configured rule, bad then good.
#
# Rule IDs and AP IDs are discovered dynamically from rules/opengrep/*.yaml so
# new rules are automatically exercised without touching this file.
# The fixture tree is copied to a path not named "tests/" because OpenGrep
# ignores directories with that name by default.

_og_rules_dir="${PLUGIN_ROOT}/rules/opengrep"
_og_fix="${_IT_WORK}/og-fixtures"

# _og_discover_rules
# Print "<rule_id> <ap_id>" pairs from every YAML in the rules directory.
# The YAML layout is:
#   rules:
#     - id: slopguard.<lang>.<slug>     ← matched by /^  - id:/
#       ...
#       metadata:
#         ap_id: AP-<LANG>-<CAT>-<N>   ← matched by /ap_id:/
# The id variable is cleared after the first ap_id emission per rule; any rule
# that has no ap_id causes awk to exit 1 so the caller fails rather than
# silently omitting the rule from the test loop.
_og_discover_rules() {
    awk '
        BEGIN { err = 0 }
        /^  - id:[[:space:]]/ {
            if (id != "") {
                print "opengrep.sh: rule " id " missing metadata.ap_id" > "/dev/stderr"
                err = 1
            }
            id = $NF; next
        }
        /[[:space:]]ap_id:[[:space:]]/ {
            if (id != "") { print id " " $NF; id = "" }
        }
        END {
            if (id != "") {
                print "opengrep.sh: rule " id " missing metadata.ap_id" > "/dev/stderr"
                err = 1
            }
            exit err
        }
    ' "${_og_rules_dir}"/*.yaml
}

# _og_uc_pair <rule_id>
# Echo "bad_uc good_uc" for the language-group slice this rule belongs to.
# C# → 1/2, Rust → 5/6, Ruby → 7/8, JVM+Go+Node → 9/10,
# React+Laravel → 11/12; all others appear only in the global gate (13/14).
_og_uc_pair() {
    case "$1" in
        slopguard.cs.*)                                  printf '1 2'   ;;
        slopguard.rs.*)                                  printf '5 6'   ;;
        slopguard.ruby.*)                                printf '7 8'   ;;
        slopguard.jvm.*|slopguard.go.*|slopguard.node.*) printf '9 10'  ;;
        slopguard.react.*|slopguard.php.laravel.*)       printf '11 12' ;;
        *)                                               printf '13 14' ;;
    esac
}

# =========================================================================== #
# OpenGrep whole-ruleset fixture gate
# =========================================================================== #

it_project "opengrep-fixture-gate"
_og_proj="${_IT_CUR_PROJ}"

# UC-3: absent binary → it_skip; SLOPGUARD_IT_REQUIRE=1 makes that fatal (via
# the tool-integration runner, not this file).
if it_skip_unless_tool opengrep; then

    # Copy the fixtures to a temp path not named "tests/" so OpenGrep does not
    # skip it by default.
    rm -rf "${_og_fix}"
    cp -r "${_IT_FIXTURES}" "${_og_fix}"

    # The binary was symlinked into vendor/bin by it_skip_unless_tool.
    _og_bin="$(lock_bin opengrep 2>/dev/null || printf 'opengrep')"
    _og_exe="${_og_proj}/vendor/bin/${_og_bin}"

    # UC-4: a non-0/non-1 exit is a scan failure; zero output or unparseable
    # JSON is also a failure — never treat either as an empty-results success.
    _og_exit=0
    _og_raw="$("${_og_exe}" scan \
        --config "${_og_rules_dir}" \
        --json --quiet \
        "${_og_fix}" 2>/dev/null)" || _og_exit=$?

    # opengrep: exit 0 = no results, exit 1 = results found; anything else is
    # an error (invalid config, internal crash, …).
    if [ "$_og_exit" -ne 0 ] && [ "$_og_exit" -ne 1 ]; then
        it_bad "opengrep: scan (UC-4)" \
            "opengrep exited ${_og_exit} — scan failed"
        return
    fi

    if [ -z "$_og_raw" ] || ! printf '%s' "$_og_raw" | jq empty 2>/dev/null; then
        it_bad "opengrep: json-parse (UC-4)" \
            "scan produced no output or invalid JSON (exit ${_og_exit})"
        return
    fi

    if ! printf '%s' "$_og_raw" | jq -e '.results | arrays' >/dev/null 2>&1; then
        it_bad "opengrep: json-structure (UC-4)" \
            "scan JSON is not an object with a .results array"
        return
    fi

    _og_err_count="$(printf '%s' "$_og_raw" \
        | jq -r '(.errors // []) | length' 2>/dev/null || printf '1')"
    if [ "${_og_err_count:-1}" -gt 0 ]; then
        it_bad "opengrep: scan-errors (UC-4)" \
            "opengrep reported ${_og_err_count} scan error(s) — partial results not accepted"
        return
    fi

    it_ok "opengrep: scan, valid JSON, no errors (UC-4)"

    # ----------------------------------------------------------------------- #
    # Per-rule checks
    # ----------------------------------------------------------------------- #
    # OpenGrep prefixes check_id with the dotted config path
    # (e.g. ".../rules/opengrep/csharp.slopguard.cs.crypto-weak-algorithm").
    # endswith($rule) in jq matches regardless of prefix length or form.
    # No fixture count is hardcoded; every rule in the YAML is exercised.

    # Capture rule list once; this preserves the exit status that process-substitution
    # loses in bash.  Fail here if any rule has no metadata.ap_id or no rules exist.
    _og_rules_list="$(_og_discover_rules)" || {
        it_bad "opengrep: rule-discovery (UC-13)" \
            "one or more rules in ${_og_rules_dir} are missing metadata.ap_id"
        return
    }
    if [ -z "$_og_rules_list" ]; then
        it_bad "opengrep: rule-discovery (UC-13)" \
            "no rules discovered in ${_og_rules_dir}"
        return
    fi

    while IFS=' ' read -r _og_rule _og_ap; do
        [ -n "$_og_rule" ] || continue
        [ -n "$_og_ap"   ] || continue

        # Resolve the UC pair for this rule's language slice and build labels
        # that trace to both the group UC and the global gate (UC-13/UC-14).
        read -r _og_uc_b _og_uc_g <<< "$(_og_uc_pair "$_og_rule")"
        if [ "$_og_uc_b" = "13" ]; then
            _og_lbl_bad="UC-13"
            _og_lbl_good="UC-14"
        else
            _og_lbl_bad="UC-${_og_uc_b}/UC-13"
            _og_lbl_good="UC-${_og_uc_g}/UC-14"
        fi

        # bad-fixture check: rule must produce ≥1 result in its own AP-id fixture.
        # Use test() with a regex so "AP-CS-SEC-003-direct.cs" cannot satisfy the
        # AP-CS-SEC-003 requirement: the ap_id must be followed by a literal dot
        # (start of file extension), not a hyphen continuing the base name.
        _og_bad_count="$(printf '%s' "$_og_raw" \
            | jq -r --arg rule "$_og_rule" --arg ap "$_og_ap" '
                [ .results[]?
                  | select(
                      (.check_id | endswith($rule))
                      and (.path   | test("/bad/" + $ap + "\\.[^/]+$"))
                    )
                ] | length' 2>/dev/null || printf '0')"

        if [ "${_og_bad_count:-0}" -gt 0 ]; then
            it_ok "opengrep[${_og_rule}]: bad-fixture ${_og_ap} (${_og_lbl_bad})"
        else
            it_bad "opengrep[${_og_rule}]: bad-fixture ${_og_ap} (${_og_lbl_bad})" \
                "rule ${_og_rule} had no match in bad/${_og_ap}.*"
        fi

        # good-fixture check: rule must produce zero results under any good/ path.
        _og_good_count="$(printf '%s' "$_og_raw" \
            | jq -r --arg rule "$_og_rule" '
                [ .results[]?
                  | select(
                      (.check_id | endswith($rule))
                      and (.path   | contains("/good/"))
                    )
                ] | length' 2>/dev/null || printf '0')"

        if [ "${_og_good_count:-0}" -eq 0 ]; then
            it_ok "opengrep[${_og_rule}]: no good-fixture hit (${_og_lbl_good})"
        else
            it_bad "opengrep[${_og_rule}]: no good-fixture hit (${_og_lbl_good})" \
                "rule ${_og_rule} fired on ${_og_good_count} good fixture(s)"
        fi

    done <<< "$_og_rules_list"

    # ----------------------------------------------------------------------- #
    # Extra adversarial fixture assertions (GH-65 bypass regression)
    # Each row: "<rule_id> <fixture_basename> <uc_label>"
    # React UC-11, C# UC-1, Go/Node UC-9, Rust UC-5 — one failure per bypass case.
    # ----------------------------------------------------------------------- #
    while IFS=' ' read -r _og_xrule _og_xfix _og_xuc; do
        [ -n "$_og_xrule" ] || continue
        _og_x_count="$(printf '%s' "$_og_raw" \
            | jq -r --arg rule "$_og_xrule" --arg fix "$_og_xfix" '
                [ .results[]?
                  | select(
                      (.check_id | endswith($rule))
                      and (.path   | endswith("/bad/" + $fix))
                    )
                ] | length' 2>/dev/null || printf '0')"
        if [ "${_og_x_count:-0}" -gt 0 ]; then
            it_ok "opengrep[${_og_xrule}]: adversarial bad-fixture ${_og_xfix} (${_og_xuc})"
        else
            it_bad "opengrep[${_og_xrule}]: adversarial bad-fixture ${_og_xfix} (${_og_xuc})" \
                "rule ${_og_xrule} had no match in bad/${_og_xfix}"
        fi
    done <<'_OG_EXTRA_EOF'
slopguard.react.href-js-scheme         AP-TS-SEC-004-call.tsx       UC-11
slopguard.react.href-js-scheme         AP-TS-SEC-004-shadow.tsx     UC-11
slopguard.go.http-client-without-timeout AP-GO-PERF-001-zero.go    UC-9
slopguard.node.prototype-pollution-merge AP-NODE-SEC-001-handler.js UC-9
slopguard.rs.unsafe-block               AP-RS-SEC-001-string.rs    UC-5
slopguard.cs.process-start-user-input   AP-CS-SEC-003-direct.cs    UC-1
slopguard.go.http-client-without-timeout AP-GO-PERF-001-return.go         UC-9
slopguard.node.prototype-pollution-merge AP-NODE-SEC-001-keys.js           UC-9
slopguard.react.href-js-scheme           AP-TS-SEC-004-import-shadow.tsx  UC-11
slopguard.react.href-js-scheme           AP-TS-SEC-004-arrow-shadow.tsx   UC-11
slopguard.cs.xxe-xml                      AP-CS-SEC-007-reenabled.cs       UC-1
slopguard.go.http-client-without-timeout AP-GO-PERF-001-return-zero.go    UC-9
slopguard.go.http-client-without-timeout AP-GO-PERF-001-return-expr.go    UC-9
_OG_EXTRA_EOF

fi
