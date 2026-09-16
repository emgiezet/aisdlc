# Changelog

All notable changes to Slop Guard will be documented in this file.

## Unreleased

- Plugin skeleton: directory layout, manifest (`plugin.json`), empty hook manifest (`hooks.json`).
- Licence notices: `LICENSE` (MIT), `THIRD_PARTY_NOTICES.md`.
- Design decisions recorded in `docs/decisions.md` (D1 bash+jq, D2 Opengrep, D10 GitHub Actions confirmed; D3–D9 taken at spec recommendation; D11 open, interim default postgres).
- Baseline configs created from spec §6 verbatim: `phpstan.neon`, `psalm.xml`, `phpmd.xml`,
  `.golangci.yml`, `ruff.toml`, `pyrightconfig.json`, `eslint.config.mjs`,
  `eslint.security-overlay.mjs`, `.sqlfluff`, `.squawk.toml`, `.tflint.hcl`, `.checkov.yaml`,
  `.kube-linter.yaml`, `.hadolint.yaml`, `zizmor.yml`, `.gitleaks.toml`.
- Validation script `scripts/validate-configs` created (spec §9.3). Ruff validated PASS against
  ruff 0.16.7. All other tools not yet installed — rows SKIP pending `slopguard doctor --install`.
  golangci-lint v1.51.0 present but does not support `config verify` (v2 config format requires
  golangci-lint v2+); SKIP until the tool is pinned in `tools.lock.json`.
- Config gaps recorded (spec gave no verbatim content):
  - `eslint.security-overlay.mjs`: content derived from spec §6.4 description (JS/TS security
    section of `eslint.config.mjs`); no rule invented beyond what the spec names.
  - `.tflint.hcl`: AWS plugin version placeholder `0.40.0` used (spec text said "X.Y.Z — pin at
    implementation time"); must be verified and updated when tflint is added to `tools.lock.json`.
- Fixture directories created: `tests/fixtures/{php,python,ts,terraform,docker,kubernetes,ci}/good/`.
  Each contains a minimal valid file sufficient for the §9.3 validation command to run.
