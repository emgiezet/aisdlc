# Tracker provider: local

A file-backed tracker under `.aisdlc/tracker/` for repositories with no remote tracker, and the
provider `make selftest` and `make harness-eval` run against. Not a mock: it is where a
disconnected repo's pipeline state lives. `/sdlc:init` gitignores the directory. `{n}` is a bare
number; `{me}` is `${AISDLC_USER:-local-user}`.

## Prerequisites

`jq`, `git`. **auth-check**: `test -d .aisdlc/tracker/issues || mkdir -p .aisdlc/tracker/issues .aisdlc/tracker/prs`.

## Conventions

Issue `{n}` is `.aisdlc/tracker/issues/{n}.md`:

```
---
number: {n}
title: <text>
state: open|closed
labels: [bug, in-progress]
assignees: [local-user]
author: <login>
created: <ISO-8601>
---
<body>

## Comments
- <ISO-8601> @<login>: <one line>
```

PRs are lines of `.aisdlc/tracker/prs.jsonl`:
`{"number":1,"branch":"…","baseRefName":"…","title":"…","labels":["ai-sdlc","review"],"state":"open","isDraft":false,"createdAt":"…","verdict":null,"reviews":[],"body_path":"specs/<T>/pr-body.md","url":"local#1","author":"local-user","assignees":[],"mergeCommit":null}`.
PR comments append to `.aisdlc/tracker/prs/{n}.comments.md`. A PR "URL" is `local#{n}`; chain
markers print the body path: `PR: #{n} (specs/<T>/pr-body.md)`.

Frontmatter edits use `sed -i` on the one key line; JSONL edits rewrite the file through `jq -c`.
`I=.aisdlc/tracker/issues/{n}.md`, `P=.aisdlc/tracker/prs.jsonl`, `now=$(date -u +%FT%TZ)`.

## Operations

### auth-check
see Prerequisites.
### current-user
`echo "${AISDLC_USER:-local-user}"`
### get-issue
`cat $I` — read the frontmatter keys and the body as they stand.
### search-issues
`for f in .aisdlc/tracker/issues/*.md; do { [ '{state}' = all ] || grep -q "^state: {state}" "$f"; } && grep -qi -- '{query}' "$f" && basename "$f" .md; done`
### create-issue
`n=$(( $(ls .aisdlc/tracker/issues | sed 's/\.md$//' | sort -n | tail -1) + 1 )); printf -- '---\nnumber: %s\ntitle: %s\nstate: open\nlabels: [%s]\nassignees: []\nauthor: %s\ncreated: %s\n---\n%s\n\n## Comments\n' "$n" '{title}' '{labels}' "{me}" "$now" "$(cat {body-file})" > .aisdlc/tracker/issues/$n.md; echo "$n"`
### comment-issue
`printf -- '- %s @%s: %s\n' "$now" "{me}" "$(tr '\n' ' ' < {body-file})" >> $I`
### close-issue
`sed -i 's/^state: .*/state: closed/' $I` then **comment-issue** with `{comment}`.
### label-issue
`grep -q '^labels: .*\b{label}\b' $I || sed -i -E 's/^labels: \[(.*)\]/labels: [\1, {label}]/; s/\[, /[/' $I`
### unlabel-issue
`sed -i -E 's/^(labels: \[.*)\b{label}\b,? ?(.*\])/\1\2/; s/, \]/]/; s/\[ /[/' $I`
### assign-issue
`sed -i -E 's/^assignees: \[(.*)\]/assignees: [\1, {user}]/; s/\[, /[/' $I`
### get-pr
`n={n}; rec=$(jq --argjson n $n -c 'select(.number==$n)' $P); bp=$(echo "$rec"|jq -r '.body_path // empty'); br=$(echo "$rec"|jq -r '.branch // empty'); body=$([ -n "$bp" ] && cat "$bp" 2>/dev/null); cf=.aisdlc/tracker/prs/$n.comments.md; comments=$(cat "$cf" 2>/dev/null); mt=$(git merge-tree "$(git merge-base HEAD "$br" 2>/dev/null)" HEAD "$br" 2>/dev/null | { grep -qF '<<<<<<<' && echo CONFLICTING || echo MERGEABLE; }); mt=${mt:-MERGEABLE}; echo "$rec" | jq -c --arg body "$body" --arg comments "$comments" --arg mt "$mt" '(.branch) as $br | . + {body:$body,comments:$comments,mergeable:$mt,headRefName:$br}'`
### list-prs
`jq -c --arg s '{state}' --arg l '{label}' 'select(($s=="all") or (.state==$s)) | select(.labels|index($l)) | {number,title,labels,url,headRefName:.branch,isDraft:(.isDraft//false),createdAt:(.createdAt//""),author:(.author//"local-user")}' $P`
### search-prs
`jq -c --arg q '{query}' --arg s '{state}' 'select(($s=="all") or (.state==$s)) | select(.title|test($q;"i")) | {number,title,url}' $P`
### create-pr
`n=$(( $(jq -s 'map(.number)|max // 0' $P 2>/dev/null) + 1 )); me=${AISDLC_USER:-local-user}; jq -nc --argjson n $n --arg b "$(git branch --show-current)" --arg t '{title}' --arg p '{body-file}' --arg base '{base}' --arg v '{verdict}' --arg u "$me" --arg d "$now" '{number:$n,branch:$b,baseRefName:$base,title:$t,labels:[],state:"open",isDraft:false,createdAt:$d,verdict:($v|if . == "null" or . == "" then null else . end),reviews:[],body_path:$p,url:("local#"+($n|tostring)),author:$u,assignees:[],mergeCommit:null}' >> $P; echo "local#$n"`
### update-pr
`jq -c --argjson n {n} --arg t '{title}' 'if .number==$n then .title=$t else . end' $P > $P.tmp && mv $P.tmp $P`
### comment-pr
`mkdir -p .aisdlc/tracker/prs; { printf -- '\n---\n%s @%s\n' "$now" "{me}"; cat {body-file}; } >> .aisdlc/tracker/prs/{n}.comments.md`
### label-pr
`jq -c --argjson n {n} 'if .number==$n then .labels=((.labels+["{label}"])|unique) else . end' $P > $P.tmp && mv $P.tmp $P`
### unlabel-pr
`jq -c --argjson n {n} 'if .number==$n then .labels=(.labels-["{label}"]) else . end' $P > $P.tmp && mv $P.tmp $P`
### assign-pr
`jq -c --argjson n {n} 'if .number==$n then .assignees=((.assignees//[])+["{user}"]|unique) else . end' $P > $P.tmp && mv $P.tmp $P`
### review-pr
`jq -c --argjson n {n} --arg v '{verdict}' --arg u "${AISDLC_USER:-local-user}" --arg d "$now" 'if .number==$n then .reviews+=[{by:$u,verdict:$v,at:$d}]|.verdict=$v else . end' $P > $P.tmp && mv $P.tmp $P` then **comment-pr**.
### merge-pr
`b=$(jq -r 'select(.number=={n}).branch' $P); git merge --squash "$b" && git commit -m "$(jq -r 'select(.number=={n}).title' $P) (#{n})"; mc=$(git rev-parse HEAD); jq -c --argjson n {n} --arg mc "$mc" 'if .number==$n then .state="merged"|.mergeCommit=$mc else . end' $P > $P.tmp && mv $P.tmp $P`
### get-pr-diff
`git diff $(git merge-base HEAD "$(jq -r 'select(.number=={n}).branch' $P)")...$(jq -r 'select(.number=={n}).branch' $P)`
### get-pr-checks
`[ -f .aisdlc/tracker/checks/{n}.json ] && cat .aisdlc/tracker/checks/{n}.json || echo '[]'` — a repo's CI may write this file; absent means no checks.
### get-run-failed-logs
`cat .aisdlc/tracker/runs/{run-id}.log 2>/dev/null || echo "no local run log"`
### rerun-check
`echo "no CI runs under local"; exit 1`
### checkout-pr
`git checkout --detach "$(jq -r 'select(.number=={n}).branch' $P)"`
### attach-image-evidence
`mkdir -p .aisdlc/tracker/evidence/pr-{n}; cp {image...} .aisdlc/tracker/evidence/pr-{n}/; ls .aisdlc/tracker/evidence/pr-{n}/* | sed 's/^/![](/; s/$/)/' > {body-file}.imgs` then **comment-pr**.
### ensure-labels
no-op — labels are free-form strings here.
### claim
**assign-issue** `{me}` (or **assign-pr**), **label-issue** `in-progress` (or **label-pr**), then
**comment-issue**/**comment-pr** with `🤖 /sdlc:{command} claimed $now`. Read back: label and
assignee present.
### check-claim
Issue: `me=${AISDLC_USER:-local-user}; grep -q '^labels: .*in-progress' $I || { echo free; exit 0; }; grep -q "^assignees: .*${me}" $I && { echo mine; exit 0; }; line=$(grep -E '🤖 .* claimed' $I | tail -1); login=$(echo "$line" | sed 's/.*@//;s/:.*//' ); ts=$(echo "$line" | grep -oE '[0-9]{4}-[0-9T:-]+Z' | head -1); [ -z "$ts" ] && { echo "other:${login:-unknown}"; exit 0; }; [ $(( $(date -u +%s) - $(date -d "$ts" +%s 2>/dev/null || echo 0) )) -gt 3600 ] && echo "stale:$login" || echo "other:$login"`
PR: `me=${AISDLC_USER:-local-user}; jq -e --argjson n {n} 'select(.number==$n).labels|index("in-progress")' $P >/dev/null || { echo free; exit 0; }; jq -e --argjson n {n} --arg me "$me" 'select(.number==$n).assignees|index($me)' $P >/dev/null && { echo mine; exit 0; }; cf=.aisdlc/tracker/prs/{n}.comments.md; ts_login=$(awk 'prev ~ /^[0-9]{4}/ && /🤖 .* claimed/ {print prev} {prev=$0}' "$cf" 2>/dev/null | tail -1); login=$(echo "$ts_login" | sed 's/.*@//'); ts=$(echo "$ts_login" | grep -oE '[0-9]{4}-[0-9T:-]+Z' | head -1); [ -z "$ts" ] && { echo "other:${login:-unknown}"; exit 0; }; [ $(( $(date -u +%s) - $(date -d "$ts" +%s 2>/dev/null || echo 0) )) -gt 3600 ] && echo "stale:$login" || echo "other:$login"`
### release
**unlabel-issue**/**unlabel-pr** `in-progress`, then comment `🤖 /sdlc:{command} completed: {outcome}. Lock released.`
