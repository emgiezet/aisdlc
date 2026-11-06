#!/usr/bin/env bash
# coverage.sh — which units of this harness a test claims to exercise, and a ratchet on it.
#
# Units are enumerated from disk, so the same script runs against a materialised base tree:
#   command     plugins/sdlc/commands/*.md                       filename stem
#   skill       plugins/sdlc/skills/*/SKILL.md                   directory name
#   hook        run-hook.cmd arguments in plugins/sdlc/hooks/hooks.json   guard mode or script
#   subcommand  the dispatch case of plugins/sdlc/bin/aisdlc     first name of each branch
#   ledger      the dispatch case of plugins/sdlc/bin/aisdlc-ledger
#   operation   `### ` headings of templates/{trackers,browsers}/TEMPLATE.md   first word
#
# A claim is a comment line that starts `# covers:` followed by `<class>:<id>`, comma-separated,
# in evals/harness/{selftest,run,coverage}.sh or .github/workflows/validate.yml. A unit with at
# least one claim is covered. Claim only what the case beside it actually drives: a false claim
# is worse than an uncovered unit, because the ratchet then defends it.
#
# Usage:
#   coverage.sh [--root <dir>]          table, then a summary line per class
#   coverage.sh [--root <dir>] --json   one {"class","id","status","covered_by"} object per line
#   coverage.sh --check --base <ref>    fail when a unit covered at <ref> is still present but no
#                                       longer covered; a new uncovered unit is a note, not a failure
#
# The registry is never committed: regenerating it is cheap, a committed copy conflicts per PR.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"
ROOT="$REPO" MODE=table BASE=""
CLAIM_FILES="evals/harness/selftest.sh evals/harness/run.sh evals/harness/coverage.sh .github/workflows/validate.yml"

die() { printf 'coverage: %s\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
    case "$1" in
        --root)  [ $# -ge 2 ] || die "--root needs a value"; ROOT="$2"; shift 2 ;;
        --json)  MODE=json; shift ;;
        --check) MODE=check; shift ;;
        --base)  [ $# -ge 2 ] || die "--base needs a value"; BASE="$2"; shift 2 ;;
        -h|--help) sed -n '2,24s/^# \{0,1\}//p' "$0"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done
[ -d "$ROOT" ] || die "no such root: $ROOT"

# units ROOT — `class<TAB>id`, sorted, one per unit.
units() {
    local r="$1" f
    for f in "$r"/plugins/sdlc/commands/*.md; do
        [ -f "$f" ] && printf 'command\t%s\n' "$(basename "$f" .md)"
    done
    for f in "$r"/plugins/sdlc/skills/*/SKILL.md; do
        [ -f "$f" ] && printf 'skill\t%s\n' "$(basename "$(dirname "$f")")"
    done
    f="$r/plugins/sdlc/hooks/hooks.json"
    [ -f "$f" ] && jq -r '.hooks[][].hooks[].command' "$f" \
        | awk '{ sub(/.*run-hook\.cmd"?[[:space:]]*/, ""); if ($0 != "") print "hook\t" $NF }'
    f="$r/plugins/sdlc/bin/aisdlc"
    [ -f "$f" ] && awk 'match($0, /^[[:space:]]+[a-z][a-z-]*(\|[^)]*)?\)[[:space:]]+(shift; *)?cmd_/) {
        s = $0; sub(/^[[:space:]]+/, "", s); sub(/[|)].*/, "", s); print "subcommand\t" s }' "$f"
    f="$r/plugins/sdlc/bin/aisdlc-ledger"
    [ -f "$f" ] && awk 'match($0, /^[[:space:]]+[a-z][a-z-]*\)[[:space:]]+cmd_/) {
        s = $0; sub(/^[[:space:]]+/, "", s); sub(/\).*/, "", s); print "ledger\t" s }' "$f"
    for f in "$r"/plugins/sdlc/templates/trackers/TEMPLATE.md "$r"/plugins/sdlc/templates/browsers/TEMPLATE.md; do
        [ -f "$f" ] && awk '/^### [^[:space:]]/ { print "operation\t" $2 }' "$f"
    done
}

# claims ROOT — `class<TAB>id<TAB>file:line` for every claim in the claim files.
claims() {
    local r="$1" f
    for f in $CLAIM_FILES; do
        [ -f "$r/$f" ] || continue
        awk -v f="$f" 'match($0, /^[[:space:]]*#[[:space:]]*covers:[[:space:]]*/) {
            n = split(substr($0, RLENGTH + 1), parts, ",")
            for (i = 1; i <= n; i++) {
                p = parts[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", p)
                if (p !~ /^[a-z]+:[^[:space:]]+$/) continue
                c = p; sub(/:.*/, "", c); id = p; sub(/^[^:]*:/, "", id)
                print c "\t" id "\t" f ":" NR
            }
        }' "$r/$f"
    done
}

# registry ROOT — one JSON object per unit, sorted by class then id.
registry() {
    local r="$1"
    jq -cn --rawfile u <(units "$r" | LC_ALL=C sort -u) --rawfile c <(claims "$r") '
        def rows($s): $s | split("\n") | map(select(length > 0) | split("\t"));
        (rows($c) | group_by(.[0] + ":" + .[1]) | map({key: (.[0][0] + ":" + .[0][1]), value: map(.[2])})
            | from_entries) as $by
        | rows($u)[] | ($by[.[0] + ":" + .[1]] // []) as $cb
        | {class: .[0], id: .[1], status: (if ($cb | length) > 0 then "covered" else "UNCOVERED" end),
           covered_by: $cb}'
}

table() {
    local reg known
    reg="$(registry "$ROOT")"
    printf '%s\n' "$reg" | jq -r '[.class, .id, .status, (.covered_by | join(" "))] | @tsv' \
        | awk -F'\t' 'BEGIN { printf "%-11s %-22s %-10s %s\n", "class", "id", "status", "covered-by" }
            { printf "%-11s %-22s %-10s %s\n", $1, $2, $3, $4 }'
    printf '\n'
    printf '%s\n' "$reg" | jq -rs 'group_by(.class)[]
        | "\(.[0].class): \(map(select(.status == "covered")) | length)/\(length) covered"'
    # A claim that names no unit is stale or mistyped; say so, it covers nothing.
    known="$(printf '%s\n' "$reg" | jq -r '"\(.class):\(.id)"')"
    claims "$ROOT" | while IFS=$'\t' read -r c id where; do
        printf '%s\n' "$known" | grep -qxF "$c:$id" || printf 'note: claim %s:%s at %s names no unit\n' "$c" "$id" "$where"
    done
}

check() {
    [ -n "$BASE" ] || die "--check needs --base <ref>"
    git -C "$REPO" rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null || die "unknown base ref: $BASE"
    local tmp rc=0 base_reg head_reg
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064 # expand now: the path is fixed for this run
    trap "rm -rf '$tmp'" EXIT
    mkdir -p "$tmp/tree"
    if ! git -C "$REPO" archive "$BASE" | tar -x -C "$tmp/tree" 2>/dev/null; then
        rm -rf "$tmp/tree"
        git -C "$REPO" worktree add --detach --quiet "$tmp/tree" "$BASE" >/dev/null 2>&1 \
            || die "cannot materialise $BASE"
    fi
    base_reg="$(registry "$tmp/tree")"
    head_reg="$(registry "$ROOT")"
    git -C "$REPO" worktree remove --force "$tmp/tree" >/dev/null 2>&1 || true
    local out
    out="$(jq -rn --argjson b "$(printf '%s\n' "$base_reg" | jq -s .)" --argjson h "$(printf '%s\n' "$head_reg" | jq -s .)" '
        ($b | map({key: "\(.class):\(.id)", value: .status}) | from_entries) as $base
        | $h[] | ($base["\(.class):\(.id)"]) as $was
        | if $was == "covered" and .status != "covered" then
            "COVERAGE DROPPED: \(.class) unit \"\(.id)\" is covered on the base but is now UNCOVERED — restore the covers: claim, or cover it from another case."
          elif $was == null and .status != "covered" then
            "note: new \(.class) unit \"\(.id)\" has no covers: claim; not a failure"
          else empty end')"
    [ -z "$out" ] || printf '%s\n' "$out"
    printf '%s\n' "$out" | grep -q '^COVERAGE DROPPED:' && rc=1
    printf 'coverage: %s covered now, %s at %s\n' \
        "$(printf '%s\n' "$head_reg" | jq -s 'map(select(.status == "covered")) | length')" \
        "$(printf '%s\n' "$base_reg" | jq -s 'map(select(.status == "covered")) | length')" "$BASE"
    return "$rc"
}

case "$MODE" in
    table) table ;;
    json)  registry "$ROOT" ;;
    check) check ;;
esac
