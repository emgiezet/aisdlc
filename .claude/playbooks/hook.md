# Playbook — Hook decision (allow / ask / deny / context)

Task-scoped. Reached from the Task Router in `CLAUDE.md`. Do not read sibling playbooks.
Hooks are the deterministic backbone: they decide before a command or write lands, whatever the
model intended. Load `agent-orchestration` → `references/deterministic-backbone.md` once if the
decision is new rather than a tweak.

## Where each decision lives

| Surface | Code | Policy text | Tests |
|---|---|---|---|
| sdlc guard (force push, `--no-verify`, `rm`, test deletion/skip at Stop) | `plugins/sdlc/hooks/guard` | `dense-testing` non-negotiables | `plugins/sdlc/tests/guard_stop_test.sh`, `grok_hook_test.sh` |
| slop-guard pre-bash / pre-write / pre-read / stop / post-write | `plugins/slop-guard/hooks/<event>` | `rules/policies/<event>.yaml`, `always-on.yaml` | `tests/{bash,write,read,stop}_test.sh` |
| decision helpers | `plugins/slop-guard/lib/hook.sh` (`hook_deny`, `hook_ask`, `hook_allow`, `hook_context`) | — | `tests/hook_test.sh` |
| banners | `plugins/*/hooks/session-start` | — | `tests/session_test.sh` |
| omp host | `plugins/*/extensions/omp.mjs` | — | `plugins/*/tests/omp_adapter_test.mjs` |

## Sequence

1. **Pick the tier by cost of a false positive.** `deny` for the irreversible (force push, `curl | sh`,
   secret read). `ask` only where a lowered bar is indistinguishable from a passing build — test
   gates, the guard's own config. Routine work gets `hook_context`, never a prompt: a gate that
   fires every day is answered without reading.
2. **Remember the hosts.** Headless, `ask` becomes `deny`; on Grok there is no ask, so it is deny;
   `CLAUDE_PLUGIN_OPTION_ENFORCEMENT_MODE=advisory` turns deny into context. Decide with all three
   in mind — a new `ask` is a new headless failure.
3. **Match on structure, not on a phrase.** Normalise the command or path first; a regex that a
   quoted argument, a `&&` chain or an env prefix walks past is a hole, and each such shape gets
   a test case.
4. **Change code, policy and spec together:** the hook, the `rules/policies/*.yaml` wording,
   `rules/catalog.yaml` for an `AP-AGENT-*` rule, and `docs/slop-guard-spec.md` §7.
5. **The omp adapter mirrors the shell hook.** If `extensions/omp.mjs` maps or re-implements the
   decision, change it in the same commit and extend `omp_adapter_test.mjs`.
6. **Changelog** — slop-guard: `CHANGELOG.md` `## Unreleased`; sdlc: `docs/ai-sdlc.md` where the
   behaviour is described.

## Test requirements

- One case per decision boundary: the input that must be denied, the nearest input that must be
  allowed, and each evasion shape from step 3. A changed tier moves the old expectation — never
  delete the case.
- JSON payloads in `plugins/slop-guard/tests/hook-contract/` are the wire format per event; add one
  for a new event or host shape.
- A live smoke: pipe a contract payload into the hook with scratch state and read the JSON it
  prints (no output, exit 0 = allow), editing `tool_input` to the case you changed:
  `CLAUDE_PLUGIN_DATA=$(mktemp -d) CLAUDE_PLUGIN_ROOT=$PWD/plugins/slop-guard plugins/slop-guard/hooks/pre-bash < plugins/slop-guard/tests/hook-contract/pre-tool-bash.json`

## Verify

The verification block in `.claude/rules/bash.md`; `.claude/rules/javascript.md` too when
`omp.mjs` changed.

## Done when

The tier matches step 1, every host behaves as intended, code/policy/catalogue/spec agree, each
boundary and evasion shape has a case, and both bash suites plus `CI= make validate` are green.
