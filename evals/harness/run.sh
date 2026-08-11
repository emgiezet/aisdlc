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

MODELS="sonnet"
SCENARIOS=""
BUDGET="${AISDLC_BUDGET:-5}"
KEEP=0

die() { printf 'run.sh: %s\n' "$1" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --model|--models) MODELS="$(printf '%s' "$2" | tr ',' ' ')"; shift 2 ;;
        --scenario)       SCENARIOS="$(printf '%s' "$2" | tr ',' ' ')"; shift 2 ;;
        --budget)         BUDGET="$2"; shift 2 ;;
        --keep)           KEEP=1; shift ;;
        -h|--help)        sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# --------------------------------------------------------------------------- #

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

    # qa_verdict
    local want_verdict
    want_verdict="$(jq -r '.assert.qa_verdict // empty' "$scenario_json")"
    if [ -n "$want_verdict" ]; then
        local report="$sandbox/specs/$ticket/qa-report.md"
        if [ ! -f "$report" ]; then
            assert_fail "qa verdict" "no qa-report.md — the QA phase produced nothing"
        elif grep -qi "Verdict:[^A-Za-z]*$want_verdict" "$report"; then
            assert_ok "qa verdict: $want_verdict"
        else
            assert_fail "qa verdict" "expected $want_verdict, report says: $(grep -io 'verdict.*' "$report" | head -1)"
        fi
    fi
}

# --------------------------------------------------------------------------- #

printf 'aisdlc harness eval\n'
printf '  scenarios: %s\n' "$SCENARIOS"
printf '  models:    %s\n' "$MODELS"
printf '  workdir:   %s\n\n' "$WORK_ROOT"

RESULTS="$WORK_ROOT/results.tsv"
mkdir -p "$WORK_ROOT"
: > "$RESULTS"

for model in $MODELS; do
    for scenario in $SCENARIOS; do
        sdir="$HARNESS_DIR/scenarios/$scenario"
        sjson="$sdir/scenario.json"
        [ -f "$sjson" ] || { printf '  skipping %s (no scenario.json)\n' "$scenario"; continue; }

        ticket="$(jq -r '.ticket' "$sjson")"
        phases="$(jq -r '.phases // "implement qa"' "$sjson")"
        sandbox="$WORK_ROOT/$scenario-$model"

        printf '── %s × %s\n' "$scenario" "$model"
        make_sandbox "$sandbox"
        mkdir -p "$sandbox/specs/$ticket"
        cp "$sdir/spec.md" "$sandbox/specs/$ticket/spec.md"
        git -C "$sandbox" add -A
        git -C "$sandbox" commit -q -m "docs(spec): add approved spec for $ticket"
        git -C "$sandbox" update-ref refs/remotes/origin/master HEAD
        base="$(git -C "$sandbox" rev-parse HEAD)"

        started="$(date +%s)"
        "$AISDLC" add "$ticket" --repo "$sandbox" --model "$model" --budget "$BUDGET" \
            --phase "$(printf '%s' "$phases" | tr ' ' ',')" --no-pr --plugin-dir >/dev/null \
            || { printf '    could not queue — see above\n'; continue; }
        "$AISDLC" run --repo "$sandbox" --once >/dev/null 2>&1
        elapsed=$(( $(date +%s) - started ))

        tjson="$(ls -1 "$sandbox"/.aisdlc/tasks/*/task.json 2>/dev/null | head -1)"
        if [ -z "$tjson" ]; then
            printf '    no task record — the runner never started\n'
            printf '%s\t%s\tERROR\t0\t0\t0\t%s\n' "$scenario" "$model" "$elapsed" >> "$RESULTS"
            continue
        fi
        status="$(jq -r '.status' "$tjson")"
        cost="$(jq -r '.cost_usd // 0' "$tjson")"
        branch="$(jq -r '.branch // empty' "$tjson")"

        if [ "$status" != "done" ]; then
            printf '    pipeline %s: %s\n' "$status" "$(jq -r '.error // "no reason recorded"' "$tjson")"
            printf '%s\t%s\t%s\t0\t0\t%s\t%s\n' "$scenario" "$model" "$status" "$cost" "$elapsed" >> "$RESULTS"
            [ "$KEEP" -eq 0 ] && rm -rf "$sandbox"
            continue
        fi

        # The worktree is gone but its branch remains: score the code the agent produced.
        git -C "$sandbox" checkout -q "$branch" 2>/dev/null \
            || { printf '    branch %s missing\n' "$branch"; continue; }

        score "$sandbox" "$sjson" "$ticket" "$base"
        verdict=$([ "$A_FAIL" -eq 0 ] && echo PASS || echo FAIL)
        printf '    %s — %d/%d assertions, $%s, %ds\n\n' \
            "$verdict" "$A_PASS" "$((A_PASS + A_FAIL))" "$cost" "$elapsed"
        printf '%s\t%s\t%s\t%d\t%d\t%s\t%s\n' \
            "$scenario" "$model" "$verdict" "$A_PASS" "$A_FAIL" "$cost" "$elapsed" >> "$RESULTS"

        [ "$KEEP" -eq 0 ] && rm -rf "$sandbox"
    done
done

# --------------------------------------------------------------------------- #

printf '\n%-22s %-8s %-7s %-12s %8s %6s\n' SCENARIO MODEL VERDICT ASSERTIONS COST SECS
while IFS=$'\t' read -r sc md vd ok bad cost secs; do
    printf '%-22s %-8s %-7s %-12s %8s %6s\n' \
        "$sc" "$md" "$vd" "$ok/$((ok + bad))" "\$$cost" "$secs"
done < "$RESULTS"

total_cost="$(awk -F'\t' '{s+=$6} END {printf "%.4f", s+0}' "$RESULTS")"
fails="$(awk -F'\t' '$3 != "PASS"' "$RESULTS" | wc -l | tr -d ' ')"
printf '\ntotal spend $%s · %s scenario run(s) not passing\n' "$total_cost" "$fails"
[ "$KEEP" -eq 1 ] && printf 'sandboxes kept under %s\n' "$WORK_ROOT"

if [ "${fails:-0}" -gt 0 ]; then
    cat <<'NOTE'

A failure here is a harness defect, not a model defect. Before reaching for a bigger model:
  - which playbook did it load? wrong row → the router wording is the bug
  - did it miss a requirement? → the UC is not observable enough
  - did it invent a convention? → the rule file does not state it explicitly
See the harness-eval skill for the full checklist.
NOTE
    exit 1
fi
