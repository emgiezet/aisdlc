# Test tiers and CI stages

A test's tier is decided by **what it touches at runtime**, never by how much code it covers.
An HTTP handler exercised through an in-memory request recorder with fake collaborators is a
unit test however many layers the call crosses; the same handler against a real database is an
integration test.

## The three tiers

| Tier | May touch | Must not touch | Budget per test |
|------|-----------|----------------|-----------------|
| `unit` | the process it runs in: pure logic, in-memory fakes and mocks, a fake clock, a temp dir it created | sockets (loopback included), a real database, a broker, a browser, `sleep` | < 100 ms |
| `integration` | one machine: real schema and migrations, real filesystem, a container the suite starts, the process's own transport over loopback | third-party networks, a browser, a multi-service topology | < 2 s |
| `e2e` | a deployed test environment through the surface a user touches: browser or public API | — | < 60 s |

A test that blows its tier's budget is usually in the wrong tier, or is doing per-test setup
that belongs in a shared fixture.

## Pick the lowest tier that can observe the result

1. Return value, raised error, emitted event, rendered component state → `unit`.
2. Persisted row, file written, migration, transaction boundary, query shape, cross-service
   contract → `integration`.
3. A journey that only exists once several screens or services are combined → `e2e`.

`unit` is the default. `integration` needs a persistence or boundary effect to earn it. `e2e` is
allowed only for a flow named in the profile's `Critical journeys:`; with `Critical journeys:
none`, at most one `e2e` use case per spec.

## One behaviour, one tier

A behaviour proven at a lower tier is never re-proven at a higher one. A pricing rule re-asserted
through the browser costs CI minutes on every push and fails for reasons that have nothing to do
with pricing.

| Instead of | Do this |
|---|---|
| one e2e case per validation rule | one e2e for the journey, one unit case per rule |
| one integration test per branch of a service method | one integration test for the persistence effect, unit cases for the branches |
| an e2e that logs in to assert a label | a unit render test for the label; e2e only for the login journey itself |

When an e2e failure finds a bug, the fix ships with a unit test that pins it, and the scenario
stays as the journey check — high-level tests are the second line of defence, not the first.

## Shape

Google's published first guess is 70% unit / 20% integration / 10% e2e: "The exact mix will be
different for each team, but in general, it should retain that pyramid shape"
(<https://testing.googleblog.com/2015/04/just-say-no-to-more-end-to-end-tests.html>).

Measure the shape **on the diff**, not the repository, and use one rule:

> New `unit` tests outnumber new `integration` + new `e2e` tests combined, and the number of new
> `e2e` tests is at most the number of `e2e` rows in the spec.

A change that breaks it is not forbidden — a migration-only change legitimately adds integration
tests and nothing else — but the QA report must say why. Unexplained, it is a `major` finding; an
e2e case asserting a rule a unit test already pins is a `minor` one.

## CI stages

Each tier runs at the earliest stage that can host it, and no stage re-runs a tier that already
passed on the same commit.

| Stage | Trigger | Runs | Budget | Red means |
|-------|---------|------|--------|-----------|
| commit | every push, every branch | lint, types, `unit` | ≤ 10 min (the ten-minute build rule) | the push is broken; nothing downstream starts |
| pull request | PR opened or updated against the default branch | `unit` + `integration` | ≤ 20 min | merge is blocked |
| test environment | merge to the default branch, after the deploy succeeds | `unit` + `integration` + `e2e` against the deployed environment | uncapped | the environment is red; no promotion |
| production | manual promotion of a commit | nothing new | — | promotion refused |

## The production gate

The production job **runs no tests**. It requires a recorded full-suite result that is

1. green for every tier,
2. keyed to the **exact commit sha** being promoted — not the branch, not "latest",
3. produced by the run against the test environment after that commit was deployed there.

Missing, red, or belonging to another commit → refuse the promotion and name which of the three
failed. A gate that re-runs the suite instead of reading the recorded result pays for the suite
twice and promotes a different run than the one that was reviewed.

## What the harness runs locally

`/sdlc:implement` and `/sdlc:qa` run the profile's `unit` row every time; the `integration` row
when the diff touches a path that tier covers or the spec has an `integration` use case; the
`e2e` row only when the spec has an `e2e` use case. Running the whole pyramid on every agent turn
is the same waste as running it on every commit.

## Sources

- Martin Fowler, *Test Pyramid* — <https://martinfowler.com/bliki/TestPyramid.html>
- Google Testing Blog, *Test Sizes* (small/medium/large defined by what a test may touch) —
  <https://testing.googleblog.com/2010/12/test-sizes.html>
- Martin Fowler, *Deployment Pipeline* — <https://martinfowler.com/bliki/DeploymentPipeline.html>
  and the ten-minute build in <https://martinfowler.com/articles/continuousIntegration.html>
