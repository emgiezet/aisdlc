---
ticket: GH-71
title: Auto-detect the queued AI SDLC runtime
status: draft
stacks: [bash, instructions]
---

# GH-71 — Auto-detect the queued AI SDLC runtime

## Problem

Operators with omp already installed still need to configure the queue runner before it will use omp. The default assumes Claude Code even on machines without it, and the runtime choice must stay stable once the operator queues a task.

## Scope

In:
- Default runtime selection at `aisdlc add`, explicit configuration precedence, queue output, and compatibility with already queued tasks.
- Runtime and spend-cap guidance in CLI help and the setup and operator docs.

Out:
- Support for Codex or another queue runtime (see #69), a dedicated CI stage (see #70), new billing enforcement, or changes to task phases.

Change budget: 160 added lines, 12 files, 6 modules

## Context

- [PR #71](https://github.com/emgiezet/aisdlc/pull/71) — runtime priority and backward compatibility.
- `plugins/sdlc/bin/aisdlc` — `cmd_add`, `resolve_default`, `check_runtime`, and the worker's persisted runtime.
- `evals/harness/selftest.sh` — offline exercising of the real runner with controlled `PATH` and runtime subprocesses.
- `docs/ai-sdlc.md`, `README.md`, `plugins/sdlc/commands/init.md`, `plugins/sdlc/commands/update.md` — operator and config-generation contract.

## Acceptance criteria

| id | actor | action | expected observable result | test |
|---|---|---|---|---|
| UC-1 | operator | add a task with both runtimes installed and no override | The task stores `omp` and the queued line says `on omp (auto-detected)` without claiming a hard spend cap. | integration |
| UC-2 | operator | add a task in auto mode with only Claude Code installed | The task stores `claude`. | integration |
| UC-3 | operator | add a task with conflicting flag, config, and environment values | The selected runtime comes from `--runtime`, then config, then `AISDLC_RUNTIME`, then the built-in default. An explicit `auto` at any of those sources resolves the same way as built-in `auto`. | integration |
| UC-4 | operator | add a task in auto mode with neither runtime installed | `add` exits nonzero with a diagnostic naming both runtimes, and no task is queued. | integration |
| UC-5 | operator | add a task with an unknown runtime | `add` exits nonzero and does not enqueue it. | integration |
| UC-6 | worker | start a previously queued task | The task runs on its stored runtime even if another is available; a legacy record without `runtime` runs on Claude Code. | integration |

## Open questions

None.
