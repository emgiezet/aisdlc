# tools.lock.json — scope and maintenance rules

## What is pinned here and why

Only `jq` and `shellcheck` are pinned in Stage 0.

**jq** — the dispatcher (`bin/slopguard`) builds and parses every JSON response
using `jq`. Under Z6 (fail-closed for policy), a missing `jq` would silently
turn every JSON-based policy into a no-op — the one failure mode this plugin
cannot have. It is pinned as a first-class binary, not assumed to be present.

**shellcheck** — the dispatcher's own lint gate. `shellcheck -S warning` is the
CI acceptance criterion for every `.sh` file in this plugin.

Every other tool (opengrep, golangci-lint, ruff, eslint-stack, checkov,
tflint, kube-linter, hadolint, zizmor, …) is added by the stage that first
uses it, so that the lockfile entry, its baseline config, and its test fixtures
always land in the same commit. A lockfile of twenty entries whose hashes
nobody has verified is worse than a short one that is true.

## Schema

See spec §9.2 for the canonical schema. Each binary tool entry carries:

- `version` — the exact release tag (without a leading `v`).
- `assets.<platform>.url` — the release asset URL. No mutable tags; the URL
  must point at an immutable release (by tag and filename).
- `assets.<platform>.sha256` — the SHA-256 of the downloaded asset, computed
  from a local download, not copied from an external source. Verified by
  `install_tool` before extraction.
- `bin` — the name of the executable inside the extracted/copied directory.

## Version bump procedure

A version bump is a pull request that:

1. Updates `version` and all `assets` entries in this file.
2. Recomputes every `sha256` by downloading the new assets and running
   `sha256sum` (or `shasum -a 256`) locally.
3. Keeps `plugins/slop-guard/tests/run-tests` green after the bump.

Automated tooling (Renovate, Dependabot) may open the PR but **must not
merge it automatically** — a human reviews the hashes.

## 7-day publication rule

Nothing is pinned within 7 days of its release publication date. The window
allows detection of a malicious or compromised release before it enters the
lockfile (see D5 in `docs/decisions.md` for the Trivy/KICS incident that
motivated this rule).

Check the publication date with:

```bash
curl -sS https://api.github.com/repos/<owner>/<repo>/releases/tags/<tag> \
    | jq -r .published_at
```

If the newest release is younger than 7 days, pin the one before it and record
this in the PR description.
