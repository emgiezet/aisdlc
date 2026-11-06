# tools.lock.json — scope and maintenance rules

## What is pinned here and why

Stage 0 pins every analyzer needed by the spec section 9.3 config gate, plus
`jq` and `shellcheck`: Betterleaks, Checkov, ESLint, golangci-lint, hadolint,
kube-linter, Opengrep, PHPStan, Psalm, Ruff, tflint, and zizmor.

`jq` is bootstrapped before the dispatcher parses JSON. This prevents a missing
system package from disabling policy hooks. `shellcheck` validates the plugin's
own shell code.

Binary and PHAR releases carry a hash for each supported platform. Ruff and
Checkov share a hash-pinned Python lock. The ESLint stack uses an npm lockfile
and installs with lifecycle scripts disabled. tflint also pins its AWS ruleset
in the baseline config.

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

## ESLint plugin major compatibility (2026-11-06)

ESLint and @eslint/js 9.39.5 (published July 10) satisfy every pinned plugin's
ESLint peer range. ESLint 10 remains excluded by eslint-plugin-react 7.37.5.

regexp 3 blocked: transitive jsdoc-type-pratt-parser requires node
`^22.22.2 || >=24.15.0`. eslint-plugin-regexp 3.3.2 accepts ESLint `>=9.38.0`,
but depends on jsdoc-type-pratt-parser `^9.0.0`; every eligible parser release
9.0.0–9.4.0 has that stricter Node engine. Parser 9.5.0 also has it and was
published Nov 3, inside the seven-day hold. No eligible parser 9.x satisfies
this bundle's `^20.19.0 || ^22.13.0 || >=24` floor or local Node 24.0.2.
Keep regexp 2.10.0 rather than override outside its range, ignore EBADENGINE,
or raise the supported Node floor to force a major upgrade.
