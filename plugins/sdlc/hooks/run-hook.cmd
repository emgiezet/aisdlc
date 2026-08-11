#!/usr/bin/env bash
# Hook runner — executes named hook script from hooks/ directory.
# Extra arguments are forwarded: run-hook.cmd guard pre-bash → hooks/guard pre-bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$1"
shift
exec "$SCRIPT_DIR/$HOOK" "$@"
