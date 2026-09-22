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
`{"number":1,"branch":"…","title":"…","labels":["ai-sdlc","review"],"state":"open","verdict":"PASS","reviews":[],"body_path":"specs/<T>/pr-body.md","url":"local#1"}`.
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
`grep -il -- '{query}' .aisdlc/tracker/issues/*.md | xargs -r -n1 basename | sed 's/\.md$//'`
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
`jq -c 'select(.number=={n})' $P`
### list-prs
`jq -c 'select(.state=="{state}") | select(.labels|index("{label}"))' $P`
### search-prs
`grep -i -- '{query}' $P | jq -c .`
### create-pr
`n=$(( $(jq -s 'map(.number)|max // 0' $P 2>/dev/null) + 1 )); jq -nc --argjson n $n --arg b "$(git branch --show-current)" --arg t '{title}' --arg p '{body-file}' '{number:$n,branch:$b,title:$t,labels:[],state:"open",verdict:null,reviews:[],body_path:$p,url:("local#"+($n|tostring))}' >> $P; echo "local#$n"`
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
`jq -c --argjson n {n} --arg v '{verdict}' --arg u "{me}" --arg d "$now" 'if .number==$n then .reviews+=[{by:$u,verdict:$v,at:$d}] else . end' $P > $P.tmp && mv $P.tmp $P` then **comment-pr**.
### merge-pr
`b=$(jq -r 'select(.number=={n}).branch' $P); git merge --squash "$b" && git commit -m "$(jq -r 'select(.number=={n}).title' $P) (#{n})"` then set `.state="merged"` as in **update-pr**.
### get-pr-diff
`git diff $(git merge-base HEAD "$(jq -r 'select(.number=={n}).branch' $P)")...$(jq -r 'select(.number=={n}).branch' $P)`
### get-pr-checks
`[ -f .aisdlc/tracker/checks/{n}.json ] && cat .aisdlc/tracker/checks/{n}.json || echo '[]'` — a repo's CI may write this file; absent means no checks.
### get-run-failed-logs
`cat .aisdlc/tracker/runs/{run-id}.log 2>/dev/null || echo "no local run log"`
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
Issue: `grep -q '^labels: .*in-progress' $I || echo free`; then `grep -q "^assignees: .*{me}" $I && echo mine`; else newest `- <ISO> @<login>: 🤖 .* claimed` line: older than 60 min → `stale:<login>`, else `other:<login>`. PR: same over `.labels`, `.assignees`, and the comments file.
### release
**unlabel-issue**/**unlabel-pr** `in-progress`, then comment `🤖 /sdlc:{command} completed: {outcome}. Lock released.`
