#!/usr/bin/env bash
# install.sh — prints the steps to register this checkout as a Claude Code plugin marketplace.
# It changes nothing on its own: plugin installation happens inside Claude Code.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

for tool in git jq flock; do
    command -v "$tool" >/dev/null 2>&1 || echo "warning: $tool is missing — the queue runner needs it" >&2
done
command -v claude >/dev/null 2>&1 || echo "warning: the claude CLI is missing — the pipeline needs it" >&2
command -v gh >/dev/null 2>&1 || echo "note: gh is absent — ship will write the PR body to a file instead" >&2

cat <<EOF

Run these in Claude Code:

  /plugin marketplace add $HERE
  /plugin install sdlc@aisdlc

Put the queue runner on your PATH:

  ln -s $HERE/plugins/sdlc/bin/aisdlc ~/.local/bin/aisdlc

Then, inside a repository you want to use this on:

  /sdlc:init

To try it without touching a real repository:

  make sandbox

EOF
