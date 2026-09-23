---
description: Generate a CHANGELOG entry from merged labelled PRs since a tag — groups by conventional-commit type, credits git-log authors (never the merger), prepends the entry to CHANGELOG.md, and ships it as a docs PR. Use at the end of a release cycle before tagging.
allowed-tools: Bash, Read, Grep, Glob, SlashCommand, Agent
---

# /sdlc:changelog

`$ARGUMENTS` is optionally `--since <tag>`. Read `.claude/sdlc.md` for the **Tracker
descriptor** and the profile PR label (`ai-sdlc`).

---

## Phase 1: Resolve the since-tag [HARD STOP]

If `--since <tag>` is passed, use that tag. Otherwise run:

```bash
git describe --tags --abbrev=0
```

If that command fails (no tags yet), use the first commit as the base:

```bash
git rev-list --max-parents=0 HEAD
```

Record the resolved base as `<since>`.

---

## Phase 2: Collect merged PRs since the base

Read `.aisdlc/config.json`. If it contains a `model_roles` key, dispatch `sdlc-scribe` to run
this phase and Phase 3: pass it `<since>`, the profile label, and the extraction rules stated
there. It returns the type → `[(#n, title, authors)]` map and nothing else — PR bodies and raw
`git log` output stay in its context. Version choice (Phase 4) and the entry (Phase 5) are yours
either way. Without the key, run both phases yourself:

1. **list-prs** `merged` with the profile label — retrieve number, title, and url for each.
2. For each listed PR, **get-pr** `{n}` and record the `mergeCommit` field.
3. Enumerate all commits reachable since `<since>`:
   ```bash
   git log <since>..HEAD --format="%H"
   ```
4. Keep only PRs whose `mergeCommit` SHA appears in that list. If the intersection is empty:
   print `nothing to release since <since>` and stop. Do not write to `CHANGELOG.md`.

---

## Phase 3: Author and type extraction

For each qualifying PR:

1. **Conventional-commit type**: extract from the PR title prefix
   (`feat`, `fix`, `docs`, `chore`, `refactor`, `perf`, `test`, `ci`).
   If the title has no recognised prefix, classify as `other`.
2. **Author**: run on the squash commit SHA:
   ```bash
   git log --format="%an" <merge-sha>^..<merge-sha>
   ```
   Never use the merger's name — use the commit author embedded in the squash. If the squash
   has multiple authors in the trailer (`Co-authored-by:`), list all of them.

Build a type → `[(#n, title, authors)]` map.

---

## Phase 4: Determine the version

Derive `<version>` from the since-tag (or `v0.1.0` when no prior tag exists):

- Any `feat` entry present → increment the **minor** component (e.g. `v1.2.0 → v1.3.0`).
- Only `fix` or other → increment the **patch** component (e.g. `v1.2.0 → v1.2.1`).

Do not write to package manifests or create a git tag — the changelog PR is a docs PR only.

---

## Phase 5: Write the CHANGELOG entry [REQUIRED]

Prepend to `CHANGELOG.md` (create the file if it does not exist):

```markdown
## [<version>] — <YYYY-MM-DD>

### Features
- <PR title> (#<n>) — @<author>

### Bug fixes
- <PR title> (#<n>) — @<author>

### Documentation
- <PR title> (#<n>) — @<author>

### Other
- <PR title> (#<n>) — @<author>
```

Omit any section that has no entries. Separate from the previous entry with a blank line.

Commit the entry:

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): release <version>"
```

---

## Phase 6: Ship [REQUIRED]

Invoke `/sdlc:ship changelog-<version> --docs` via `SlashCommand`. If unavailable, read
`${CLAUDE_PLUGIN_ROOT}/commands/ship.md` and follow it verbatim.

Pass the ship output in the standard block:

```
— PREVIOUS STEP (/sdlc:ship changelog-<version> --docs) said —
<ship output>
```

---

## Phase 7: Report

```
## Changelog — <version>
Since: <since>
PRs included: <n>
Types: feat <a>, fix <b>, docs <c>, other <d>
Entry: CHANGELOG.md (top, committed)

Verdict: PASS
PR: #<n> (<url>)
```

---

## Not to be confused with

- **Release tagging** — this command writes a CHANGELOG entry only. It does not run `git tag`,
  bump `package.json`, or publish to any registry. Tag after the changelog PR merges.
- **`/sdlc:ship`** — this command calls ship with `--docs` as its final step. Ship itself
  does not know which PRs to credit; that logic lives here.
- **`/sdlc:close-fixed`** — closes issues fixed by merged PRs. Run that separately; this
  command only writes the changelog.
