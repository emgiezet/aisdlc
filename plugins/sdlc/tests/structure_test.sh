#!/usr/bin/env bash
# structure_test.sh — structural checks for the portable SDLC skill migration.
#
# Proves:
#   1. All six canonical SKILL.md files exist with required frontmatter fields.
#   2. The obsolete commands/ directory is absent.
#   3. The portable plugin.json points at real resources (skills/ and hooks/hooks.json).
#   4. All four optional capabilities are documented in init/SKILL.md and templates/sdlc.md.
#   5. Fallback wording remains in implement/SKILL.md and qa/SKILL.md.
#
# Usage: bash plugins/sdlc/tests/structure_test.sh [PLUGIN_ROOT]
# Default PLUGIN_ROOT: directory two levels above this script.
#
# Exit 0 on all-pass; exit 1 on any failure.

set -euo pipefail

PLUGIN_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); printf '  ok  %s\n' "$*"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. Six canonical SKILL.md files — required frontmatter
# ---------------------------------------------------------------------------
printf '\n=== 1. Canonical SKILL.md files ===\n'

WORKFLOWS="init spec mockup implement qa ship"

for name in $WORKFLOWS; do
    skill_file="${PLUGIN_ROOT}/skills/${name}/SKILL.md"

    if [ ! -f "$skill_file" ]; then
        bad "${name}/SKILL.md — file does not exist"
        continue
    fi

    # Extract YAML frontmatter (between the first --- pair)
    frontmatter="$(awk '/^---$/{f=!f; next} f' "$skill_file" | head -30)"

    # name field
    if printf '%s\n' "$frontmatter" | grep -qE '^name: '; then
        ok "${name}/SKILL.md — name present"
    else
        bad "${name}/SKILL.md — name field missing from frontmatter"
    fi

    # description field (may be multi-line >)
    if printf '%s\n' "$frontmatter" | grep -qE '^description:'; then
        ok "${name}/SKILL.md — description present"
    else
        bad "${name}/SKILL.md — description field missing from frontmatter"
    fi

    # allowed-tools field (preserved from Claude command files)
    if printf '%s\n' "$frontmatter" | grep -qE '^allowed-tools:'; then
        ok "${name}/SKILL.md — allowed-tools present"
    else
        bad "${name}/SKILL.md — allowed-tools field missing from frontmatter"
    fi

    # No literal $ARGUMENTS — must use host-neutral invocation-input wording
    if grep -q '\$ARGUMENTS' "$skill_file"; then
        bad "${name}/SKILL.md — contains Claude-only \$ARGUMENTS; must use invocation-input wording"
    else
        ok "${name}/SKILL.md — no \$ARGUMENTS (host-neutral)"
    fi
done

# ---------------------------------------------------------------------------
# 2. Obsolete commands/ directory is absent
# ---------------------------------------------------------------------------
printf '\n=== 2. Obsolete commands/ directory ===\n'

commands_dir="${PLUGIN_ROOT}/commands"
if [ -e "$commands_dir" ]; then
    bad "commands/ directory still exists at ${commands_dir}"
else
    ok "commands/ directory is absent"
fi

# Confirm no residual *.md files under any commands path
leftover="$(find "${PLUGIN_ROOT}" -path '*/commands/*.md' 2>/dev/null || true)"
if [ -n "$leftover" ]; then
    bad "Residual command files found: ${leftover}"
else
    ok "No residual command/*.md files"
fi

# ---------------------------------------------------------------------------
# 3. Portable plugin.json points at real resources
# ---------------------------------------------------------------------------
printf '\n=== 3. Portable plugin.json ===\n'

portable="${PLUGIN_ROOT}/plugin.json"
if [ ! -f "$portable" ]; then
    bad "plugin.json not found at ${portable}"
else
    ok "plugin.json exists"

    # JSON must parse
    if command -v jq >/dev/null 2>&1; then
        if jq . "$portable" >/dev/null 2>&1; then
            ok "plugin.json — valid JSON"
        else
            bad "plugin.json — invalid JSON"
        fi

        # Required fields
        for field in name version description; do
            val="$(jq -r ".${field} // empty" "$portable")"
            if [ -n "$val" ]; then
                ok "plugin.json — .${field} present: ${val}"
            else
                bad "plugin.json — .${field} missing or empty"
            fi
        done

        # skills path must point to an existing directory
        skills_path="$(jq -r '.skills // empty' "$portable")"
        if [ -n "$skills_path" ]; then
            # Resolve relative to plugin root (strip leading ./)
            resolved="${PLUGIN_ROOT}/${skills_path#./}"
            # Strip trailing slash for directory check
            resolved="${resolved%/}"
            if [ -d "$resolved" ]; then
                ok "plugin.json — .skills points to existing directory: ${resolved}"
            else
                bad "plugin.json — .skills=${skills_path} does not resolve to a directory"
            fi
        else
            bad "plugin.json — .skills field missing"
        fi

        # OpenAI extension hooks path must point to existing file
        hooks_path="$(jq -r '.extensions["com.openai"].hooks // empty' "$portable")"
        if [ -n "$hooks_path" ]; then
            resolved="${PLUGIN_ROOT}/${hooks_path#./}"
            if [ -f "$resolved" ]; then
                ok "plugin.json — extensions.com.openai.hooks points to existing file: ${resolved}"
            else
                bad "plugin.json — extensions.com.openai.hooks=${hooks_path} does not resolve to a file"
            fi
        else
            bad "plugin.json — extensions.com.openai.hooks missing"
        fi
    else
        bad "jq not found — cannot validate plugin.json fields; install jq"
    fi
fi

# ---------------------------------------------------------------------------
# 4. All four optional capabilities in init/SKILL.md and templates/sdlc.md
# ---------------------------------------------------------------------------
printf '\n=== 4. Optional capabilities documented ===\n'

CAPABILITIES="slop-guard superpowers ponytail headroom"

init_skill="${PLUGIN_ROOT}/skills/init/SKILL.md"
sdlc_template="${PLUGIN_ROOT}/templates/sdlc.md"

for cap in $CAPABILITIES; do
    # Normalise: match case-insensitively (slop-guard | Slop Guard | Slop guard)
    pattern="$(printf '%s' "$cap" | sed 's/-/ /g')"

    if grep -qiE "(${cap}|${pattern})" "$init_skill" 2>/dev/null; then
        ok "init/SKILL.md — '${cap}' present"
    else
        bad "init/SKILL.md — '${cap}' not found"
    fi

    if grep -qiE "(${cap}|${pattern})" "$sdlc_template" 2>/dev/null; then
        ok "templates/sdlc.md — '${cap}' present"
    else
        bad "templates/sdlc.md — '${cap}' not found"
    fi
done

# Headroom must NOT be described as an in-process invocation.
# Lines saying "never invoked" or "not invoked" are correct; filter those out first.
for file in "$init_skill" "$sdlc_template"; do
    label="$(basename "$(dirname "$file")")/$(basename "$file")"
    # Select lines containing "headroom" + an invocation word, then strip lines that also
    # contain a negation qualifier ("never", "not ", "external", "transport", "absent").
    # Any surviving lines are a genuine mis-statement.
    bad_lines="$(grep -iE 'headroom' "$file" 2>/dev/null \
        | grep -iE '(invoke|load|call|dispatch)' \
        | grep -viE '(never |not |external|transport|absent)' || true)"
    if [ -n "$bad_lines" ]; then
        bad "${label} — Headroom described as in-process invocation; must be external transport only"
    else
        ok "${label} — Headroom not described as in-process (correct)"
    fi
done

# ---------------------------------------------------------------------------
# 5. Fallback wording remains in implement and qa
# ---------------------------------------------------------------------------
printf '\n=== 5. AISDLC fallback wording ===\n'

implement_skill="${PLUGIN_ROOT}/skills/implement/SKILL.md"
qa_skill="${PLUGIN_ROOT}/skills/qa/SKILL.md"

# implement must have fallback for Superpowers / Ponytail
if grep -qiE 'fallback.*(superpowers|ponytail)|aisdlc fallback' "$implement_skill" 2>/dev/null; then
    ok "implement/SKILL.md — fallback wording present"
else
    bad "implement/SKILL.md — fallback wording missing for optional capabilities"
fi

# implement must conditionally reference Ponytail (not unconditionally)
if grep -qiE 'if ponytail|ponytail.*available|ponytail.*recorded' "$implement_skill" 2>/dev/null; then
    ok "implement/SKILL.md — Ponytail integration is conditional"
else
    bad "implement/SKILL.md — Ponytail integration wording is not conditional"
fi

# qa must have fallback wording
if grep -qiE 'fallback.*(absent|unknown)|aisdlc fallback' "$qa_skill" 2>/dev/null; then
    ok "qa/SKILL.md — fallback wording present"
else
    bad "qa/SKILL.md — fallback wording missing for optional capabilities"
fi

# qa must note security boundary
if grep -qiE '(not verified|security|boundary)' "$qa_skill" 2>/dev/null; then
    ok "qa/SKILL.md — security boundary / not-verified language present"
else
    bad "qa/SKILL.md — no security boundary or Not verified section wording"
fi

# Slop Guard integration must be conditional, not unconditional, in implement and qa
for skill_file in "$implement_skill" "$qa_skill"; do
    label="skills/$(basename "$(dirname "$skill_file")")/SKILL.md"
    if grep -qiE 'if slop.guard.*available|slop.guard.*recorded' "$skill_file" 2>/dev/null; then
        ok "${label} — Slop Guard integration is conditional"
    else
        bad "${label} — Slop Guard integration wording is not conditional"
    fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results ===\n'
printf 'passed: %d   failed: %d\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
