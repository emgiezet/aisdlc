# AI SDLC — the operating manual

How to run software delivery where agents write the code and people own the specification, the
harness, and the judgement calls. This is the reference for the `/sdlc-*` commands, the `aisdlc`
queue, and the four harness skills.

## The shift

Spec-driven development wrote requirements for humans: prose to align a team before people wrote
code. The artefacts here look similar and function differently — they are **fuel for agents**.
A paragraph a person reads charitably, an agent reads literally, so ambiguity stops being a
communication risk and becomes a defect that ships.

Three consequences shape everything below:

1. **Throughput stops being bounded by typing.** When the constraint moves off the keyboard, the
   new constraints are specification quality, review capacity, and test coverage.
2. **The developer's product is the pipeline, not the patch.** You stop making one pair of shoes
   well and start running the factory: the router, the playbooks, the test floors, the queue.
   A defect in the harness reproduces across every task; a defect in one patch does not.
3. **Review is the scarce resource.** Generating a hundred pull requests is easy. Making a hundred
   pull requests *worth someone's attention* is the actual engineering.

## The loop

| Step | Who | Artefact |
|------|-----|----------|
| `/sdlc:brainstorm`, `/sdlc:discover`, `/sdlc:backlog` (optional) | human with an agent | `specs/briefs/*.md`, issues |
| `/sdlc:init` (once per repo) | agent proposes, human approves | `CLAUDE.md`, `.claude/playbooks/`, `.claude/rules/`, `.claude/sdlc.md`, `.claude/trackers/`, `.claude/browsers/` |
| `/sdlc:update` (after each plugin upgrade) | agent proposes, human approves | descriptor operations, `.claude/sdlc.md` fields and `.aisdlc/config.json` keys brought up to the installed version; drift in the router, playbooks and rules reported, never rewritten |
| `/sdlc:spec <TICKET>` | agent drafts, human corrects | `specs/<TICKET>/spec.md`, `status: draft` |
| `/sdlc:mockup <TICKET>` | agent builds, business reacts | `specs/<TICKET>/mockup/index.html` |
| **Approve** | **human only** | `status: approved`, committed — or, for a bug, the `bug` label on the issue |
| `aisdlc add` / `run` | queue | worktree + branch per task |
| `/sdlc:triage`, `/sdlc:root-cause` (issue route) | agent, read-only | `specs/GH-<n>/spec.md` with `kind: bugfix`, root cause in Context |
| `/sdlc:implement` | agent, unattended | commits per UC, or `BLOCKED.md` |
| `/sdlc:qa` | agent, unattended | `specs/<TICKET>/qa-report.md`, PASS/GAPS, screenshots for UI UCs |
| `aisdlc scope-check` | queue, native bash | `specs/<TICKET>/scope-report.md`, PASS/GAPS/BLOCKED — BLOCKED stops before ship |
| `/sdlc:ship` | agent, unattended | draft PR labelled `ai-sdlc` + `review` |
| `/sdlc:review` | agent, unattended | `APPROVED` → `merge-ready`, or `CHANGES_REQUESTED` and an autofix loop |
| `/sdlc:continue`, `/sdlc:fix-pr`, `/sdlc:autopilot` | agent, on demand | a stalled PR driven to `merge-ready` |
| `/sdlc:merge` | **human only** | the decision that still cannot be delegated, now with its gates checked |
| `/sdlc:close-fixed`, `/sdlc:changelog`, `/sdlc:retro` | agent, on a schedule | closed issues, a changelog PR, a ranked list of what the harness cost |

Everything before the approval line is cheap to change. Everything after it is an agent acting on
your behalf without supervision. Spend your attention accordingly: **an hour on the spec is worth
a day of reviewing what the spec failed to say.**

## Where the leverage actually is

### The spec is the only gate

`/sdlc:implement` has no plan-review step. That is not a corner cut for speed — it is what makes
the work queueable, and it moves all the risk to one reviewable artefact. Which is why the queue
refuses a spec that is not `approved`, refuses one with unresolved open questions, and checks both
again inside the worktree before spending a token.

The section that earns its keep most is `Out:`. It is the only thing standing between "add a
balance endpoint" and an agent helpfully restructuring the money handling on its way past.

### Context is routed, not concatenated

A single large `CLAUDE.md` makes every instruction weaker: the model reads all of it for every
task, and adding a rule dilutes the rest. The hierarchy — router table → task playbook →
path-scoped rule — means a migration task loads migration instructions and nothing about Helm.
Cheaper, and measurably better at following what it did load. See the `task-router` skill for the
budgets and the diagnosis steps.

### Tests are a net, and nets are judged by hole size

Agent defects are scattered and specific rather than systematic, so **the number of behaviours
pinned matters more than the elegance of any single test.** One integration test per `UC-<n>`
carrying its id, a unit test per public symbol, a case per error branch and validation rule. The
UC id in the test name is what makes spec coverage a `grep` instead of a judgement call.

The rules that cannot bend: never delete a test, skip a test, or loosen an assertion to get green.
Those are enforced by a `Stop` hook rather than by good intentions, because an agent under pressure
to produce a green run will otherwise take the shortest path to green.

### A plan may be large; a pull request may not

Throughput is worthless if the review at the end is a rubber stamp, and review quality falls off
a cliff with size. The numbers behind the defaults:

| Signal | What the evidence says | Source |
|---|---|---|
| Added lines | Defect-finding degrades past ~400 reviewed lines; 200–400 LOC in 60–90 min yields 70–90% of findable defects | [SmartBear / Cisco review study](https://smartbear.com/learn/code-review/best-practices-for-peer-code-review/) (vendor telemetry, single org) |
| Added lines | "100 lines is usually a reasonable size for a CL, and 1000 lines is usually too large"; reviewers may reject a change for size alone | [Google eng-practices, Small CLs](https://google.github.io/eng-practices/review/developer/small-cls.html) (guidance) |
| Files | Each extra file in a PR cuts the odds that any given file gets a review comment by 8.7%; latent-bug risk is lowest near ~10 files | [arXiv 2609.22610](https://arxiv.org/abs/2609.22610) — 330,343 PRs, 182 projects (peer-reviewed preprint) |
| Modules | Co-changes spanning different subsystems produce more defects than co-changes inside one | [D'Ambros, Lanza, Robbes, WCRE 2009](https://www.inf.usi.ch/lanza/PUBS/P/DAmb2009e.pdf); change entropy: [Hassan, ICSE 2009](https://dl.acm.org/doi/10.1109/ICSE.2009.5070510) |
| Merge latency | 500+ line PRs average 9 days to merge; 50-line PRs merge ~40% faster and are reverted 15% less than 250-line ones | [Graphite](https://graphite.com/blog/the-ideal-pr-is-50-lines-long) (vendor telemetry, methodology disclosed) |

So the harness budgets the change instead of hoping: **400 added lines, 15 files, 3 modules**, with
a hard ceiling of **3000 added lines** past which `scope-check` returns `BLOCKED` and the queue
stops before ship. Deleted lines, generated output, vendored trees, lock files and the specs
directory never count — removing code is not a large change to review.

The budget binds at planning time, not at review time: `/sdlc:spec` estimates the surface from the
paths in `Context` plus their call sites, and calls `/sdlc:decompose` when the estimate breaks a
number. Decomposition picks a seam that keeps every intermediate state shippable — walking
skeleton, vertical slice, seam-first for shotgun surgery, expand/contract for data shapes, and a
separate slice for anything mechanical. A 300-file rename is reviewable by pattern; the same
rename mixed with logic is not, which is why a spec may declare its own wider `Change budget:`
and why a mechanical slice never carries behaviour.

Two numbers deliberately disagree with the research. The 3000-line ceiling is far above what any
source would defend as reviewable — it is the outer bound on damage, not a target. And the file
and module budgets produce `GAPS`, not `BLOCKED`: no primary source justifies blocking on module
count alone, so it starts a decomposition conversation instead of stopping the run.

### QA before humans

`auto-qa` re-derives the use cases from the spec *before* reading the implementation. Reading the
code first makes any reviewer — human or agent — agree with it. The verdict is the first line of
the PR body, so a reviewer knows in one second whether this branch deserves the next ten minutes.

`GAPS` must mean gaps. The moment `PASS` sometimes means "nearly", reviewers go back to reading
every diff and the pipeline's value collapses.

### Cheap models are the target

If the pipeline only works on the most expensive model, the harness is carrying none of the weight.
`make harness-eval MODEL=haiku` measures that directly. When a scenario fails on Haiku, the defect
is in a file you own: a router row that reads ambiguously, a rule that implies instead of stating,
a UC with nothing observable to assert. Fixing those makes the expensive model better too.

Acceptance bar for a harness change: Sonnet passes every scenario, Haiku passes all but one.

**Measured baseline** — `go-endpoint` (3 use cases, Go, contract change) on Haiku:

| | turns | cost | wall clock |
|---|---|---|---|
| `/sdlc:implement` | 29 | $0.22 | 154 s |
| `/sdlc:qa` | 6 | $0.37 | 164 s |
| **total** | | **$0.59** | **5.4 min** |

10/10 assertions: a test per use case carrying its id, the contract updated in the same commit,
integer serialisation preserved, zero skips, QA verdict `PASS` and committed. QA earned its place —
it started the service and confirmed each result against the running instance with `curl`, rather
than trusting the tests it had just read.

Two things this number is worth reading for. QA is 63% of the cost for a three-use-case change,
which makes it the first candidate for tuning: it re-reads the spec, the diff and the tests, then
runs the suites again. Measure before picking a fix — scope `auto-qa`'s reading to the diff plus the
spec, or run QA at a lower effort setting than implement — and never tune it by weakening what QA
checks.

The second is what changed between an earlier run of the same scenario ($1.53, 12 minutes, QA at 12
turns) and this one ($0.59, 5.4 minutes, QA at 6 turns). Nothing about the model changed. Two
instructions did: the commands got an unmissable first-action file check instead of a gate buried
mid-document, and the queue stopped inheriting whatever permission rules the developer happened to
have. Both of those were wandering, and wandering is what agent work actually costs.

## Definition of done for a queued task

A task is done when **all** of these hold — this is what `/sdlc:qa`, `aisdlc scope-check`,
`/sdlc:ship` and `/sdlc:review` check:

- Every `UC-<n>` in the spec has a passing test carrying its id.
- The full CI matrix for every touched stack is green, and skip count is zero.
- No file in the spec's `Out:` scope was modified.
- The contract directory, if this project has one, changed in the same commit as any handler whose contract moved.
- `qa-report.md` says `PASS`, with an explicit "not verified" section, and a screenshot per UI UC when a browser is configured.
- `scope-report.md` says `PASS` or `GAPS` (no `BLOCKED`); any `GAPS` entries reviewed and accepted by a human.
- The PR is a draft, labelled, with the riskiest changes called out by `file:line`.
- `/sdlc:review` returned `APPROVED`: no blocker, no unwaived major.

Anything less is `GAPS` or `BLOCKED`. Both are successful outcomes of an unattended run — the
failure mode to fear is a confident PR that quietly does the wrong thing.

## Metrics worth tracking

`aisdlc status` and each task's `result.json` carry the raw numbers.

| Metric | Why it matters | Where |
|--------|----------------|-------|
| PRs merged per week | The throughput claim, tested | `gh pr list --label ai-sdlc --state merged` |
| $ per merged PR | The economics, per task and per model | `.aisdlc/tasks/*/task.json` → `cost_usd` (null for subscription-billed runs) |
| First-pass QA rate | `PASS` without human intervention — the harness's real score | QA verdicts |
| `BLOCKED` rate and reasons | Recurring reasons are a spec-format or playbook defect | `BLOCKED.md` files |
| Haiku pass rate | Independence from the top model | `make harness-eval MODEL=haiku` |
| Review latency | The bottleneck once generation is cheap | PR open → merge |

Watch the ratio between generated and merged. A rising generated count with a flat merged count
means the harness is producing work that reviewers reject — noise dressed as throughput.

## Queue configuration

The queue runner reads per-repo defaults from `.aisdlc/config.json`, written by `/sdlc:init`.
All settings can also be overridden by environment variable or by a flag on `aisdlc add`.
Precedence for every setting: CLI flag > `.aisdlc/config.json` > environment variable > built-in default.

| Setting | Config key | Env variable | Default | Notes |
|---------|------------|--------------|---------|-------|
| model | `model` | `AISDLC_MODEL` | `sonnet` | Any model name accepted by `claude --model` |
| per-phase budget | `budget` | `AISDLC_BUDGET` | `5` | USD ceiling per phase; ignored when `billing=subscription` |
| base ref | `base` | `AISDLC_BASE` | auto-detected | Branch or remote ref to branch from |
| workers | `workers` | `AISDLC_WORKERS` | `3` | Parallel workers for `aisdlc run` |
| label | `label` | `AISDLC_LABEL` | `ai-sdlc` | PR label applied by ship |
| specs dir | `specs_dir` | `AISDLC_SPECS_DIR` | `specs` | Root for spec files |
| billing | `billing` | `AISDLC_BILLING` | `api` | `api` or `subscription` — see below |
| model roles | `model_roles` | — | *(absent)* | Maps `smol`/`default`/`slow` roles to model names; see below. Absent = today's behaviour |

### billing = subscription

On a Claude Pro/Max subscription the CLI reports no per-token cost, so every phase records
`total_cost_usd: 0`. Zero is indistinguishable from "a phase that ran instantly and did
nothing useful", which is exactly the class of silent failure the queue tries to surface.
Setting `billing: subscription` makes the difference explicit:

- `--max-budget-usd` is **not** passed to `claude`. A spend cap that cannot be enforced reads
  as a guarantee; omitting it is more honest and has no effect on behaviour.
- `cost_usd` in `task.json` is recorded as JSON `null`, not `0`. A null unambiguously means
  "cost data unavailable" rather than "this task was free".
- The phase log notes the billing mode: a log read weeks later explains its own missing numbers.
- `/sdlc:retro` renders null costs as `n/a` and excludes them from averages. The `$ per merged PR`
  metric shows `n/a — subscription billing` when all tasks in the window have null cost.

The zero-turn failure check is **unaffected**: a phase that completes with `num_turns == 0` is
still a hard failure regardless of billing mode. That guard is what prevents a silent no-op from
being reported as a successful PR; billing mode has no bearing on whether Claude ran.

### model_roles

The optional `model_roles` key maps three role names to concrete model names, routing different
queue phases to different models without touching any agent file.

| Role | Queue phases | Commands delegating to `sdlc-scribe` |
|---|---|---|
| `smol` | `scope-check`, `ship` | `close-fixed`, `merge-buddy`, `changelog` |
| `default` | `implement`, `qa`, `triage` | — |
| `slow` | `review`, `root-cause` | — |

Resolution is snapshotted into `task.json` at `aisdlc add` time as a `models` map covering every
phase of that task. `run_phase` uses `.models[<phase>]` when present, falling back to `.model`.
When `model_roles` is absent, no `models` key is written and every phase uses the task's single
model — behaviour identical to today.

Role values are opaque strings passed to `claude --model`; the harness never interprets them.
Omitting a role resolves to the task's `model`.

The command column is a different mechanism from the phase column: those three commands dispatch
the `sdlc-scribe` agent for their read-heavy collection step — the `list-prs` / `get-pr` sweep and
the parsing — and keep every mutation and every gate in the calling session. The agent's own model
comes from its frontmatter, so what `model_roles` controls there is only whether the dispatch
happens at all. `followup` deliberately does not delegate: its single comment read is smaller than
the dispatch that would carry it.

```json
{"model": "sonnet", "model_roles": {"smol": "haiku", "slow": "opus"}}
```

## Failure modes

| Symptom | Real cause | Fix |
|---------|-----------|-----|
| PRs look fine, reviewers keep finding gaps | Specs describe intent, not observable results | `spec-authoring`: rewrite UCs so a test can read the result |
| Agents drift into unrelated code | `Out:` scope is thin | Name the adjacent modules explicitly |
| The same mistake in every task | Harness defect, not a model defect | Fix the playbook or rule; add an eval scenario for it |
| Green suite, low trust | Density floors not applied, or tests assert on mocks | `dense-testing` |
| Only works on the top model | Instructions rely on inference | `harness-eval`: commands over intentions, examples over descriptions |
| Cost per PR climbing | Specs too large; whole-repo context per task | Split specs; check the router loads one playbook |
| Review queue growing faster than merges | Generation outran review capacity | Queue fewer, larger-value tasks — throughput is merges, not PRs |
| `BLOCKED` on the same ambiguity repeatedly | The spec template is missing a section your domain needs | Extend the template, not the individual spec |

## What stays human

Not a temporary list — these are the parts where being accountable is the job:

- Approving a spec, and owning what it left out. For a bug, labelling the issue `bug` *is* that
  approval — `/sdlc:triage` records who did it in the generated spec.
- Deciding a test that contradicts the spec means the test is wrong, or the spec is.
- Hard-to-reverse calls: schema shape, contract breaks, IAM, anything touching money or PII.
- Applying infrastructure. Agents produce the plan; a person runs the apply.
- Merging. `/sdlc:merge` checks the gates and squash-merges, but only when a person runs it; the
  queue never does. A `merge-ready` label is a recommendation, not a decision.
- Evidence. Nothing a synthetic panel says, and nothing tagged `[ASSUMPTION]`, counts as evidence
  in a brief; only a person can gather what does.

## Host support

The harness runs on Claude Code, Codex, Grok, and omp. The queue runner is Claude-only.

| Capability | Claude Code | Codex | Grok | omp |
|------------|-------------|-------|------|-----|
| Knowledge skills (`npx skills`) | ✓ | ✓ | ✓ | ✓ |
| Full plugin (marketplace install) | ✓ | ✓ | ✓ | ✓ |
| Interactive commands (`init`, `spec`, `mockup`, `implement`, `qa`, `ship`, `review`, …) | `/sdlc:<name>` | `$<name>` | `/<name>` | `/sdlc:<name>` |
| Unattended queue (`aisdlc run`) | ✓ | — | — | — |
| `Stop` hook (test-deletion guard) | blocking | blocking | advisory (exit 0, stderr) | — |
| `PreToolUse` hooks (force-push guard, secrets) | blocking | blocking | blocking | extension adapter |
| Model roles (`model_roles`) | queue phases + `sdlc-scribe` delegation | — | — | `sdlc-scribe` delegation; optional `@role` aliases |

On omp, hook enforcement arrives through an extension module (`plugins/<name>/extensions/omp.mjs`, declared via `package.json` → `omp.extensions`) that translates omp's `tool_call` events into calls to the same bash policies Claude and Grok use. Without that adapter the plugin installs as documentation with zero enforcement — omp has no `hooks/hooks.json` surface.

Where `model_roles` is configured, `close-fixed`, `merge-buddy` and `changelog` hand their collection step to the `sdlc-scribe` agent — which needs a host that runs subagents, so Claude Code and omp only. Claude Code resolves that agent's model from its frontmatter; omp additionally resolves `@role` aliases through the optional `modelRoles` mapping in `.omp/config.yml` (see `plugins/sdlc/templates/omp/config.yml` for a copy-and-edit example). Codex and Grok expose no subagent model surface, so the delegation never fires there and the collection runs inline; the phase mapping reaches only the queue, which is Claude-only regardless.

`/sdlc:init` writes both `CLAUDE.md` and `AGENTS.md` into the target repository. `AGENTS.md`
is the Codex entry point: it points Codex agents at the same three-tier instruction hierarchy
(`CLAUDE.md` → task playbook → path-scoped rules) and lists the Codex command for each
workflow step.

## Credentials for the queue runner

`aisdlc run` shells out to `claude -p` and sets no credentials of its own — whatever authenticates
your `claude` CLI authenticates the queue. An API key is one option of four:

| Option | Environment variable(s) | Billed against |
|--------|------------------------|----------------|
| Pro / Max subscription | `CLAUDE_CODE_OAUTH_TOKEN` (run `claude setup-token` once) | plan message limits |
| API key | `ANTHROPIC_API_KEY` | per token, Console |
| Cloud provider | `CLAUDE_CODE_USE_BEDROCK=1` (or Vertex / Foundry) plus that cloud's credentials | AWS / GCP / Azure bill |
| LLM gateway | `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` | wherever the gateway routes |

Two things affect how the pipeline behaves:

- **`ANTHROPIC_API_KEY` wins if it is set.** A key in the environment overrides a subscription token
  and forces Console billing; the runner host must not export one when a subscription is intended.
- **Cost accounting goes quiet on a subscription.** The queue reads `total_cost_usd` from each
  completed phase. A subscription reports no per-token cost, so that value arrives as zero:
  `/sdlc:retro` will rank every task at `$0`, `make harness-eval` cost columns will read zero,
  and `--max-budget-usd` stops being the real ceiling — your plan's rate window is. The
  `num_turns == 0` check still catches a phase that never ran.

## Getting started

```bash
make sandbox                                    # hermetic Go + JS repo in the temp dir
cd /tmp/aisdlc-sandbox && make verify           # baseline must be green
aisdlc add SBX-1 --repo /tmp/aisdlc-sandbox --model haiku --no-pr --plugin-dir
aisdlc run --repo /tmp/aisdlc-sandbox --once
aisdlc logs <id>                                # read what it actually did
```

Then on a real repo: `/sdlc:init`, read what it generated and correct anything that reads wrong,
write one spec by hand with `/sdlc:spec`, run it through `/sdlc:implement` and `/sdlc:qa` while
watching, and only then queue anything. The first spec teaches you more about your harness than the
first ten queued tasks.
