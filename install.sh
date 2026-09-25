#!/usr/bin/env bash
# install.sh — prints installation instructions for Claude Code, Codex, Grok, and omp.
# It changes nothing on its own: plugin installation happens inside each host.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

for tool in git jq flock; do
    command -v "$tool" >/dev/null 2>&1 || echo "warning: $tool is missing — the queue runner needs it" >&2
done
command -v claude >/dev/null 2>&1 || echo "warning: the claude CLI is missing — aisdlc run requires it" >&2
command -v gh >/dev/null 2>&1 || echo "note: gh is absent — ship will write the PR body to a file instead" >&2

cat <<EOF

git, jq, flock: needed by the queue runner (aisdlc run).
claude CLI: needed only by the queue runner — the interactive commands work on all four hosts.

--- Claude Code ---

Register the marketplace and install the plugin:

  /plugin marketplace add $HERE
  /plugin install sdlc@aisdlc

Then set up a repository:

  /sdlc:init

--- Codex ---

Register this checkout as a marketplace source:

  codex plugin marketplace add $HERE

Then open the Plugins Directory, select the aisdlc marketplace, and install sdlc.

To set up a repository, start a Codex session in the repo and run:

  \$init

--- Grok ---

Add this checkout as a marketplace source in ~/.grok/config.toml:

  [[marketplace.sources]]
  type = "local"
  path = "$HERE"

Then open the Marketplace tab in the Grok TUI (/plugins), browse aisdlc, and select sdlc.

To set up a repository, start a Grok session in the repo and run:

  /init

--- omp ---

Register this checkout as a marketplace source:

  omp plugin marketplace add $HERE

Then install the plugin:

  omp plugin install sdlc@aisdlc

To set up a repository, start an omp session in the repo and run:

  /sdlc:init

--- Updating ---

Is anything to update?

  aisdlc version --check   compares the installed version with the one published on GitHub

The harness itself, per host:

  Claude Code  /plugin update sdlc@aisdlc
  Codex        codex plugin marketplace upgrade   (git source; for this checkout: git -C $HERE pull)
  Grok         git -C $HERE pull, then reinstall from /plugins
  omp          omp plugin upgrade sdlc@aisdlc
  skills       npx skills update

No host updates what /sdlc:init generated inside a repository. In each repo that ran it:

  /sdlc:update           re-syncs descriptor operations, profile fields and runner config keys
  /sdlc:update --check   reports what would change, writes nothing

--- Queue runner (requires the claude CLI) ---

Put the queue runner on your PATH:

  ln -s $HERE/plugins/sdlc/bin/aisdlc ~/.local/bin/aisdlc

aisdlc run starts headless claude -p sessions. It does not work with Codex, Grok, or omp.

To try it without touching a real repository:

  make sandbox

Credentials: aisdlc run uses whatever authenticates your claude CLI. Options:

  CLAUDE_CODE_OAUTH_TOKEN                   Pro/Max subscription (claude setup-token)
  ANTHROPIC_API_KEY                         Anthropic Console, billed per token
  CLAUDE_CODE_USE_BEDROCK=1                 AWS Bedrock (or Vertex / Foundry equivalents)
  ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN LLM gateway

If ANTHROPIC_API_KEY is set it wins over a subscription token and forces Console billing.

EOF
