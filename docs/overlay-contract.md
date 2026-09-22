# The overlay contract

This harness is deliberately empty of any organisation's vocabulary: no company rules, no stack
conventions, no regulatory ids. An organisation that needs those installs a **second plugin beside
this one** — a policy overlay — rather than forking this repository and editing its text.

This file states what the overlay may rely on, and what this repository has to grow so that a
downstream layer is a configuration exercise rather than a rewrite.

## Why not a fork

A private fork of this harness exists and has been running in production. Two things it taught:

- **A fork drifts and then cannot merge back.** Its history has no merge base with this one, so
  every fix moved by hand. Six months of generic improvements — a five-phase queue, a real issue
  queue, portable guards, a multi-runtime installer — ended up trapped on the private side.
- **The generic files were never generic.** Every command, agent and playbook carried the fork's
  command namespace and its rule ids inline. Nothing prevented that, because nothing in this
  repository ever asked where those values come from.

The overlay model fixes both: one authoritative copy of the harness, and a downstream layer that
supplies vocabulary through configuration.

## What this repository must parameterise

Today these are literals in the text. Each one has to come from the plugin manifest or the project
profile before an overlay can exist:

| Value | Where it is hardcoded today | Should come from |
|---|---|---|
| Plugin id and command namespace (`/sdlc:*`) | every command, playbook and doc | the plugin manifest |
| Rule ids quoted in commands and agents | agent and command prose | the policy layer, or nothing |
| Policy directories | not present here yet | the profile |
| Artefact directories (`specs/`, and an intent home) | commands, runner | the profile |
| Verification commands | already in `.claude/sdlc.md` | keep as is; this one is right |

The test for each: **could a second organisation install this plugin unmodified and get a working
pipeline in its own vocabulary?** Where the answer is no, the value is a hole to close.

## What an overlay owns

- Its own rule files, in whatever tiers it needs, and the tooling that materialises them into a
  consumer repository.
- Its own router entries, docs and manifests.
- Nothing else. An overlay that carries a copy of a command from here is a fork again.

## How the two compose

Two plugins installed side by side, from two marketplaces. Rejected alternatives, each for a
concrete reason measured against four runtimes (Claude Code, Codex, Grok, OMP):

- **Plugin dependency** — supported by one runtime's marketplace semantics, not the others. An
  overlay installed alone would yield a policy layer and no pipeline on three of four.
- **Submodule** — marketplaces clone or copy the marketplace root without initialising submodules,
  so the plugin's files are silently absent.
- **Subtree** — works at runtime and vendors this repository into the overlay, which recreates the
  fork this model exists to end.

Consequence for anyone installing only this repository: the pipeline works, there is no policy
layer, and no rule ids are enforced. That is the intended shape, and the installer should say so
rather than implying a policy tier exists.

## Generic work still to land here

Measured against the private fork, these are improvements with no organisation-specific content,
and they belong in this repository:

1. A file-scope check after the verification phase, diffing the branch against the scope the task
   declared.
2. A separate security pass as its own queue phase, reading a report rather than an exit code
   (the review pass landed with SDLC-005/006; security is still folded into it).
3. Portable mechanical guards, each driven by a project configuration file rather than by
   hardcoded paths.
4. An installer that registers this checkout with every agent runtime on `PATH`, with `--check`
   and `--dry-run` modes.
5. The artefact chain ahead of the spec as *committed, human-approved* documents: the discovery
   commands (SDLC-008) write briefs; an approved implementation plan between spec and implement
   does not exist yet.

Landed: the `review` queue phase and `num_turns == 0` as failure (SDLC-005); `invoke_claude`
reading from `/dev/null`; the issue queue with an atomic claim (`aisdlc add --issue`, SDLC-005);
tracker and browser descriptors as the parameterisation this document asked for — a second
organisation installs the plugin unmodified and points `.claude/sdlc.md` at its own descriptor.

Each is a separate change with its own tests. None requires the overlay to exist first.
