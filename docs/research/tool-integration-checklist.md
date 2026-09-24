# slop-guard — New Tool Integration Checklist

> **Running example**: a Go binary tool called `mytool` that runs on `.tf` files at the medium tier, has a config file `.mytool.yaml`, and emits JSON with fields `rule_id`, `message`, `line`.
> Substitute the real name, version, assets, and output format.

Steps must be performed in the order shown. The Makefile `validate-slopguard` gate (step 2b) will fail until every step is complete, so an agent that runs it mid-way will see failures.

---

## 0. Pre-conditions

- Confirm the tool binary releases pre-compiled platform assets (no server, no licence key, no network at analysis time).
- Confirm the licence is permissive enough to invoke as a separate process (the existing tools use GPLv3, LGPL-2.1; AGPL tools and tools with commercial restrictions require explicit human review before adding).
- Record the exact release version and the download URL + sha256 for each of the four platforms: `linux-amd64`, `linux-arm64`, `darwin-amd64`, `darwin-arm64`.

---

## 1. `tools/tools.lock.json` — Add the lock entry

**File**: `plugins/slop-guard/tools/tools.lock.json`  
**Current last tool key** (for placement reference): `zizmor` (line ~234).

### Entry schema (all fields)

```jsonc
"mytool": {
  "version": "1.2.3",          // required; exact semver as reported by --version
  "bin": "mytool",             // required; the executable filename inside the archive
  "assets": {                  // required for binary tools
    "linux-amd64":  { "url": "https://…/mytool-1.2.3-linux-amd64.tar.gz",   "sha256": "abc…" },
    "linux-arm64":  { "url": "https://…/mytool-1.2.3-linux-arm64.tar.gz",   "sha256": "def…" },
    "darwin-amd64": { "url": "https://…/mytool-1.2.3-darwin-amd64.tar.gz",  "sha256": "ghi…" },
    "darwin-arm64": { "url": "https://…/mytool-1.2.3-darwin-arm64.tar.gz",  "sha256": "jkl…" }
  }
  // ALTERNATIVES (mutually exclusive with assets):
  // "python_lock": "tools/python/requirements.lock"  — for pip-installable tools (checkov, ruff)
  // "node_lock": "tools/node/package-lock.json"      — for npm-installable tools (eslint-stack)
}
```

### How `lib/tools.sh` consumes this entry

| Accessor | Where | What it reads |
|---|---|---|
| `lock_version "mytool"` | line ~174 | `.tools["mytool"].version` |
| `lock_bin "mytool"` | line ~180 | `.tools["mytool"].bin // "mytool"` |
| `lock_field "mytool" "linux-amd64" "url"` | line ~170 | `.tools["mytool"].assets["linux-amd64"].url` |
| `lock_field "mytool" "linux-amd64" "sha256"` | line ~170 | `.tools["mytool"].assets["linux-amd64"].sha256` |
| `lock_metadata "mytool" "python_lock"` | line ~185 | `.tools["mytool"].python_lock` |
| `lock_metadata "mytool" "node_lock"` | line ~185 | `.tools["mytool"].node_lock` |
| `lock_tools` | line ~190 | all keys in `.tools` |

`install_tool "mytool"` (line ~488): checks for `python_lock` and `node_lock` first; if both absent, uses `assets` for the current platform. Downloads to a temp dir, verifies sha256, extracts (`.tar.gz`, `.tar.xz`, `.zip`, or raw binary), moves to `${CLAUDE_PLUGIN_DATA}/tools/mytool/<version>/`, and atomically symlinks `current`.

### Version matching

`tool_version_matches "mytool" "<path>"` (line ~355):
1. Reads `lock_version` → strips leading `v`.
2. Calls `tool_version_output "mytool" "<path>"` (line ~348): runs `"$binary" --version 2>&1` by default.
3. Greps the first `N.N.N` token from the output; falls back to `N.N`.
4. Exact equality check — `1.2.3` does **not** match `1.2.30`.

**Special cases**: if `mytool --version` does not include a dotted-integer token, add a new case to `tool_version_output` (line ~348-351):
```bash
kube-linter) "$2" version 2>&1 ;;   # existing example — uses 'version' subcommand
mytool)      "$2" --version 2>&1 ;; # add only if truly different from default
```

For tflint, an extra post-install step also runs (`--init`) at line ~645. Add an analogous block for any tool that requires a one-time plugin download after the binary is installed.

---

## 2. `rules/stacks.json` — Wire the tool to one or more stacks

**File**: `plugins/slop-guard/rules/stacks.json`

If `mytool` applies to Terraform files, append `"mytool"` to the `tools` array of the `terraform` entry (currently `"tools": ["tflint", "checkov"]`):

```jsonc
"terraform": {
  "tier": 1,
  "tools": ["tflint", "checkov", "mytool"],  // ADD HERE
  ...
}
```

If the tool applies to a new file type not yet represented by any stack, add a new stack entry with `tier`, `tools`, `anchors`, `globs`, and `skill`.

### Three `make validate-slopguard` gates that now apply (Makefile lines 197-232)

1. **Every stack entry must declare a `tools` array** (line 197-201). The new entry (or the edited terraform entry) must have `"tools": [...]`, not a missing key.

2. **Every tool in `tools` must be pinned in `tools.lock.json`** (line 218-224). `mytool` must be present in the lockfile (step 1) before this gate passes.

3. **Every pinned tool must be reachable from a stack or the core set** (line 225-232). The check unions all `tools` arrays from every stack entry with `SLOPGUARD_CORE_TOOLS` and compares to `lock_tools`. If `mytool` is in the lockfile but not in any `tools` array and not in `SLOPGUARD_CORE_TOOLS`, the gate fails with: `a pinned tool belongs to no stack and is not core — it would never run`.

### `SLOPGUARD_CORE_TOOLS` (only if the tool must run on every project)

**File**: `plugins/slop-guard/lib/detect.sh`, line 156:
```bash
SLOPGUARD_CORE_TOOLS="betterleaks jq shellcheck"
```
Append `mytool` here **only** if it must run on every project regardless of stacks (like secret scanning). Stack-specific tools go in `stacks.json` only.

---

## 3. `lib/dispatch.sh` — Add the runner function and register its routing

**File**: `plugins/slop-guard/lib/dispatch.sh`

### 3a. Choose the tier

| Criterion | Fast tier (≤8 s) | Medium tier (≤45 s) |
|---|---|---|
| Invoked from | `post-write --tier=fast` | `post-write --tier=medium` (asyncRewake) |
| Timeout var | `_dispatch_timeout` (default 8 s) | `_dispatch_medium_timeout` (default 45 s) |
| Routing table | `_dispatch_tools_for_file` line 698 | `_dispatch_medium_tools_for_file` line 1219 |
| Example | `_dispatch_run_ruff` line 277 | `_dispatch_run_checkov` line 1090 |

### 3b. Write the runner function

**Placement**: immediately before `_dispatch_medium_tools_for_file` (line 1217) for medium-tier, or before `_dispatch_tools_for_file` (line 695) for fast-tier.

**Contract** (7 positional arguments, identical for both tiers):
```
_dispatch_run_mytool  file  session_id  agent_id  project_dir
                      is_untracked  changed_ranges  findings_out
```

**Canonical implementation** (modelled on `_dispatch_run_checkov` line 1090-1140):

```bash
# _dispatch_run_mytool  file session_id agent_id project_dir
#                       is_untracked changed_ranges findings_out
_dispatch_run_mytool() {
    local file="$1" session_id="$2" agent_id="$3" project_dir="$4"
    local is_untracked="$5" changed_ranges="$6" findings_out="$7"

    # 1. Resolve binary (project-first → plugin → PATH at locked version).
    local tool_bin; tool_bin="$(CLAUDE_PROJECT_DIR="$project_dir" resolve_tool mytool 2>/dev/null || true)"
    if [ -z "$tool_bin" ]; then
        if ! _dispatch_tool_unavail_seen "$session_id" "$agent_id" mytool; then
            _dispatch_tool_unavail_mark "$session_id" "$agent_id" mytool
            printf 'slopguard: mytool unavailable — run: slopguard doctor --install\n' >&2
        fi
        return 0  # Z6 fail-open
    fi

    # 2. Config mode gate.
    local config; config="$(tool_config_path mytool "$project_dir")"
    local config_mode; config_mode="$(tool_config_mode mytool "$project_dir")"
    [ "$config_mode" = "skip" ] && return 0

    # 3. Run the tool with appropriate timeout.
    local raw exit_code=0
    raw="$(timeout "$(_dispatch_medium_timeout)" \
        "$tool_bin" --config "$config" --output=json "$file" 2>/dev/null)" || exit_code=$?
    # 0 = clean, 1 = findings; anything else = tool crash → fail-open.
    [ "$exit_code" -eq 0 ] || [ "$exit_code" -eq 1 ] || return 0
    [ -n "$raw" ] || return 0

    # 4. Load the mapping file.
    local mapping="${CLAUDE_PLUGIN_ROOT}/rules/mapping/mytool.yaml"

    # 5. Parse JSON output with jq → TSV → loop.
    local rule_id msg line ap_id severity category cwe_str cwe_json fix snippet lookup
    while IFS=$'\t' read -r rule_id msg line; do
        [ -n "$rule_id" ] || continue
        snippet="$(printf '%s' "$msg" | head -c 120)"

        # 6. Map rule_id → AP-id.
        lookup="$(_dispatch_map_lookup "$mapping" "$rule_id")"
        if [ -n "$lookup" ]; then
            IFS=$'\t' read -r ap_id severity category cwe_str <<< "$lookup"
            cwe_json="$(_dispatch_cwe_json "$cwe_str")"
        else
            ap_id="AP-XX-LINT-000"  # non-empty bucket id — see mapping note
            category="maintainability"
            severity="$(_dispatch_default_severity "$category")"
            cwe_json='[]'
        fi
        fix=""

        # 7. Emit through config + diff filters.
        _dispatch_config_filter_emit "$config_mode" \
            "$session_id" "$agent_id" "$ap_id" "mytool" "$rule_id" \
            "$category" "$severity" "$cwe_json" \
            "$file" "$line" "$line" "$msg" "$fix" "$snippet" \
            "$is_untracked" "$changed_ranges" "$findings_out"
    done <<< "$(printf '%s\n' "$raw" \
        | jq -r '.[] | [.rule_id, .message, (.line|tostring)] | @tsv' 2>/dev/null || true)"
}
```

### `_dispatch_config_filter_emit` argument order (line 261)

```
_dispatch_config_filter_emit  config_mode
  session_id  agent_id  ap_id  tool  tool_rule
  category  severity  cwe_json
  file  line  end_line  message  fix  snippet
  is_untracked  changed_ranges  findings_out
```
(17 args after `config_mode` = 18 total)

### `_dispatch_filter_emit` argument order (line 204)

Identical to the last 17 args of `_dispatch_config_filter_emit` (17 positional).

### Important: empty `ap_id` is fatal

The bucket fallback id **must** be non-empty (e.g. `AP-XX-LINT-000`). `_dispatch_map_lookup` returns the row as `IFS=$'\t' read -r ap_id severity category cwe_str`. A leading empty field in TSV collapses and `severity` lands in `ap_id` — findings silently report at the wrong severity (CHANGELOG line ~108).

### Function naming rule

The dispatcher calls the function as `"_dispatch_run_${tool//-/_}"` (line 778 fast, line 1349 medium). Hyphens in the tool name become underscores: `mytool-lint` → `_dispatch_run_mytool_lint`.

### 3c. Register file-extension routing

**Fast tier** — inside `_dispatch_tools_for_file` starting at line 698:
```bash
# Terraform → mytool (fast tier example)
case "$ext" in
    tf) tools="${tools} mytool" ;;
esac
```

**Medium tier** — inside `_dispatch_medium_tools_for_file` starting at line 1219 (existing cases at lines 1220-1265):
```bash
# Terraform → mytool (medium tier example)
case "$ext" in
    tf|tofu) tools="${tools} mytool" ;;
esac
```

Ensure deduplication guards (`case "$tools" in *mytool*) ;; *) tools="${tools} mytool" ;; esac`) are used when adding to an extension case that already appends another tool, following the Dockerfile/checkov pattern at line 1254-1265.

---

## 4. `lib/stop.sh` — Stop-gate (directory-scanning tools only)

Skip this step if the tool runs file-at-a-time in the dispatcher (step 3). Use this step only if the tool must scan a full directory at the end of the session (like Checkov's `--dir` mode).

**File**: `plugins/slop-guard/lib/stop.sh`

### 4a. Write `_stop_run_mytool` (model: `_stop_run_checkov` line 226)

```bash
# _stop_run_mytool <session_id> <agent_id> <project_dir> <changed_files>
_stop_run_mytool() {
    local session_id="$1" agent_id="$2" project_dir="$3" changed_files="$4"

    # 1. Filter: only run if relevant files were changed.
    local has_relevant=0
    local f
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        case "$f" in *.tf) has_relevant=1; break ;; esac
    done <<< "$changed_files"
    [ "$has_relevant" -eq 1 ] || return 0

    # 2. Respect config_source knob.
    if declare -F tool_config_mode >/dev/null 2>&1; then
        local _mode; _mode="$(tool_config_mode mytool "$project_dir")"
        [ "$_mode" = "skip" ] && return 0
    fi

    # 3. Resolve binary.
    local my_bin=""
    if declare -F resolve_tool >/dev/null 2>&1; then
        my_bin="$(resolve_tool mytool 2>/dev/null || true)"
    fi
    [ -n "$my_bin" ] || my_bin="$(command -v mytool 2>/dev/null || true)"
    if [ -z "$my_bin" ]; then
        printf 'slopguard: mytool unavailable; scan skipped (fail-open)\n' >&2
        return 0
    fi

    # 4. Find affected directories (reuse _stop_iac_dirs for IaC tools,
    #    or compute your own set from changed_files).
    local dirs; dirs="$(_stop_iac_dirs "$changed_files")"
    [ -n "$dirs" ] || return 0

    # 5. Config file (project-first fallback to baseline).
    local my_config=""
    for c in "${project_dir}/.mytool.yaml" \
              "${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT:-}}/configs/baseline/.mytool.yaml"; do
        [ -f "$c" ] && { my_config="$c"; break; }
    done

    # 6. Scan each directory, parse findings, call finding_add.
    local dir
    while IFS= read -r dir; do
        [ -z "$dir" ] && continue
        local abs_dir="$dir"
        [ "${abs_dir#/}" = "$abs_dir" ] && abs_dir="${project_dir}/${abs_dir}"
        [ -d "$abs_dir" ] || continue

        local raw=""
        raw="$("$my_bin" ${my_config:+--config "$my_config"} --json "$abs_dir" 2>/dev/null)" || true
        [ -z "$raw" ] && continue

        local checks_json
        checks_json="$(printf '%s' "$raw" | jq -c '.findings[]? // empty' 2>/dev/null || true)"
        [ -z "$checks_json" ] && continue

        while IFS= read -r chk; do
            [ -z "$chk" ] && continue
            local rule_id chk_file line_s
            rule_id="$(printf '%s' "$chk" | jq -r '.rule_id // empty' 2>/dev/null)"
            chk_file="$(printf '%s' "$chk" | jq -r '.file_path // empty' 2>/dev/null)"
            line_s="$(printf '%s' "$chk" | jq -r '(.line // 0) | tonumber | floor' 2>/dev/null || printf '0')"
            [ -z "$rule_id" ] && continue

            finding_add "$session_id" "$agent_id" \
                "AP-XX-SEC-001" "mytool" "$rule_id" "security" "error" '[]' \
                "${chk_file:-$abs_dir}" "$line_s" "$line_s" \
                "mytool ${rule_id}" "Review rule in mytool documentation" \
                "changed-lines" "${rule_id}|${chk_file}"
        done <<< "$checks_json"
    done <<< "$dirs"
}
```

### 4b. Call it from `stop_main` (line 628-630)

```bash
# current lines 628-630:
_stop_run_psalm    "$session_id" "${agent_id:-}" "$project_dir" "$changed_files"
_stop_run_checkov  "$session_id" "${agent_id:-}" "$project_dir" "$changed_files"
_stop_scan_secrets "$session_id" "${agent_id:-}" "$project_dir"

# ADD after _stop_run_checkov:
_stop_run_mytool   "$session_id" "${agent_id:-}" "$project_dir" "$changed_files"
```

### `_stop_iac_dirs` (line 63) — extension filter

The existing function matches `*.tf|*.hcl|*.yaml|*.yml|Dockerfile|*/Dockerfile`. If `mytool` targets a different extension not in this list, you need either a new custom dir-collector function or extend `_stop_iac_dirs`. Changing `_stop_iac_dirs` affects all other stop-gate tools; a dedicated function is safer.

---

## 5. `rules/mapping/mytool.yaml` — Create the mapping file

**File**: `plugins/slop-guard/rules/mapping/mytool.yaml` (create new).

### Schema

```yaml
---
# mytool rule → AP-id mapping.
# Each entry:
#   ap_id:    AP-XX-YYY-NNN   (MUST NOT be empty)
#   severity: blocker | error | warn | info
#   category: security | performance | maintainability | supply-chain
#   cwe:      CWE-NNN  (space-separated list, or empty string "")
rules:
  MY-RULE-001:
    ap_id: AP-TF-SEC-001
    severity: blocker
    category: security
    cwe: CWE-269
  MY-RULE-002:
    ap_id: AP-TF-MAINT-001
    severity: warn
    category: maintainability
    cwe: ""
```

### Parsing contract (`_dispatch_map_lookup`, line 82-109)

`_dispatch_map_lookup` uses `awk` to parse the YAML. Rules:
- Top-level `rules:` key is **ignored** — the awk parser reads only 2-space-indented rule-id keys and 4-space-indented field keys.
- Rule keys must be 2-space indented; field keys 4-space indented.
- A YAML comment (`#`) in a rule key or field value is treated as part of the value — put comments on their own lines.
- `IFS=$'\t' read -r ap_id severity category cwe_str` (line ~320 in every runner). **`ap_id` MUST NOT be empty** — an empty leading TSV field collapses and `severity` lands in `ap_id`.
- Use a bucket id (`AP-XX-LINT-000`) rather than an empty `ap_id` for unmapped rules you want to pass through.

### Existing bucket ids (for reference)

| Bucket id | Used by |
|---|---|
| `AP-PY-LINT-000` | ruff (unmapped rules) |
| `AP-IAC-SEC-000` | checkov (unmapped rules) |
| `AP-DOCKER-LINT-000` | hadolint (unmapped rules) |
| `AP-PHP-MAINT-000` | phpstan (unmapped rules) |
| `AP-CI-LINT-000` | zizmor / CI (unmapped rules) |

---

## 6. `lib/tools.sh` — Add config path + `_adopt_dest`

### 6a. `tool_config_path` (line 218 in lib/tools.sh)

Add a case for `mytool` inside the `case "$tool" in` block. **Pattern** — project config wins, baseline is fallback:

```bash
mytool)
    [ -n "$project_dir" ] && [ -f "${project_dir}/.mytool.yaml" ] \
        && { printf '%s' "${project_dir}/.mytool.yaml"; return; }
    printf '%s' "${CLAUDE_PLUGIN_ROOT}/configs/baseline/.mytool.yaml"
    ;;
```

If the tool accepts multiple candidate filenames (like ruff: `ruff.toml`, `.ruff.toml`, or `[tool.ruff]` in `pyproject.toml`), check each in order before falling through to the baseline.

**For no-config tools** (like `jq` or `shellcheck`): do **not** add a case — the `*)` catch-all at the end prints `none` (line ~298). `cmd_adopt_config` skips `none` tools in its listing (line ~609).

### 6b. `_adopt_dest` in `bin/slopguard` (line 558)

Add a case mapping the tool name to the primary project config destination path:

```bash
mytool) printf '%s/.mytool.yaml' "$_ad_dir" ;;
```

This controls where `slopguard adopt-config mytool` copies the baseline file. It must mirror the first candidate checked in `tool_config_path`.

### 6c. `configs/baseline/.mytool.yaml` (create new)

Create the baseline config file at `plugins/slop-guard/configs/baseline/.mytool.yaml`. This file is:
- Used when no project config is found (overlay mode — only security findings emitted).
- Copied verbatim by `slopguard adopt-config mytool` into the project root.
- The `configs/baseline/README.md` describes the directory's purpose.

**For descriptor-only tools** (tools that must run from the project's environment, like `pylint` or `mypy`):
- Do **not** add an entry to `tools.lock.json`.
- Do **not** add a case to `tool_config_path` (falls through to `none`).
- Create `configs/baseline/descriptors/mytool.yaml` following the schema in `configs/baseline/descriptors/pylint.yaml`:
  ```yaml
  name: mytool
  tier: fast
  match:
    globs: ["**/*.py"]
    stacks: ["python"]
  resolve:
    project: [".venv/bin/mytool", "venv/bin/mytool"]
  run:
    args: ["--output-format=json", "--exit-zero", "{file}"]
    timeout: 30
  parse:
    format: json
    jq: '.messages[] | {rule: .code, message: .message, line: .line}'
  ```
- Add a mapping file at `rules/mapping/mytool.yaml` as usual.
- `slopguard adopt-config mytool` will copy the descriptor to `.slopguard/tools/mytool.yaml` in the project (`_adopt_descriptor_template` in bin/slopguard line 593, `cmd_adopt_config` line 633-648).

---

## 7. Tests — Which files need new cases

### 7a. `tests/medium_test.sh` — routing assertion (add if medium tier)

Current routing assertions are at lines 125-151. After adding `mytool` to `_dispatch_medium_tools_for_file`, add:

```bash
_mt_tools_tf="$(_dispatch_medium_tools_for_file "main.tf")"
case "$_mt_tools_tf" in
    *mytool*) ok "medium: .tf routes to mytool" ;;
    *)        bad "medium: .tf mytool routing" "expected mytool, got: ${_mt_tools_tf}" ;;
esac
```

### 7b. `tests/stop_test.sh` — stop-gate wiring (add if stop gate)

Existing stub tests: psalm (line 358-388, test 9), checkov (line 390-421, test 10). Add a new numbered section:

```bash
# --------------------------------------------------------------------------- #
# N. mytool stub: finding added for a changed IaC file
# --------------------------------------------------------------------------- #

_st_mytool_repo="${_ST_WORK}/repo-mytool"
mkdir -p "${_st_mytool_repo}/vendor/bin"
git -C "$_st_mytool_repo" init -q ...
printf '# seed\n' > "${_st_mytool_repo}/infra/main.tf"
git -C "$_st_mytool_repo" add . && git -C "$_st_mytool_repo" commit -q -m "init"
printf '# changed\n' > "${_st_mytool_repo}/infra/main.tf"  # uncommitted change

cat > "${_st_mytool_repo}/vendor/bin/mytool" <<'STUBEOF'
#!/bin/sh
printf '{"findings":[{"rule_id":"MY-RULE-001","file_path":"infra/main.tf","line":1}]}\n'
STUBEOF
chmod +x "${_st_mytool_repo}/vendor/bin/mytool"

_st_setup_session "sess-mytool" "[]" 0
_st_run "advisory" "false" "$_st_mytool_repo" \
    "$(_st_payload_normal "sess-mytool" "$_st_mytool_repo")"

_st_mytool_ctx="$(printf '%s' "$_ST_STDOUT" | \
    jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)"
printf '%s' "$_st_mytool_ctx" | grep -qE "mytool|MY-RULE" \
    && ok  "stop-gate: mytool stub finding appears in report" \
    || bad "stop-gate: mytool stub finding not in report" "ctx=${_st_mytool_ctx}"
```

### 7c. `tests/adopt_test.sh` — config adoption (add if tool has a config file)

The existing test at line 32 asserts that `ruff` appears in the listing for a clean project. Add analogous assertions (appear in listing, absent when project config is present, baseline filename shown) after line 83.

### 7d. `tests/tools_test.sh` — installer and resolver

No new test needed for a standard binary tool. The existing generic tests cover install, hash mismatch, upgrade, and resolver precedence using a synthetic `fake-tool`. A new test is warranted only if:
- The tool requires an unusual post-install step (like `tflint --init`).
- The tool's `--version` output is so unusual that `tool_version_matches` needs a new case in `tool_version_output`.

---

## 8. Documentation — Files to update

### 8a. `CHANGELOG.md` (line 5 — `## Unreleased`)

Add a bullet under `## Unreleased` following the existing format:

```markdown
- **mytool integration** (YYYY-MM-DD)
  - `tools/tools.lock.json`: `mytool` pinned at v1.2.3 with sha256-verified assets for all four platforms.
  - `rules/stacks.json`: `terraform` stack gains `mytool` in its `tools` array.
  - `lib/dispatch.sh`: `_dispatch_run_mytool` (medium tier) — routes `.tf` files; JSON output parsed to rule_id/message/line; fallback ap_id `AP-XX-LINT-000`.
  - `rules/mapping/mytool.yaml`: 5 rules mapped to AP-ids; bucket id for unmapped rules.
  - `configs/baseline/.mytool.yaml`: baseline config (security-findings-only overlay default).
  - `THIRD_PARTY_NOTICES.md`: mytool entry added (MIT licence).
```

### 8b. `docs/decisions.md` (add a row D32+ for any non-obvious design choice)

Existing rows end at D31 (line ~63). Add only if there is a genuinely non-obvious decision — tool tier assignment, a non-standard config-path discovery scheme, or a deviation from the standard exit-code contract:

```markdown
| D32 | mytool tier assignment | **Medium tier.** mytool takes 15–30 s on real projects; this exceeds the fast-tier 8 s budget. | 2026-09-NN | Placed in dispatch_medium; stop gate not wired (file-at-a-time is sufficient). |
```

### 8c. `docs/slop-guard-spec.md` (root `docs/` directory)

The spec lives at `docs/slop-guard-spec.md` (not in `plugins/slop-guard/docs/`). Relevant sections to update:
- **§6** (tool configs / baseline) — mention the new baseline config file.
- **§9.1** (tool resolution and config source) — if a new config-discovery pattern is used.
- **§11.3** (Etap table) — mark which Etap delivered this tool.

### 8d. `THIRD_PARTY_NOTICES.md` (line ~70 — Run-Only Tools table)

Add a row to the table at the bottom of the `## Run-Only Tools` section:

```markdown
| mytool | MIT | https://github.com/example/mytool |
```

Note: if the licence is AGPL or commercial, add an explicit restriction note and seek human review before merging (per project Constraints).

### 8e. Root `README.md` (optional)

If the project's Slop Guard section has an explicit tool table or tier breakdown, add `mytool` there. The CHANGELOG note at line ~33 indicates the README Slop Guard section was extended with detection tiers — check that section for an appropriate insertion point.

---

## Quick Validation Sequence

After all steps:

```bash
# 1. JSON validity + all three stacks.json gates
make validate-slopguard

# 2. Shell syntax + shellcheck
bash -n plugins/slop-guard/lib/dispatch.sh
bash -n plugins/slop-guard/lib/stop.sh
bash -n plugins/slop-guard/lib/tools.sh
bash -n plugins/slop-guard/bin/slopguard
shellcheck -S warning plugins/slop-guard/lib/dispatch.sh plugins/slop-guard/lib/stop.sh \
    plugins/slop-guard/lib/tools.sh plugins/slop-guard/bin/slopguard

# 3. Run targeted tests
bash plugins/slop-guard/tests/tools_test.sh
bash plugins/slop-guard/tests/adopt_test.sh
bash plugins/slop-guard/tests/medium_test.sh
bash plugins/slop-guard/tests/stop_test.sh
```

---

## Summary Table

| # | File | Operation | Key symbol / line |
|---|---|---|---|
| 1 | `tools/tools.lock.json` | Add JSON object under `tools` | `"mytool": { version, bin, assets.{platform}.{url,sha256} }` |
| 2 | `rules/stacks.json` | Append tool name to `tools` array of target stack | e.g. `terraform.tools` |
| 3a | `lib/detect.sh` line 156 | (Only if core) Append to `SLOPGUARD_CORE_TOOLS` | `SLOPGUARD_CORE_TOOLS="… mytool"` |
| 3b | `lib/dispatch.sh` before line 1217 (medium) / line 695 (fast) | Add `_dispatch_run_mytool` function | 7-arg contract; `resolve_tool` → `tool_config_mode` → `timeout` → jq parse → `_dispatch_config_filter_emit` |
| 3c | `lib/dispatch.sh` `_dispatch_tools_for_file` line 698 or `_dispatch_medium_tools_for_file` line 1219 | Add extension routing case | `case "$ext" in tf) tools="${tools} mytool" ;;` |
| 4a | `lib/stop.sh` | (Stop-gate only) Add `_stop_run_mytool` function | `finding_add` per failing check |
| 4b | `lib/stop.sh` line 629 | (Stop-gate only) Call `_stop_run_mytool` in `stop_main` | After `_stop_run_checkov` |
| 5 | `rules/mapping/mytool.yaml` | Create mapping file | `rules: { RULE-ID: { ap_id, severity, category, cwe } }` |
| 6a | `lib/tools.sh` `tool_config_path` line 218 | Add config discovery case | project file → baseline fallback |
| 6b | `bin/slopguard` `_adopt_dest` line 558 | Add case | `mytool) printf '%s/.mytool.yaml' "$_ad_dir" ;;` |
| 6c | `configs/baseline/.mytool.yaml` | Create baseline config | Used in overlay mode |
| 7a | `tests/medium_test.sh` line ~151 | Add routing assertion | `_dispatch_medium_tools_for_file + case *mytool*` |
| 7b | `tests/stop_test.sh` line ~421 | (Stop-gate only) Add stub test | Stub binary + `grep -qE "mytool\|RULE"` |
| 7c | `tests/adopt_test.sh` line ~83 | Add listing / suppress assertions | `grep -q 'mytool'` |
| 8a | `CHANGELOG.md` line 5 | Add bullet under `## Unreleased` | — |
| 8b | `docs/decisions.md` | Add decision row (if warranted) | D32+ |
| 8c | `docs/slop-guard-spec.md` | Update §6, §9.1, §11.3 as needed | — |
| 8d | `THIRD_PARTY_NOTICES.md` line ~70 | Add row to Run-Only Tools table | Tool name, licence, URL |
| 8e | `README.md` | Update tool table if one exists | — |
