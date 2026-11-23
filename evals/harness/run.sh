#!/usr/bin/env bash
# run.sh — harness eval: does the AI SDLC pipeline deliver on a cheap model?
#
# For each scenario × model: instantiate a fresh sandbox in the temp dir, queue the scenario's
# approved spec, run it through aisdlc, then score the produced branch against the scenario's
# assertions. Prints a scenario × model table with cost and duration.
#
#   ./run.sh --model haiku
#   ./run.sh --model sonnet --scenario go-endpoint
#   ./run.sh --model haiku,sonnet --keep
#
# This measures the harness, not the model. A scenario failing on haiku is a defect in a
# playbook, a rule, or the spec — fix the instructions, not the model tier.
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "${HARNESS_DIR}/../.." && pwd)"
FIXTURE="${REPO_ROOT}/evals/fixtures/sandbox"
AISDLC="${REPO_ROOT}/plugins/sdlc/bin/aisdlc"
WORK_ROOT="${TMPDIR:-/tmp}/aisdlc-eval"
LEDGER="${HARNESS_DIR}/results.jsonl"
EVAL_VERSION="$(jq -r '.version // "unknown"' "${REPO_ROOT}/plugins/sdlc/.claude-plugin/plugin.json" 2>/dev/null || printf 'unknown')"

MODELS="sonnet"
SCENARIOS=""
BUDGET="${AISDLC_BUDGET:-5}"
KEEP=0

die() { printf 'run.sh: %s\n' "$1" >&2; exit 1; }

# --------------------------------------------------------------------------- #

# The instruction surface under test: everything the agent reads that we tune. Paths are relative
# to their root so the digest is identical in any checkout.
HARNESS_PATHS="plugins/sdlc/commands plugins/sdlc/skills plugins/sdlc/agents plugins/sdlc/prompts plugins/sdlc/templates evals/fixtures/sandbox/.claude evals/fixtures/sandbox/CLAUDE.md"

harness_fingerprint() {
    local root="${1:-$REPO_ROOT}" p
    for p in $HARNESS_PATHS; do
        [ -e "$root/$p" ] || die "harness surface missing: $p — an absent path would digest to a value that looks comparable with runs that had it"
    done
    # shellcheck disable=SC2086
    (cd "$root" && find $HARNESS_PATHS -type f -print0 | sort -z | xargs -0 sha256sum) \
        | sha256sum | cut -c1-16
}

# What this scenario asked and what it supplied. A corrected scenario is not the old one, so its
# results must never be compared as equals.
inputs_fingerprint() {
    (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum) | sha256sum | cut -c1-16
}

# One cell, written once to the run log and once to the durable ledger.
record_cell() {
    local scenario="$1" model="$2" inputs="$3" status="$4" verdict="$5" \
          gradeable="$6" passed="$7" failed="$8" cost="$9" secs="${10}" runtime="${11}"
    local line
    line="$(jq -nc \
        --arg ts "$(date -u +%FT%TZ)" --arg version "$EVAL_VERSION" \
        --arg harness "$HARNESS_FP" --arg inputs "$inputs" \
        --arg scenario "$scenario" --arg model "$model" --arg runtime "$runtime" \
        --arg status "$status" --arg verdict "$verdict" --arg cost "$cost" \
        --argjson gradeable "$gradeable" --argjson secs "$secs" \
        --arg passed "$passed" --arg failed "$failed" \
        '{ts:$ts, aisdlc_version:$version, harness:$harness, inputs:$inputs,
          scenario:$scenario, model:$model, runtime:$runtime, status:$status,
          verdict:$verdict, gradeable:$gradeable,
          assertions_passed:(if $gradeable then ($passed|tonumber) else null end),
          assertions_failed:(if $gradeable then ($failed|tonumber) else null end),
          cost_usd:($cost|tonumber), seconds:$secs}')"
    printf '%s\n' "$line" >> "$RUN_LOG"
    printf '%s\n' "$line" >> "$LEDGER"
}

# The last result for this scenario on a different harness: the only honest comparison. Reads
# $BASELINE, the ledger as it stood before this run, so a cell is never compared with itself.
baseline_delta() {
    local scenario="$1" model="$2" inputs="$3" harness="$4" verdict="$5" gradeable="$6" prior
    [ "$gradeable" = true ] || { printf '—'; return 0; }
    # "" = nothing recorded on these inputs; "=" = only reruns of this harness; else the verdict.
    prior="$(jq -rs --arg s "$scenario" --arg m "$model" --arg i "$inputs" --arg h "$harness" \
        '[.[] | select(.scenario==$s and .model==$m and .inputs==$i and .gradeable == true)]
         | if length == 0 then ""
           else (map(select(.harness != $h)) | if length == 0 then "=" else last.verdict end)
           end' "$BASELINE" 2>/dev/null)"
    if [ -z "$prior" ]; then
        printf 'new'
    elif [ "$prior" = "=" ]; then
        printf 'same harness'
    elif [ "$prior" = "$verdict" ]; then
        printf '%s→%s' "$prior" "$verdict"
    else
        printf '%s→%s %s' "$prior" "$verdict" \
            "$([ "$verdict" = PASS ] && printf 'improved' || printf 'REGRESSED')"
    fi
}

# Every requested cell must have produced exactly one record. A missing one is a cell that
# silently never ran; a duplicate means two iterations wrote the same key and one is a phantom.
assert_run_identity() {
    local expected=0 actual dupes _m _s
    for _m in $MODELS; do for _s in $SCENARIOS; do expected=$((expected + 1)); done; done
    actual="$(wc -l < "$RUN_LOG" | tr -d ' ')"
    dupes="$(jq -r '"\(.scenario)\t\(.model)"' "$RUN_LOG" | sort | uniq -d)"
    [ "$actual" -eq "$expected" ] && [ -z "$dupes" ] && return 0

    printf '\nledger identity failed: %s cell(s) recorded, %s requested\n' "$actual" "$expected"
    for _m in $MODELS; do
        for _s in $SCENARIOS; do
            jq -e --arg s "$_s" --arg m "$_m" \
                'select(.scenario == $s and .model == $m)' "$RUN_LOG" >/dev/null 2>&1 \
                || printf '  missing cell: %s × %s\n' "$_s" "$_m"
        done
    done
    if [ -n "$dupes" ]; then
        printf '%s\n' "$dupes" | while IFS=$'\t' read -r _s _m; do
            printf '  duplicate cell: %s × %s — one record overwrote another\n' "$_s" "$_m"
        done
    fi
    return 1
}

# A fresh sandbox per run: an eval that inherits the previous run's state proves nothing.
make_sandbox() {
    local dest="$1"
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    cp -R "$FIXTURE" "$dest"
    git -C "$dest" init -q -b master
    git -C "$dest" config user.email eval@localhost
    git -C "$dest" config user.name "aisdlc eval"
    git -C "$dest" add -A
    git -C "$dest" commit -q -m "chore: sandbox baseline"
    # aisdlc branches off origin/master; give it one without a remote.
    git -C "$dest" update-ref refs/remotes/origin/master HEAD
}

# Assertion helpers. Each prints "ok <label>" or "FAIL <label>: <detail>" and returns 0/1.
declare -i A_PASS=0 A_FAIL=0
assert_ok()   { printf '      ok    %s\n' "$1"; A_PASS+=1; }
assert_fail() { printf '      FAIL  %s: %s\n' "$1" "$2"; A_FAIL+=1; }

score() {
    local sandbox="$1" scenario_json="$2" ticket="$3" base="$4"
    A_PASS=0; A_FAIL=0

    local diff names
    diff="$(git -C "$sandbox" diff "$base"...HEAD 2>/dev/null)"
    names="$(git -C "$sandbox" diff --name-only "$base"...HEAD 2>/dev/null)"

    # commands: must all exit 0 inside the sandbox
    while IFS= read -r cmd; do
        [ -n "$cmd" ] || continue
        local out rc=0
        out="$(cd "$sandbox" && eval "$cmd" 2>&1)" || rc=$?
        if [ "$rc" -eq 0 ]; then
            assert_ok "cmd: ${cmd:0:52}"
        else
            assert_fail "cmd: ${cmd:0:52}" "exit $rc — $(printf '%s' "$out" | tail -2 | tr '\n' ' ' | cut -c1-140)"
        fi
    done < <(jq -r '.assert.commands // [] | .[]' "$scenario_json")

    # uc_ids: every use case id appears in a test file under test_paths
    local test_paths
    test_paths="$(jq -r '.assert.test_paths // [] | join(" ")' "$scenario_json")"
    if [ -n "$test_paths" ]; then
        local found
        found="$(cd "$sandbox" && grep -rhoE 'UC-?[0-9]+' $test_paths 2>/dev/null \
                 | tr -d '-' | sort -u | tr '\n' ' ')"
        while IFS= read -r uc; do
            [ -n "$uc" ] || continue
            local norm="${uc//-/}"
            if printf ' %s ' "$found" | grep -q " $norm "; then
                assert_ok "traceability: $uc has a test"
            else
                assert_fail "traceability: $uc" "no test name carries this id"
            fi
        done < <(jq -r '.assert.uc_ids // [] | .[]' "$scenario_json")
    fi

    # diff_contains / diff_absent
    while IFS= read -r re; do
        [ -n "$re" ] || continue
        if printf '%s' "$diff" | grep -qE "$re"; then
            assert_ok "diff contains /$re/"
        else
            assert_fail "diff contains /$re/" "not found in the change"
        fi
    done < <(jq -r '.assert.diff_contains // [] | .[]' "$scenario_json")

    while IFS= read -r re; do
        [ -n "$re" ] || continue
        if printf '%s' "$diff" | grep -qE "$re"; then
            assert_fail "diff must not contain /$re/" "found in the change"
        else
            assert_ok "diff avoids /$re/"
        fi
    done < <(jq -r '.assert.diff_absent // [] | .[]' "$scenario_json")

    # files_changed
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        if printf '%s\n' "$names" | grep -qxF "$f"; then
            assert_ok "changed: $f"
        else
            assert_fail "changed: $f" "untouched — contract and code must move together"
        fi
    done < <(jq -r '.assert.files_changed // [] | .[]' "$scenario_json")

    # min_test_funcs: the suite must not shrink. Counted within test_paths only — a second
    # stack's tests must not mask a deletion in the one under test.
    local min_funcs
    min_funcs="$(jq -r '.assert.min_test_funcs // empty' "$scenario_json")"
    if [ -n "$min_funcs" ] && [ -n "$test_paths" ]; then
        local n
        n="$(cd "$sandbox" && { grep -rhoE '^func Test[A-Za-z0-9_]+' --include='*_test.go' $test_paths 2>/dev/null;
                                grep -rhoE "^test\(" --include='*.test.mjs' $test_paths 2>/dev/null; } | wc -l)"
        if [ "${n:-0}" -ge "$min_funcs" ]; then
            assert_ok "test count $n >= $min_funcs in $test_paths"
        else
            assert_fail "test count" "$n test functions in $test_paths, expected at least $min_funcs — a test was removed"
        fi
    fi

    # no_skips
    if [ "$(jq -r '.assert.no_skips // false' "$scenario_json")" = "true" ]; then
        local skips
        skips="$(printf '%s' "$diff" | grep -E '^\+' | grep -v '^+++' \
                 | grep -cE '(t\.Skip|\.skip\(|it\.only|test\.only|\.only\(|markTestSkipped|@pytest\.mark\.skip)' || true)"
        if [ "${skips:-0}" -eq 0 ]; then
            assert_ok "no tests skipped or focused"
        else
            assert_fail "no_skips" "$skips skip/only marker(s) added"
        fi
    fi

    # qa_verdict. Accept the report from the branch or from the task directory: the runner copies
    # it out before releasing the worktree, so an uncommitted report is still evidence the phase
    # ran. Whether it was committed is a separate assertion — conflating the two makes a missing
    # commit look like a QA phase that produced nothing.
    local want_verdict
    want_verdict="$(jq -r '.assert.qa_verdict // empty' "$scenario_json")"
    if [ -n "$want_verdict" ]; then
        local report="" committed="no" candidate
        for candidate in "$sandbox/specs/$ticket/qa-report.md" \
                         "$sandbox"/.aisdlc/tasks/*/qa-report.md; do
            [ -f "$candidate" ] || continue
            report="$candidate"; break
        done
        git -C "$sandbox" ls-tree -r --name-only HEAD 2>/dev/null \
            | grep -qx "specs/$ticket/qa-report.md" && committed="yes"

        if [ -z "$report" ]; then
            assert_fail "qa verdict" "no qa-report.md anywhere — the QA phase produced nothing"
        elif ! grep -qi "Verdict:[^A-Za-z]*$want_verdict" "$report"; then
            assert_fail "qa verdict" "expected $want_verdict, report says: $(grep -io 'verdict.*' "$report" | head -1)"
        elif [ "$committed" = "no" ]; then
            assert_fail "qa report committed" "verdict is $want_verdict but the report was never committed — it would vanish with the worktree"
        else
            assert_ok "qa verdict: $want_verdict (committed)"
        fi
    fi

    # artifacts_exist: each listed path must exist and be non-empty in the sandbox worktree
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        if [ -f "$sandbox/$f" ] && [ -s "$sandbox/$f" ]; then
            assert_ok "artifact: $f"
        else
            assert_fail "artifact: $f" "missing or empty in worktree (expected at $sandbox/$f)"
        fi
    done < <(jq -r '.assert.artifacts_exist // [] | .[]' "$scenario_json")
}

# --------------------------------------------------------------------------- #

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --model|--models) MODELS="$(printf '%s' "$2" | tr ',' ' ')"; shift 2 ;;
            --scenario)       SCENARIOS="$(printf '%s' "$2" | tr ',' ' ')"; shift 2 ;;
            --budget)         BUDGET="$2"; shift 2 ;;
            --keep)           KEEP=1; shift ;;
            -h|--help)        sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
            *)                die "unknown flag: $1" ;;
        esac
    done

    for tool in git jq go node claude; do
        command -v "$tool" >/dev/null 2>&1 || die "$tool is required for the eval"
    done
    [ -x "$AISDLC" ] || die "aisdlc not executable at $AISDLC"

    if [ -z "$SCENARIOS" ]; then
        SCENARIOS="$(cd "$HARNESS_DIR/scenarios" && ls -d */ 2>/dev/null | tr -d '/' | tr '\n' ' ')"
    fi
    [ -n "$SCENARIOS" ] || die "no scenarios found in $HARNESS_DIR/scenarios"

    # die inside $(…) only ends the subshell; a run without a digest must not record anything.
    HARNESS_FP="$(harness_fingerprint)" || exit 1

    printf 'aisdlc harness eval\n'
    printf '  scenarios: %s\n' "$SCENARIOS"
    printf '  models:    %s\n' "$MODELS"
    printf '  workdir:   %s\n' "$WORK_ROOT"
    printf '  harness:   %s\n\n' "$HARNESS_FP"

    RUN_LOG="$WORK_ROOT/run.jsonl"
    BASELINE="$WORK_ROOT/baseline.jsonl"
    mkdir -p "$WORK_ROOT"
    : > "$RUN_LOG"
    if [ -f "$LEDGER" ]; then cp "$LEDGER" "$BASELINE"; else : > "$BASELINE"; fi

    for model in $MODELS; do
        for scenario in $SCENARIOS; do
            sdir="$HARNESS_DIR/scenarios/$scenario"
            sjson="$sdir/scenario.json"
            [ -f "$sjson" ] || { printf '  skipping %s (no scenario.json)\n' "$scenario"; continue; }

            ticket="$(jq -r '.ticket' "$sjson")"
            phases="$(jq -r '.phases // "implement qa"' "$sjson")"
            inputs_fp="$(inputs_fingerprint "$sdir")"
            sandbox="$WORK_ROOT/$scenario-$model"

            printf '── %s × %s\n' "$scenario" "$model"
            make_sandbox "$sandbox"
            while IFS= read -r setup_cmd; do
                [ -n "$setup_cmd" ] || continue
                (cd "$sandbox" && eval "$setup_cmd") || die "setup: $setup_cmd"
            done < <(jq -r '.setup // [] | .[]' "$sjson")
            mkdir -p "$sandbox/specs/$ticket"
            cp "$sdir/spec.md" "$sandbox/specs/$ticket/spec.md"
            git -C "$sandbox" add -A
            git -C "$sandbox" commit -q -m "docs(spec): add approved spec for $ticket"
            git -C "$sandbox" update-ref refs/remotes/origin/master HEAD
            base="$(git -C "$sandbox" rev-parse HEAD)"

            started="$(date +%s)"
            if ! "$AISDLC" add "$ticket" --repo "$sandbox" --model "$model" --budget "$BUDGET" \
                --phase "$(printf '%s' "$phases" | tr ' ' ',')" --no-pr --plugin-dir >/dev/null; then
                printf '    could not queue — see above\n'
                record_cell "$scenario" "$model" "$inputs_fp" queue-failed ERROR false "" "" 0 \
                    "$(( $(date +%s) - started ))" ""
                continue
            fi
            "$AISDLC" run --repo "$sandbox" --once >/dev/null 2>&1
            elapsed=$(( $(date +%s) - started ))

            tjson="$(ls -1 "$sandbox"/.aisdlc/tasks/*/task.json 2>/dev/null | head -1)"
            if [ -z "$tjson" ]; then
                printf '    no task record — the runner never started\n'
                record_cell "$scenario" "$model" "$inputs_fp" no-task ERROR false "" "" 0 "$elapsed" ""
                continue
            fi
            status="$(jq -r '.status' "$tjson")"
            cost="$(jq -r '.cost_usd // 0' "$tjson")"
            branch="$(jq -r '.branch // empty' "$tjson")"
            runtime="$(jq -r '.runtime // "claude"' "$tjson")"

            if [ "$status" != "done" ]; then
                printf '    pipeline %s: %s\n' "$status" "$(jq -r '.error // "no reason recorded"' "$tjson")"
                record_cell "$scenario" "$model" "$inputs_fp" "$status" ERROR false "" "" "$cost" "$elapsed" "$runtime"
                [ "$KEEP" -eq 0 ] && rm -rf "$sandbox"
                continue
            fi

            # The worktree is gone but its branch remains: score the code the agent produced.
            if ! git -C "$sandbox" checkout -q "$branch" 2>/dev/null; then
                printf '    branch %s missing\n' "$branch"
                record_cell "$scenario" "$model" "$inputs_fp" branch-missing ERROR false "" "" "$cost" "$elapsed" "$runtime"
                continue
            fi

            score "$sandbox" "$sjson" "$ticket" "$base"
            verdict=$([ "$A_FAIL" -eq 0 ] && echo PASS || echo FAIL)
            printf '    %s — %d/%d assertions, $%s, %ds\n\n' \
                "$verdict" "$A_PASS" "$((A_PASS + A_FAIL))" "$cost" "$elapsed"
            record_cell "$scenario" "$model" "$inputs_fp" "done" "$verdict" true "$A_PASS" "$A_FAIL" "$cost" "$elapsed" "$runtime"

            [ "$KEEP" -eq 0 ] && rm -rf "$sandbox"
        done
    done

    # A run whose bookkeeping does not add up reports nothing.
    assert_run_identity || exit 1

    # ----------------------------------------------------------------------- #

    printf '\n%-22s %-8s %-7s %-12s %8s %6s  %s\n' SCENARIO MODEL VERDICT ASSERTIONS COST SECS DELTA
    while IFS=$'\t' read -r sc md inp hs vd gr ok bad cost secs; do
        if [ "$gr" = true ]; then asserts="$ok/$((ok + bad))"; else asserts='—'; fi
        printf '%-22s %-8s %-7s %-12s %8s %6s  %s\n' \
            "$sc" "$md" "$vd" "$asserts" "\$$cost" "$secs" \
            "$(baseline_delta "$sc" "$md" "$inp" "$hs" "$vd" "$gr")"
    done < <(jq -r '[.scenario, .model, .inputs, .harness, .verdict, .gradeable,
                     (.assertions_passed // 0), (.assertions_failed // 0), .cost_usd, .seconds]
                    | @tsv' "$RUN_LOG")

    # A cell that could not be graded is a defect, but never a scored assertion failure: it stays
    # out of the graded denominator and is reported on its own.
    total_cost="$(jq -r '.cost_usd' "$RUN_LOG" | awk '{s+=$1} END {printf "%.4f", s+0}')"
    graded="$(jq -s '[.[] | select(.gradeable)] | length' "$RUN_LOG")"
    passing="$(jq -s '[.[] | select(.gradeable and .verdict == "PASS")] | length' "$RUN_LOG")"
    ungradeable="$(jq -s '[.[] | select(.gradeable | not)] | length' "$RUN_LOG")"
    printf '\ntotal spend $%s · %s/%s graded scenario run(s) passing · %s ungradeable\n' \
        "$total_cost" "$passing" "$graded" "$ungradeable"
    printf 'ledger: %s\n' "$LEDGER"
    [ "$KEEP" -eq 1 ] && printf 'sandboxes kept under %s\n' "$WORK_ROOT"

    if [ "$passing" -ne "$graded" ] || [ "$ungradeable" -gt 0 ]; then
        cat <<'NOTE'

A failure here is a harness defect, not a model defect. Before reaching for a bigger model:
  - which playbook did it load? wrong row → the router wording is the bug
  - did it miss a requirement? → the UC is not observable enough
  - did it invent a convention? → the rule file does not state it explicitly
See the harness-eval skill for the full checklist.
NOTE
        exit 1
    fi
}

[ "${BASH_SOURCE[0]:-$0}" = "$0" ] || return 0
main "$@"
