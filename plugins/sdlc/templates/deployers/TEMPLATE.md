# Deploy target: {name}

Copy to `.claude/deployers/{name}.md`, set **Deployer descriptor** in `.claude/sdlc.md` to that
path, and fill every operation below. Commands name operations in bold (**current-release**); this
file says how each one runs. It is the whole integration surface — no command changes for a new
deploy target.

Rules for a provider:

- One `### <operation>` per heading below, body = the exact command with `{param}` placeholders,
  then `Returns:` one line. A heading left empty strands every command that names it.
- Read-only operations must be safe to run at any time without side effects.
- **promote** and **rollback** are the only mutating operations. Both read back the deployment
  state with **deploy-status** before reporting success. A write that fails must not be reported
  as success.
- **promote** never force-deploys and never skips the target's own checks. There is no `--force`
  flag; a refused promotion is a human's problem by design, exactly as `/sdlc:merge` has no force
  flag.
- Environments are named by the project, not by this file. `{env}` is whatever string the profile
  uses (`staging`, `prod`, `production`). The profile key **Environments** lists them in order.
- `none` is a valid configuration: `/sdlc:release-check` then works from git history alone and
  says in one line which checks it could not perform.

## Prerequisites

{CLI or API, how to authenticate, minimum version — and any pre-flight check command}

## Conventions

{how environments are named, how a deployment is identified, how rollback is defined for this
target, any deployment-id or run-url format}

## Operations

### deploy-status      {env} → state (succeeded|failed|in-progress|unknown), ref, finished-at
### current-release    {env} → the ref (sha or tag) currently live in that environment
### env-diff           {from-env} {to-env} → one line per commit present in from but not to: sha, subject, PR number when derivable
### pending-migrations {env} → one line per migration present in the code but not applied in that environment; empty output means none
### promote            {ref} {env} → the deployment id or run url, read back with deploy-status
### rollback           {env} {ref} → the deployment id or run url, read back with deploy-status
