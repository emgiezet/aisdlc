# Changelog

All notable changes to Slop Guard will be documented in this file.

## Unreleased

- Plugin skeleton: directory layout, manifest (`plugin.json`), empty hook manifest (`hooks.json`).
- Licence notices: `LICENSE` (MIT), `THIRD_PARTY_NOTICES.md`.
- Design decisions recorded in `docs/decisions.md` (D1 bash+jq, D2 Opengrep, D10 GitHub Actions confirmed; D3–D9 taken at spec recommendation; D11 open, interim default postgres).
- Baseline configs created from spec §6 verbatim (exceptions noted): `phpstan.neon`, `psalm.xml`,
  `phpmd.xml`, `.golangci.yml`, `pyrightconfig.json`, `eslint.config.mjs`, `.sqlfluff`,
  `.squawk.toml`, `.checkov.yaml`, `.kube-linter.yaml`, `.hadolint.yaml`, `zizmor.yml`,
  `.gitleaks.toml`. Exceptions: `ruff.toml` (spec comments in Polish — translated to English per
  plugin language rule); `.tflint.hcl` (spec placeholder `X.Y.Z` for AWS plugin version —
  `plugin "aws"` block commented out pending tflint pin in `tools.lock.json`);
  `eslint.security-overlay.mjs` (spec §6.4 describes role but gives no verbatim content — derived
  from the JS/TS common security block of `eslint.config.mjs`; `extends: [js.configs.recommended]`
  omitted since the overlay is a second pass, not a replacement config).
- Validation script `scripts/validate-configs` created (spec §9.3). Ruff validated PASS against
  ruff 0.16.7. All other tools not yet installed — rows SKIP pending `slopguard doctor --install`.
  golangci-lint v1.51.0 present but does not support `config verify` (v2 config format requires
  golangci-lint v2+); SKIP until the tool is pinned in `tools.lock.json`.
- Fixture directories created: `tests/fixtures/{php,python,ts,terraform,docker,kubernetes,ci}/good/`.
  Each contains a minimal valid file sufficient for the §9.3 validation command to run.
  `ci/good/workflow.yml` uses pinned action hash and `persist-credentials: false`.
