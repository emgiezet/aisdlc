---
ticket: GH-41
title: "ship: add a Change map (mermaid + before/after UC table) to the PR body"
status: draft
stacks: [instructions]
---

# GH-41 — ship: add a Change map (mermaid + before/after UC table) to the PR body

Source: https://github.com/emgiezet/aisdlc/issues/41

## Problem

The PR body `ship` writes is prose: verdict, scope, then a file tour. When agents produce
many PRs, reviewers stop reading long descriptions. There is no visual summary that lets a
human verify the shape of a change in seconds, as described in *Fighting Code Slop: The State
of Software Factories* (Dex Horthy). An agent-generated Change map — a mermaid flowchart of
touched modules and a before/after UC table — would give reviewers a scannable confirmation
that the change matches the spec before they read a line of code.

## Scope

In:
- `plugins/sdlc/commands/ship.md` Phase 2 body template: add `### Change map` section with
  mermaid flowchart instructions (≤12 nodes, out-of-scope warning style, omission rule for
  docs-only diffs) and a before/after UC table; include a valid rendered mermaid example.
- `README.md` catalog table row for `/sdlc:ship`: update the description to mention the
  visual Change map in the PR body.

Out:
- `plugins/sdlc/bin/aisdlc` — no changes to the queue runner or `pr-body.md` file handling.
- `plugins/sdlc/agents/auto-qa.md` — screenshot attachment stays unchanged.
- `plugins/sdlc/commands/review.md` — review command reads the PR but does not generate it.
- `plugins/sdlc/commands/fix-pr.md` — out of scope.
- Any template or fixture under `evals/` — the eval sandbox must not be touched.
- New helper scripts or code — this is a pure instruction-file change.

Change budget: 80 added lines, 2 files, 2 modules

## Context

- `plugins/sdlc/commands/ship.md` — `## Phase 2: Open the PR`, step 2 "Compose the body"
  and the markdown body template block; the `### Change map` section appends after
  `### Not covered`. The `--docs` omission rule mirrors the `--docs` diff-check constraint
  defined in `## Phase 1: Preflight`.
- `README.md` — catalog table under `### 🤖 Queueable commands`, row `/sdlc:ship <T> [--docs]`.
- `plugins/sdlc/agents/auto-qa.md` — `## Screenshots` section establishes that visual
  evidence is UI-only; the mermaid diagram is distinct (spec+diff derived, not a screenshot).

## Acceptance criteria

| id   | actor          | action                                                                                                       | expected observable result                                                                                                                                                                                                                                          | test        |
|------|----------------|--------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|
| UC-1 | ship agent     | generates PR body for a branch whose diff contains at least one non-doc file                                 | the PR body and `pr-body.md` contain a `### Change map` section; the section includes (a) a fenced mermaid flowchart whose nodes are modules touched by the diff, with edges derived from call/data relationships in the spec's `## Context`, and (b) a before/after table with columns UC id \| Before \| After populated from the spec's `## Acceptance criteria` rows | integration |
| UC-2 | ship agent     | builds the Change-map mermaid graph and a touched module is absent from the spec's `In:` scope               | that node in the generated mermaid block carries a distinct warning style declaration (e.g., `style NodeName fill:#ffa,stroke:#f90`); in-scope nodes carry no such style                                                                                             | integration |
| UC-3 | ship agent     | every path in `git diff --name-only <base>..HEAD` matches `*.md`, `docs/**`, `specs/**`, or `CHANGELOG*`    | the generated PR body / `pr-body.md` contains no `### Change map` section, no mermaid block, and no before/after UC table                                                                                                                                           | integration |
| UC-4 | implementer    | adds Change map instructions to `ship.md`                                                                    | `ship.md` contains at least one fenced ` ```mermaid ``` ` block that is syntactically valid (parseable by GitHub's mermaid renderer); the block illustrates the node-and-edge format the surrounding instructions describe, with ≥2 nodes and ≥1 edge               | integration |
| UC-5 | ship agent     | the diff touches more than 12 distinct modules                                                               | the generated mermaid flowchart contains at most 12 nodes; the instruction in `ship.md` states the cap and a selection or aggregation strategy for when the count exceeds it                                                                                         | integration |
| UC-6 | README reader  | scans the catalog table row for `/sdlc:ship`                                                                 | the "What it does" cell describes a visual Change map (mermaid diagram + before/after UC table) in the PR body, not only the existing prose summary                                                                                                                  | integration |

## Non-functional

- The mermaid flowchart is generated from the spec's `## Context` file references and the diff
  together — consistent with the existing Phase 2 instruction "Compose the body from the spec
  and the QA report — never from the diff alone."
- The `### Change map` section is the last section of the PR body, after `### Not covered`.
- `CI= make validate` must pass; this is verified by the implementer, not a standalone UC.

## Open questions

- [ ] **Node selection strategy when >12 modules are touched** (UC-5): the issue caps at 12
  nodes but does not specify how to select or aggregate when the diff touches more — by
  relevance to spec `In:` scope, by call-graph degree, by collapsed grouping (e.g., one node
  per top-level directory), or another rule. Must be resolved before `status: approved`.
