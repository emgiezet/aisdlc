#!/usr/bin/env bash
# install.sh — prints installation instructions for Claude Code, Codex, and Grok.
# It changes nothing on its own: plugin installation happens inside each host.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

for tool in git jq flock; do
    command -v "$tool" >/dev/null 2>&1 || echo "warning: $tool is missing — the queue runner needs it" >&2
done
command -v claude >/dev/null 2>&1 || echo "warning: the claude CLI is missing — aisdlc run requires it" >&2
command -v gh >/dev/null 2>&1 || echo "note: gh is absent — ship will write the PR body to a file instead" >&2

cat <<EOF

Clone (if you have not already):

  git clone git@github.com:emgiezet/aisdlc.git ~/.local/share/aisdlc

--- Claude Code ---

Run these in Claude Code:

  /plugin marketplace add $HERE
  /plugin install sdlc@aisdlc

--- Codex ---

Register this checkout as a marketplace source:

  codex plugin marketplace add $HERE

Then open the Plugins Directory in the Codex UI, choose the aisdlc marketplace,
and install the sdlc plugin from there.

--- Grok ---

Add this checkout as a marketplace source in ~/.grok/config.toml:

  [[marketplace.sources]]
  type = "local"
  path = "$HERE"

Then open the Marketplace tab in the Grok TUI (/plugins), browse the aisdlc
marketplace, and select sdlc.

--- Queue runner (requires the claude CLI) ---

Put the queue runner on your PATH:

  ln -s $HERE/plugins/sdlc/bin/aisdlc ~/.local/bin/aisdlc

aisdlc run starts headless claude -p sessions. It does not work with Codex or Grok.

--- Set up a repository ---

After installing the plugin on your chosen host, start an interactive session
inside the repository you want to use and run:

  /sdlc:init

To try it without touching a real repository:

  make sandbox

EOF
