# Playbook — New or restructured service

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
For a new endpoint on an existing service use `api-endpoint.md` — this playbook is for
service-level structure.

## Sequence

1. **Copy the nearest existing service.** Mirror its layout, config loading, middleware chain, and
   build targets. A new service that does not look like the others is a permanent maintenance cost.
2. **Config from the environment**, parsed once at startup into a typed structure, validated before
   anything binds a port. Fail fast with a clear message on a missing variable — never default a
   credential, never read one at request time.
3. **Layers in this order:** transport (decode, validate, map errors to status) → business logic
   (no transport types) → data access (context or cancellation token first). Declare interfaces
   where they are consumed, not where they are implemented.
4. **Observability from the first commit**, not retrofitted: structured logs to stdout, a request
   id carried through the call chain, and a health endpoint that reports dependency status.
5. **Graceful shutdown.** Handle the termination signal, stop accepting work, drain in flight, and
   tie every background task to a cancellation scope.
6. **Deployment artefacts in the same change** — container build, deployment manifest or chart
   values, and the CI job. A service that cannot be deployed is not done. Infrastructure changes
   beyond a values file belong in their own change (`infra-change.md`).

## Test requirements

- One test per business-logic function, parameterised, one case per branch.
- Transport tests covering each status code the handler can return.
- Data-access tests against a real datastore, tagged or marked so they can be run separately.
- The health endpoint has a test — it is the endpoint the platform trusts most and teams test least.
- One test per acceptance criterion, named with its `UC-<n>` id when working from a spec.

## Verify

Run the verification block from the rules file for this stack: lint, static analysis, build, tests
including the race or concurrency mode if the language has one. Add:

- The integration-tagged suite when data-access code changed.
- The service starts, answers its health endpoint, and shuts down cleanly on a termination signal.

## Done when

Layout mirrors a sibling service, config validated at startup, logging and health in place,
shutdown graceful, deployment artefacts present, and every verification command green.
