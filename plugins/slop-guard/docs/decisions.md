# Slop Guard — Design Decisions

Date confirmed: **2026-09-16**

---

## Blocking Decisions (confirmed before Stage 1)

| # | Decision | Answer | Date | Consequence |
|---|---|---|---|---|
| D1 | Dispatcher language | **bash + `jq`** | 2026-09-16 | No compiled artefact, no cross-compilation, no release matrix. `jq` becomes a pinned dependency (Task 0.2). Tests are bash assertions, not `go test`. Windows support is a wrapper problem deferred to Stage 6 and recorded as a known limitation. |
| D2 | SAST engine | **Opengrep** (`sast_engine=semgrep\|none` still works) | 2026-09-16 | Own rules are kept in the syntax both Opengrep and Semgrep CE parse. Taint-mode rules are marked in the catalogue so a `semgrep` fallback degrades visibly, not silently. |
| D10 | Target CI system | **GitHub Actions** | 2026-09-16 | Stage 2 implements `actionlint` + `zizmor` with `unpinned-uses: hash-pin`. The GitLab Opengrep rule set (§6.9) moves behind Stage 2, and AP-CI-006 ships in Stage 3 or later. |

### Why Opengrep rather than Semgrep CE

The rules that need dataflow tracking are the ones no other tool in the matrix covers. PHP has Psalm taint and Go has `gosec`; Python, TypeScript and Node have nothing free that tracks `req.body` to a sink. AP-NODE-SEC-001, AP-PY-SEC-001 and AP-TS-SEC-004 are precisely those, and Opengrep keeps intra-file taint in the open-source engine while Semgrep moved it behind the paid tier.

The rule format and JSON/SARIF output are identical, so `sast_engine` stays a one-word switch rather than a rewrite. Neither engine changes the licence problem — Semgrep Registry rules cannot be shipped either way, so the plugin writes its own rules regardless. Opengrep costs nothing extra here.

The risk is maintenance, not capability: the fork is young and small. Mitigations: pin it by sha256 like every other binary, and keep every own rule inside the syntax Semgrep CE also parses, verified by running `scripts/validate-configs` with `sast_engine=semgrep`.

---

## Non-Blocking Decisions (taken at the spec's recommendation)

| # | Decision | Answer | Consequence |
|---|---|---|---|
| D3 | Default enforcement mode | **balanced** | `strict` for repos with high requirements (payment/personal-data modules). `advisory` available for low-friction onboarding. |
| D4 | Stop gate blocking behaviour | **Blocks on blockers only; at most 2 iterations** | The Stop handler checks `stop_hook_active` and gives up after 2 failed iterations, leaving a summary for the user. Only `error`-severity findings block; warnings do not. |
| D5 | Trivy / KICS | **Off by default** | Checkov + tflint + kube-linter cover the same scope without the maintenance overhead. Can be enabled via project config if needed. |
| D6 | JS/TS linter | **ESLint + typescript-eslint** | Type-aware rules (`no-floating-promises`, etc.) are enabled. Biome/Oxlint as a fast tier-F option is recorded in `docs/ideas.md` for consideration if performance becomes a problem. |
| D7 | Python type checker | **Project's own type checker; Pyright (standard mode) as fallback** | If the project ships a `pyrightconfig.json` or `pyproject.toml [tool.pyright]`, that configuration is used. Otherwise Pyright runs in standard mode. |
| D8 | Network in fast path | **`allow_network=false` by default** | SCA runs in CI rather than in the plugin until a local vulnerability-database mirror is available. Users may set `allow_network=true` to enable SCA in the Stop gate. |
| D9 | Overlap with `security-guidance` / Claude Security | **No LLM-review duplication** | If `security-guidance` is enabled, `/slop-guard:secure-review` defers to it instead of launching an independent LLM review. Deterministic tool findings are always reported regardless. |

---

## Open Decisions

| # | Decision | Status | Interim default | Notes |
|---|---|---|---|---|
| D11 | Default SQL dialect | **Open** (blocks nothing before Stage 2) | **postgres** | MySQL has no equivalent of `squawk`, which means more custom rules and a larger skill. Until this is answered, `squawk` runs only on PostgreSQL migrations. The answer determines the scope of Stage 2's SQL tooling. |
