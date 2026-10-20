## GH-42-a — Map anti-slop into the catalogue; detect fabricated type evidence
**QA verdict: PASS** · UC coverage: 7/7 automated · Tests: 0 → 12 assertions · Skipped: 0

🤖 Written by an agent from `specs/GH-42-a/spec.md`. Review the spec's `Out:` scope first —
that is where an unattended run is most likely to have overstepped.

Part of #42

### What the spec asked for

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | maintainer | `bash tests/catalog_test.sh` | passes; D36 table has exactly 23 rows; every GH-42-a `added as`/`covered by` id in `catalog.yaml` | unit |
| UC-2 | maintainer | `slopguard doctor --install --all`, then `scripts/validate-configs` | eslint reports `PASS`; `@spacemansh/anti-slop` 0.3.0 installed | integration |
| UC-3 | agent | writes `const x = (y as unknown) as Foo;` | fast tier reports `AP-TS-MAINT-005` from `anti-slop/no-chained-type-assertions` | integration |
| UC-4 | agent | writes `const id = value as UserId;` with no comment above | fast tier reports `AP-TS-MAINT-005` from `anti-slop/require-safety-comment-for-type-assertion` | integration |
| UC-5 | agent | writes a known object widened to `unknown` then asserted | fast tier reports `AP-TS-MAINT-006` | integration |
| UC-6 | agent | good fixture: `as const` chains and `// SAFETY:` comments | no `AP-TS-MAINT-005` or `AP-TS-MAINT-006` finding | integration |
| UC-7 | maintainer | `scripts/gen-skills --check` | exit 0; `reference/AP-TS-MAINT-005.md` and `-006.md` exist with `bad`/`good` blocks | unit |

### How to verify

```bash
# UC-1, UC-2, UC-7
bash plugins/slop-guard/tests/catalog_test.sh

# UC-3, UC-4, UC-5, UC-6 (requires eslint-stack)
slopguard doctor --install --all
bash plugins/slop-guard/tests/integration/fast.sh

# Full validate
CI= make validate
make selftest
```

Verify report: `specs/GH-42-a/verify-report.md` — `CI= make validate` PASS, `make selftest` PASS (head `ab96e04`).

### Review here first

- `plugins/slop-guard/configs/baseline/eslint.config.mjs:83–86` — four new ESLint rules added at `warn`; review the import of `@spacemansh/anti-slop/eslint` and its plugin registration in the TypeScript block.
- `plugins/slop-guard/rules/catalog.yaml:1304–1345` — two new catalogue entries `AP-TS-MAINT-005` and `AP-TS-MAINT-006`; verify CWE list and severity match the spec's mapping table.
- `plugins/slop-guard/tools/node/package.json` + `package-lock.json` — new dependency `@spacemansh/anti-slop@0.3.0`; confirm no transitive runtime dependencies and integrity hash present in lockfile.

### Not covered

Nothing. All 7 UCs have automated coverage. UC-3/4/5/6 require `eslint-stack`; they skip cleanly without it and pass under `slopguard doctor --install --all` (auto-qa agent verified). One non-blocking informational finding: `.gitignore` adds `plugins/slop-guard/sessions/` (not in scope but harmless).
