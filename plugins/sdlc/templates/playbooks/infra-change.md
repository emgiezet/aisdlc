# Playbook — Infrastructure change

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
Load the applicable infrastructure and security rules files (Claude/Grok auto-attach them; on Codex, open them explicitly).

## Sequence

1. **Read the current state before proposing a change.** Run the plan or diff command against the
   real target. Infrastructure drifts; the repository is not automatically the truth.
2. **Blast radius first.** Name what this change can take down and who notices. Anything touching
   networking, identity and access, or a stateful resource is review-before-apply, always.
3. **Smallest reversible step.** Add before you remove. Never let one change both create the
   replacement and destroy the original for a stateful resource.
4. **No secrets in the repository.** Values come from the secret manager by reference. A literal
   credential in a values file or a template is a blocking defect even in a draft.
5. **Pin everything** — provider, module, chart, and image versions. Never a floating tag.
6. **Get it reviewed**, and involve a security reviewer when the change touches identity, network
   exposure, or data at rest.

## Verify

**Never apply from an unattended run.** Produce the evidence and stop:

- Format check, validate, lint, then the plan or rendered diff — with the output attached to the
  pull request body. Applying is a human action.
- Confirm the plan creates and destroys exactly what you intended. A plan destroying a resource
  you did not mention means stop and re-read step 2.

## Test requirements

Infrastructure has no unit tests, so **the plan output is the test artefact**. Required in the pull
request body: the full plan or diff, the blast-radius statement from step 2, the rollback command,
and whether this is safe to apply outside a maintenance window.

## Done when

Plan or diff attached and matching the stated intent, no secrets and no floating versions, review
clean, rollback documented, and the apply left to a human.
