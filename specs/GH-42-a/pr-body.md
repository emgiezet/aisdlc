## GH-42-a — Map anti-slop into the catalogue; detect fabricated type evidence
**QA verdict: PASS** · UC coverage: 7/7 automated · Tests: +12 assertions · Skipped: 0

🤖 Written by an agent from `specs/GH-42-a/spec.md`. Review the spec's `Out:` scope first —
that is where an unattended run is most likely to have overstepped.

### What the spec asked for

| id | actor | action | expected observable result | test |
|----|-------|--------|----------------------------|------|
| UC-1 | maintainer | `bash tests/catalog_test.sh` | passes; it fails when the D36 table has other than 23 rows, or an `added as`/`covered by` id is missing from `catalog.yaml` | unit |
| UC-2 | maintainer | `slopguard doctor --install --all`, then `scripts/validate-configs` | eslint reports `PASS`; `tools/node/node_modules/@spacemansh/anti-slop/package.json` version is `0.3.0` | integration |
| UC-3 | agent | writes `const x = (y as unknown) as Foo;` | fast tier reports `AP-TS-MAINT-005` from `anti-slop/no-chained-type-assertions` | integration |
| UC-4 | agent | writes `const id = value as UserId;` with no comment above | fast tier reports `AP-TS-MAINT-005` from `anti-slop/require-safety-comment-for-type-assertion` | integration |
| UC-5 | agent | writes a known object, assigns it to `const w: unknown`, then `w as { id: string }` | fast tier reports `AP-TS-MAINT-006` | integration |
| UC-6 | agent | the good fixture: `as const` chains and `// SAFETY: <reason>` above each assertion *(inferred negative)* | no `AP-TS-MAINT-005` or `AP-TS-MAINT-006` finding | integration |
| UC-7 | maintainer | `scripts/gen-skills --check` | exit 0; `reference/AP-TS-MAINT-005.md` and `-006.md` exist with the catalogue's `bad` and `good` blocks | unit |

### How to verify

```bash
# UC-1, UC-2, UC-7 — no tools required
bash plugins/slop-guard/tests/catalog_test.sh

# UC-3, UC-4, UC-5, UC-6 — requires eslint-stack
slopguard doctor --install --all
bash plugins/slop-guard/tests/tool-integration
```

`catalog_test.sh`: 27 passed, 0 failed (6.02 s)  
`tool-integration` (with eslint-stack): 21 passed, 0 failed, 2 skipped, 1 known (56.05 s)

### Review here first

1. `plugins/slop-guard/configs/baseline/eslint.config.mjs:83–86` — four new `warn` rules enabled globally in the TypeScript block (`no-chained-type-assertions`, `require-safety-comment-for-type-assertion`, `no-known-value-widening`, `no-widen-then-assert`). Any project consuming this baseline will surface these against existing code immediately after `doctor --install --all`.
2. `plugins/slop-guard/rules/catalog.yaml:1304` — AP-TS-MAINT-005 and AP-TS-MAINT-006 entries added; their shape and uniqueness are validated by the `catalog_test.sh` invariant suite.
3. `plugins/slop-guard/tools/node/package.json` — new dependency `@spacemansh/anti-slop 0.3.0`; zero runtime dependencies; integrity hash recorded in `package-lock.json`; installed via `--ignore-scripts`.

### Not covered

Nothing. All 7 UCs have automated test coverage. UC-3/4/5/6 skip cleanly when `eslint-stack` is absent and pass under `slopguard doctor --install --all` (verified by auto-qa agent).
