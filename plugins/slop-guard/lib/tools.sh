#!/usr/bin/env bash
# lib/tools.sh — tool resolution and installation for slop-guard.
#
# Sources (§9.1, tool_source=project-first):
#   1. Project binary: vendor/bin, node_modules/.bin, .venv/bin, go tool
#   2. Plugin binary:  ${CLAUDE_PLUGIN_DATA}/tools/<name>/current/<name>
#   3. PATH binary — only when --version contains the lockfile version string
#
# Requires: jq (or a compatible implementation), sha256sum or shasum.
# No flock: file locking uses mkdir (POSIX, macOS-safe per D1).

# --------------------------------------------------------------------------- #
# sha256 helper
# --------------------------------------------------------------------------- #

_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        printf 'slopguard: sha256sum or shasum is required\n' >&2
        return 1
    fi
}

# --------------------------------------------------------------------------- #
# platform detection
# --------------------------------------------------------------------------- #

# detect_platform — prints one of: linux-amd64 linux-arm64 darwin-arm64 darwin-amd64
detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "${os}-${arch}" in
        Linux-x86_64)  printf 'linux-amd64' ;;
        Linux-aarch64) printf 'linux-arm64' ;;
        Darwin-arm64)  printf 'darwin-arm64' ;;
        Darwin-x86_64) printf 'darwin-amd64' ;;
        *)
            printf 'slopguard: unsupported platform %s-%s\n' "$os" "$arch" >&2
            return 1
            ;;
    esac
}

# --------------------------------------------------------------------------- #
# lockfile accessors — all read ${TOOLS_LOCK} at call time so tests can override it
# --------------------------------------------------------------------------- #

_tools_lock() {
    printf '%s' "${TOOLS_LOCK:-${CLAUDE_PLUGIN_ROOT}/tools/tools.lock.json}"
}

# lock_field <tool> <platform> <field>  — prints the value or nothing
lock_field() {
    local tool="$1" platform="$2" field="$3"
    jq -r --arg t "$tool" --arg p "$platform" --arg f "$field" \
        '.tools[$t].assets[$p][$f] // empty' "$(_tools_lock)" 2>/dev/null
}

# lock_version <tool>  — prints the version string or nothing
lock_version() {
    local tool="$1"
    jq -r --arg t "$tool" '.tools[$t].version // empty' "$(_tools_lock)" 2>/dev/null
}

# lock_bin <tool>  — prints the binary name (defaults to tool name)
lock_bin() {
    local tool="$1"
    jq -r --arg t "$tool" '.tools[$t].bin // $t' "$(_tools_lock)" 2>/dev/null
}

# lock_tools  — prints every tool name, one per line
lock_tools() {
    jq -r '.tools | keys[]' "$(_tools_lock)" 2>/dev/null
}

# --------------------------------------------------------------------------- #
# tool_version_matches
# --------------------------------------------------------------------------- #

# tool_version_matches <name> <binary_path>
# Returns 0 when the binary's --version output contains the lockfile version.
tool_version_matches() {
    local name="$1" binary="$2"
    local expected; expected="$(lock_version "$name")"
    [ -n "$expected" ] || return 1
    local actual; actual="$("$binary" --version 2>&1 || true)"
    printf '%s\n' "$actual" | grep -qF "$expected"
}

# --------------------------------------------------------------------------- #
# resolve_tool
# --------------------------------------------------------------------------- #

# resolve_tool <name>
# Prints an absolute path or nothing. Reads CLAUDE_PLUGIN_OPTION_TOOL_SOURCE
# (project-first | plugin-only | project-only); defaults to project-first.
resolve_tool() {
    local name="$1"
    local source="${CLAUDE_PLUGIN_OPTION_TOOL_SOURCE:-project-first}"
    local found=""

    # 1. Project binary (skipped in plugin-only mode).
    if [ "$source" != "plugin-only" ]; then
        local project_dir="${CLAUDE_PROJECT_DIR:-}"
        if [ -n "$project_dir" ]; then
            local candidate
            for candidate in \
                "${project_dir}/vendor/bin/${name}" \
                "${project_dir}/node_modules/.bin/${name}" \
                "${project_dir}/.venv/bin/${name}"
            do
                if [ -x "$candidate" ]; then
                    found="$candidate"
                    break
                fi
            done
        fi
        # go tool (only if go is present and name is a known tool directive).
        if [ -z "$found" ] && command -v go >/dev/null 2>&1; then
            local go_path
            go_path="$(go tool "$name" 2>/dev/null)" || true
            if [ -n "$go_path" ] && [ -x "$go_path" ]; then
                found="$go_path"
            fi
        fi
    fi

    # 2. Plugin binary (skipped in project-only mode).
    if [ -z "$found" ] && [ "$source" != "project-only" ]; then
        local bin_name; bin_name="$(lock_bin "$name")"
        local plugin_current="${CLAUDE_PLUGIN_DATA}/tools/${name}/current"
        if [ -x "${plugin_current}/${bin_name}" ]; then
            found="${plugin_current}/${bin_name}"
        fi
    fi

    # 3. PATH binary — only when version matches the lockfile (§9.1).
    if [ -z "$found" ] && [ "$source" = "project-first" ]; then
        if command -v "$name" >/dev/null 2>&1; then
            local path_bin; path_bin="$(command -v "$name")"
            if tool_version_matches "$name" "$path_bin"; then
                found="$path_bin"
            fi
        fi
    fi

    printf '%s' "$found"
}

# --------------------------------------------------------------------------- #
# install_tool
# --------------------------------------------------------------------------- #

# install_tool <name>
# Download → verify sha256 → extract into version directory → atomic current swap.
# On hash mismatch: remove the download, remove any partial version dir, exit non-zero.
# Never writes under ${CLAUDE_PLUGIN_ROOT} (replaced on plugin update, §3.1).
install_tool() {
    local name="$1"
    local platform; platform="$(detect_platform)" || return 1

    local version;        version="$(lock_version "$name")"
    local url;            url="$(lock_field "$name" "$platform" url)"
    local expected_hash;  expected_hash="$(lock_field "$name" "$platform" sha256)"
    local bin_name;       bin_name="$(lock_bin "$name")"

    [ -n "$url" ]           || { printf 'slopguard: no asset for %s on %s\n' "$name" "$platform" >&2; return 1; }
    [ -n "$expected_hash" ] || { printf 'slopguard: no sha256 for %s on %s\n' "$name" "$platform" >&2; return 1; }
    [ -n "$version" ]       || { printf 'slopguard: no version for %s\n' "$name" >&2; return 1; }

    local tools_base="${CLAUDE_PLUGIN_DATA}/tools/${name}"
    local version_dir="${tools_base}/${version}"
    local current_link="${tools_base}/current"

    # Temp dir for the download — removed by us before returning, no trap needed.
    local download_dir; download_dir="$(mktemp -d)"
    local asset_file="${download_dir}/asset"

    # Download.
    printf 'slopguard: downloading %s %s...\n' "$name" "$version" >&2
    if ! curl -sSL --fail -o "$asset_file" "$url"; then
        printf 'slopguard: download failed: %s\n' "$url" >&2
        rm -rf "$download_dir"
        return 1
    fi

    # Verify sha256.
    local actual_hash; actual_hash="$(_sha256 "$asset_file")"
    if [ "$actual_hash" != "$expected_hash" ]; then
        printf 'slopguard: sha256 mismatch for %s\n' "$name" >&2
        printf '  expected: %s\n' "$expected_hash" >&2
        printf '  actual:   %s\n' "$actual_hash" >&2
        rm -f "$asset_file"
        rm -rf "$download_dir"
        return 1
    fi

    # Extract or copy into the version directory.
    mkdir -p "$version_dir"
    local asset_name; asset_name="$(basename "$url")"
    case "$asset_name" in
        *.tar.gz|*.tgz)
            if ! tar -xzf "$asset_file" --strip-components=1 -C "$version_dir"; then
                printf 'slopguard: extraction failed for %s\n' "$name" >&2
                rm -rf "$version_dir" "$download_dir"
                return 1
            fi
            ;;
        *.tar.xz)
            if ! tar -xJf "$asset_file" --strip-components=1 -C "$version_dir"; then
                printf 'slopguard: extraction failed for %s\n' "$name" >&2
                rm -rf "$version_dir" "$download_dir"
                return 1
            fi
            ;;
        *.zip)
            if ! unzip -q "$asset_file" -d "$version_dir"; then
                printf 'slopguard: extraction failed for %s\n' "$name" >&2
                rm -rf "$version_dir" "$download_dir"
                return 1
            fi
            ;;
        *)
            # Raw binary (e.g. jq-linux-amd64 with no extension).
            cp "$asset_file" "${version_dir}/${bin_name}"
            chmod +x "${version_dir}/${bin_name}"
            ;;
    esac

    rm -rf "$download_dir"

    # Confirm the binary is in place.
    if [ ! -x "${version_dir}/${bin_name}" ]; then
        printf 'slopguard: binary not found after install: %s/%s\n' "$version_dir" "$bin_name" >&2
        rm -rf "$version_dir"
        return 1
    fi

    # Atomic symlink swap of current.
    local new_link="${tools_base}/current.new.$$"
    ln -sf "$version_dir" "$new_link"
    mv -f "$new_link" "$current_link"

    printf 'slopguard: installed %s %s at %s\n' "$name" "$version" "$version_dir" >&2
    return 0
}
