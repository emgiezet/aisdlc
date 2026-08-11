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
| `/sdlc:init` (once per repo) | agent proposes, human approves | `CLAUDE.md`, `.claude/playbooks/`, `.claude/rules/`, `.claude/sdlc.md` |
| `/sdlc:spec <TICKET>` | agent drafts, human corrects | `specs/<TICKET>/spec.md`, `status: draft` |
| `/sdlc:mockup <TICKET>` | agent builds, business reacts | `specs/<TICKET>/mockup/index.html` |
| **Approve** | **human only** | `status: approved`, committed |
| `aisdlc add` / `run` | queue | worktree + branch per task |
| `/sdlc:implement` | agent, unattended | commits per UC, or `BLOCKED.md` |
| `/sdlc:qa` | agent, unattended | `specs/<TICKET>/qa-report.md`, PASS/GAPS |
| `/sdlc:ship` | agent, unattended | draft PR labelled `ai-sdlc` |
| Review & merge | human | the decision that still cannot be delegated |

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

**Measured baseline** — `go-endpoint` (3 UCs, Go, contract change) on Haiku, first real run:

| | turns | cost | wall clock |
|---|---|---|---|
| `/sdlc:implement` | 28 | $0.25 | 117 s |
| `/sdlc:qa` | 12 | $1.29 | 598 s |
| **total** | | **$1.53** | **12 min** |

10/10 assertions: a test per UC carrying its id, contract updated in the same commit, integer
serialisation preserved, zero skips. QA earned its place by finding a gap `implement` missed —
the non-functional requirement had no test — writing one, and committing it separately from the
report.

The uncomfortable number is QA taking 84% of the cost and 83% of the wall clock on a three-UC
change. That is the first thing to tune: QA re-reads the spec, the diff, and the tests, then runs
the suites again. Options worth measuring before picking one — scope `auto-qa`'s reading to the
diff plus the spec, skip the independent re-derivation for specs under some size, or run QA on a
cheaper effort setting than implement. Do not tune it by weakening what QA checks.

## Definition of done for a queued task

A task is done when **all** of these hold — this is what `/sdlc:qa` and `/sdlc:ship` check:

- Every `UC-<n>` in the spec has a passing test carrying its id.
- The full CI matrix for every touched stack is green, and skip count is zero.
- No file in the spec's `Out:` scope was modified.
- The contract directory, if this project has one, changed in the same commit as any handler whose contract moved.
- `qa-report.md` says `PASS`, with an explicit "not verified" section.
- The PR is a draft, labelled, with the riskiest changes called out by `file:line`.

Anything less is `GAPS` or `BLOCKED`. Both are successful outcomes of an unattended run — the
failure mode to fear is a confident PR that quietly does the wrong thing.

## Metrics worth tracking

`aisdlc status` and each task's `result.json` carry the raw numbers.

| Metric | Why it matters | Where |
|--------|----------------|-------|
| PRs merged per week | The throughput claim, tested | `gh pr list --label ai-sdlc --state merged` |
| $ per merged PR | The economics, per task and per model | `.aisdlc/tasks/*/task.json` → `cost_usd` |
| First-pass QA rate | `PASS` without human intervention — the harness's real score | QA verdicts |
| `BLOCKED` rate and reasons | Recurring reasons are a spec-format or playbook defect | `BLOCKED.md` files |
| Haiku pass rate | Independence from the top model | `make harness-eval MODEL=haiku` |
| Review latency | The bottleneck once generation is cheap | PR open → merge |

Watch the ratio between generated and merged. A rising generated count with a flat merged count
means the harness is producing work that reviewers reject — noise dressed as throughput.

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

- Approving a spec, and owning what it left out.
- Deciding a test that contradicts the spec means the test is wrong, or the spec is.
- Hard-to-reverse calls: schema shape, contract breaks, IAM, anything touching money or PII.
- Applying infrastructure. Agents produce the plan; a person runs the apply.
- Merging. A draft PR labelled `ai-sdlc` with a `PASS` verdict is a recommendation, not a decision.

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
