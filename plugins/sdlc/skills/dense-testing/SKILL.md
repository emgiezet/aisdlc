---
name: dense-testing
description: >
  Build the test grid that makes AI-written code safe — traceability from spec UC ids to
  tests, density floors per changed symbol, and a hard ban on skipping or weakening tests to
  get green. Use when deciding how many tests a change needs, wiring acceptance criteria to
  test names, generating tests for agent-written code, or when a suite is green but trust in
  it is low.
---

# Dense Testing

When agents write the code, tests stop being a quality ritual and become the only mechanism
that catches a hallucination. The grid has to be dense enough that a plausible-but-wrong
implementation cannot slip between the holes.

The counter-intuitive part: **at scale, test count matters more than the elegance of any
single test.** A thousand blunt tests that each pin one observable behaviour catch more
agent defects than fifty beautifully-factored ones, because agent errors are scattered and
specific rather than systematic. Optimise for coverage of behaviours, not for DRY test code.

Stack conventions and commands live elsewhere: this project's `.claude/rules/` files, its
`.claude/sdlc.md` verification table, and any stack pattern skills it happens to have. This skill
is the *how much* and the *what must never happen*.

## Traceability: UC id in the test name

Every acceptance criterion in `specs/<TICKET>/spec.md` carries a stable `UC-<n>` id. Every
test that proves one carries that id in its name or annotation:

```go
func TestGetBalance_UC1_ReturnsIntegerMinorUnits(t *testing.T) { … }
```
```ts
it('UC-3: lists entries newest first', async () => { … })
```
```python
def test_uc2_rejects_a_total_that_does_not_reconcile(): ...
```

This makes coverage of the *spec* computable with grep, independent of line-coverage tools:

```bash
grep -rho 'UC-[0-9]\+' <test-dir> | sort -u    # UCs with at least one test
```

The `qa` skill and the `auto-qa` agent build the UC×test matrix from exactly this. A UC with no
matching test is a gap, whatever the line coverage says.

## Density floors

Minimums, not targets. Applied to the diff, not the whole repo:

| Changed thing | Minimum tests |
|---------------|---------------|
| Acceptance criterion (`UC-<n>`) | 1 integration test carrying its id |
| Public function / method / exported symbol | 1 unit test for the happy path |
| Error return or thrown exception | 1 case per distinct error |
| Validation rule | 1 rejection case per rule, asserting no side effect |
| HTTP endpoint | happy path + validation rejection + authorization denial + not-found |
| Conditional branch | 1 case per side |
| UI component with logic | 1 case per render state: populated, empty, loading, error, denied |
| Multi-screen flow in the spec | 1 Playwright scenario |
| Migration | up→down→up on a scratch DB, plus 1 case per new constraint |
| Bug fix | 1 test that fails before the fix and passes after |

Table-driven or parameterised tests satisfy several rows at once and are the cheapest way to hit
the branch floor — one case per branch, which is also how a weak model reliably generates them.

## Assert on observable behaviour

Assert what a caller can see: status code, response body, database row, rendered text,
emitted event, log line. Not: that a mock was called, that an internal method ran, that a
private field holds a value. A test coupled to the implementation passes for a
reimplementation that is wrong, which is the exact failure this grid exists to catch.

Mock only what you cannot run: third-party APIs, clocks, randomness, payment providers. Never mock
your own database or your own service layer in an integration test.

## Non-negotiable

The no-delete/no-skip/no-weaken invariants are mandatory on every host. On Claude and Codex, the `Stop` hook blocks a session that violates them. On Grok, Stop is passive — the same check fires as an advisory warning:

1. **Never delete a test** to make a suite green.
2. **Never skip a test** — `t.Skip`, `.skip(`, `.only(`, `markTestSkipped`,
   `@pytest.mark.skip`, `@Ignore`, commenting a test out.
3. **Never weaken an assertion** — loosening an exact match to a substring, removing a field
   check, widening an expected range, replacing an assertion with a log.
4. **Never assert current buggy behaviour** just to get green.

When a test contradicts the spec, **stop and report the contradiction.** One of the two is
wrong and deciding which is a human call, not a cleanup task. In an unattended run, write the
contradiction to `specs/<TICKET>/BLOCKED.md` and exit non-zero.

A flaky test is a defect in the test or the fixture. Fix the race, the shared state, or the
clock dependency. Never add a retry wrapper to hide it.

## End-to-end tests for spec flows

For multi-screen rows (`test: e2e`), one scenario per flow with whichever runner the project
records in `.claude/sdlc.md`, named with the use-case id, driving the real UI against a seeded
database. Assert on user-visible text and roles. Capture a screenshot at the point the result
becomes visible and attach it to the QA report — the cheapest evidence a human can check in
seconds. Keep the e2e count low and the integration count high: e2e is where suite runtime goes
to die.

## Reporting

After a run, report in the spec's terms, not the tool's:

```
UC coverage: 7/8 (UC-6 has no test)
Tests: 412 → 448 (+36)
Suites: <each one you ran> ✓
Skipped: 0        # any non-zero value is a finding, not a footnote
```

Coverage percentage is a secondary signal. `UC` coverage and skip count are the primary ones.
