.PHONY: help validate validate-slopguard selftest sandbox harness-eval eval-dry templates \
        bump-patch bump-minor bump-major bump-slopguard tool-integration

PLUGIN_JSON := plugins/sdlc/.claude-plugin/plugin.json
SLOPGUARD_PLUGIN_JSON := plugins/slop-guard/.claude-plugin/plugin.json
MARKETPLACE_JSON := .claude-plugin/marketplace.json
CODEX_MARKETPLACE    := .agents/plugins/marketplace.json
GROK_MARKETPLACE     := .grok-plugin/marketplace.json
PORTABLE_SDLC_JSON   := plugins/sdlc/plugin.json
OMP_MARKETPLACE      := .omp-plugin/marketplace.json
PORTABLE_SLOPGUARD_JSON := plugins/slop-guard/plugin.json
SANDBOX_DIR := $(or $(TMPDIR),/tmp)/aisdlc-sandbox
# Pass --strict to validate-configs in CI (GitHub Actions sets CI=true automatically).
CONFIG_STRICT := $(if $(CI),--strict,)
SCRIPTS := plugins/sdlc/hooks/run-hook.cmd plugins/sdlc/hooks/session-start \
           plugins/sdlc/hooks/guard plugins/sdlc/bin/aisdlc \
           evals/harness/run.sh evals/harness/selftest.sh evals/harness/stub-claude \
           evals/harness/stub-gh
COMMANDS := init spec mockup implement qa ship \
            review fix-pr review-prs autopilot continue merge merge-buddy followup close-fixed changelog \
            issue triage root-cause fix-issue \
            brainstorm discover synthetic-users backlog ux-shape ux-setup \
            test-env integration-tests ux-review retro arch-review
SKILLS := spec-authoring task-router dense-testing harness-eval pipeline-contracts code-review discovery architecture-review rest-api-design graphql-api-design
AGENTS := auto-qa code-reviewer
PLAYBOOKS := api-endpoint db-change ui-feature service infra-change testing graphql-api
TRACKERS := TEMPLATE github local
BROWSERS := TEMPLATE playwright agent-browser

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

validate: validate-slopguard ## Validate manifests, required files, and shell scripts
	@echo "Validating JSON..."
	@jq . $(MARKETPLACE_JSON) > /dev/null && echo "  ✓ marketplace.json"
	@jq . $(PLUGIN_JSON) > /dev/null && echo "  ✓ plugin.json"
	@jq . plugins/sdlc/hooks/hooks.json > /dev/null && echo "  ✓ hooks.json"
	@jq . $(CODEX_MARKETPLACE) > /dev/null && echo "  ✓ .agents/plugins/marketplace.json"
	@jq . $(GROK_MARKETPLACE) > /dev/null && echo "  ✓ .grok-plugin/marketplace.json"
	@jq . $(OMP_MARKETPLACE) > /dev/null && echo "  ✓ .omp-plugin/marketplace.json"
	@jq . $(PORTABLE_SDLC_JSON) > /dev/null && echo "  ✓ plugins/sdlc/plugin.json"
	@jq . $(PORTABLE_SLOPGUARD_JSON) > /dev/null && echo "  ✓ plugins/slop-guard/plugin.json"
	@for f in evals/harness/scenarios/*/scenario.json; do \
		jq . "$$f" > /dev/null && echo "  ✓ $$f"; \
	done
	@echo "Checking plugin name matches the command namespace..."
	@test "$$(jq -r '.name' $(PLUGIN_JSON))" = "$$(jq -r '.plugins[0].name' $(MARKETPLACE_JSON))" \
		&& echo "  ✓ plugin name consistent" \
		|| (echo "  ✗ plugin.json and marketplace.json disagree on the plugin name" && exit 1)
	@echo "Checking cross-marketplace consistency..."
	@set -e; for plugin in sdlc slop-guard; do \
		codex_path=$$(jq -r ".plugins[] | select(.name==\"$$plugin\") | .source.path" $(CODEX_MARKETPLACE)); \
		test -n "$$codex_path" && test "$$codex_path" != "null" \
			&& echo "  ✓ $$plugin: found in Codex marketplace" \
			|| (echo "  ✗ $$plugin: not found in Codex marketplace" && exit 1); \
		codex_dir="$${codex_path#./}"; \
		test -d "$$codex_dir" \
			&& echo "  ✓ $$plugin: Codex source.path $$codex_path resolves" \
			|| (echo "  ✗ $$plugin: Codex source.path $$codex_path not found" && exit 1); \
		manifest_name=$$(jq -r '.name' "$$codex_dir/plugin.json"); \
		test "$$manifest_name" = "$$plugin" \
			&& echo "  ✓ $$plugin: portable manifest name matches" \
			|| (echo "  ✗ $$plugin: portable manifest name '$$manifest_name' != '$$plugin'" && exit 1); \
		grok_path=$$(jq -r ".plugins[] | select(.name==\"$$plugin\") | .source.path" $(GROK_MARKETPLACE)); \
		test -n "$$grok_path" && test "$$grok_path" != "null" \
			&& echo "  ✓ $$plugin: found in Grok marketplace" \
			|| (echo "  ✗ $$plugin: not found in Grok marketplace" && exit 1); \
		grok_dir="$${grok_path#./}"; \
		test -d "$$grok_dir" \
			&& echo "  ✓ $$plugin: Grok source.path $$grok_path resolves" \
			|| (echo "  ✗ $$plugin: Grok source.path $$grok_path not found" && exit 1); \
		omp_src=$$(jq -r ".plugins[] | select(.name==\"$$plugin\") | .source" $(OMP_MARKETPLACE)); \
		test -n "$$omp_src" && test "$$omp_src" != "null" \
			&& echo "  ✓ $$plugin: found in omp marketplace" \
			|| (echo "  ✗ $$plugin: not found in omp marketplace" && exit 1); \
		omp_dir="$${omp_src#./}"; \
		test -d "$$omp_dir" \
			&& echo "  ✓ $$plugin: omp source $$omp_src resolves" \
			|| (echo "  ✗ $$plugin: omp source $$omp_src not found" && exit 1); \
		claude_v=$$(jq -r ".plugins[] | select(.name==\"$$plugin\") | .version" $(MARKETPLACE_JSON)); \
		portable_v=$$(jq -r '.version' "$$codex_dir/plugin.json"); \
		grok_v=$$(jq -r ".plugins[] | select(.name==\"$$plugin\") | .version" $(GROK_MARKETPLACE)); \
		omp_v=$$(jq -r ".plugins[] | select(.name==\"$$plugin\") | .version" $(OMP_MARKETPLACE)); \
		test "$$claude_v" = "$$portable_v" && test "$$claude_v" = "$$grok_v" && test "$$claude_v" = "$$omp_v" \
			&& echo "  ✓ $$plugin: version consistent across hosts ($$claude_v)" \
			|| (echo "  ✗ $$plugin: version mismatch — claude=$$claude_v portable=$$portable_v grok=$$grok_v omp=$$omp_v" && exit 1); \
	done
	@echo "Checking omp adapters..."
	@for plugin in sdlc slop-guard; do \
		pkg="plugins/$$plugin/package.json"; \
		if test -f "$$pkg"; then \
			jq . "$$pkg" > /dev/null && echo "  ✓ $$plugin/package.json"; \
			plugin_v=$$(jq -r '.version' "plugins/$$plugin/.claude-plugin/plugin.json"); \
			pkg_v=$$(jq -r '.version' "$$pkg"); \
			test "$$plugin_v" = "$$pkg_v" \
				&& echo "  ✓ $$plugin: package.json version matches plugin.json ($$pkg_v)" \
				|| (echo "  ✗ $$plugin: package.json version $$pkg_v != plugin.json $$plugin_v" && exit 1); \
			ext_path=$$(jq -r '.omp.extensions[0]' "$$pkg"); \
			ext_file="plugins/$$plugin/$${ext_path#./}"; \
			test -f "$$ext_file" \
				&& echo "  ✓ $$plugin: omp.extensions[0] $$ext_path exists" \
				|| (echo "  ✗ $$plugin: omp.extensions[0] $$ext_path not found" && exit 1); \
		else \
			echo "  – $$plugin/package.json absent, skipped"; \
		fi; \
	done
	@if command -v node > /dev/null 2>&1; then \
		for plugin in sdlc slop-guard; do \
			ext="plugins/$$plugin/extensions/omp.mjs"; \
			if test -f "$$ext"; then \
				node --check "$$ext" && echo "  ✓ $$ext syntax ok"; \
			else \
				echo "  – $$ext absent, skipped"; \
			fi; \
		done; \
	else \
		echo "  – node not installed, omp.mjs syntax checks skipped"; \
	fi
	@echo "Checking required files..."
	@for c in $(COMMANDS); do \
		test -f plugins/sdlc/commands/$$c.md && echo "  ✓ commands/$$c.md" || \
		(echo "  ✗ commands/$$c.md MISSING" && exit 1); \
	done
	@for s in $(SKILLS); do \
		test -f plugins/sdlc/skills/$$s/SKILL.md && echo "  ✓ skills/$$s/SKILL.md" || \
		(echo "  ✗ skills/$$s/SKILL.md MISSING" && exit 1); \
		test -f plugins/sdlc/skills/$$s/agents/eval-set.json || \
		(echo "  ✗ skills/$$s/agents/eval-set.json MISSING" && exit 1); \
	done
	@for a in $(AGENTS); do \
		test -f plugins/sdlc/agents/$$a.md && echo "  ✓ agents/$$a.md" || \
		(echo "  ✗ agents/$$a.md MISSING" && exit 1); \
	done
	@for t in $(TRACKERS); do \
		test -f plugins/sdlc/templates/trackers/$$t.md && echo "  ✓ templates/trackers/$$t.md" || \
		(echo "  ✗ templates/trackers/$$t.md MISSING" && exit 1); \
	done
	@for b in $(BROWSERS); do \
		test -f plugins/sdlc/templates/browsers/$$b.md && echo "  ✓ templates/browsers/$$b.md" || \
		(echo "  ✗ templates/browsers/$$b.md MISSING" && exit 1); \
	done
	@for p in $(PLAYBOOKS); do \
		test -f plugins/sdlc/templates/playbooks/$$p.md && echo "  ✓ templates/playbooks/$$p.md" || \
		(echo "  ✗ templates/playbooks/$$p.md MISSING" && exit 1); \
	done
	@test -f plugins/sdlc/templates/CLAUDE.md && test -f plugins/sdlc/templates/sdlc.md \
		&& echo "  ✓ templates/CLAUDE.md + templates/sdlc.md" \
		|| (echo "  ✗ a template is MISSING" && exit 1)
	@echo "Checking instruction budgets (task-router skill)..."
	@awk 'END { if (NR > 90) { print "  ✗ templates/CLAUDE.md is " NR " lines, budget 90"; exit 1 } \
		else print "  ✓ templates/CLAUDE.md " NR " lines" }' plugins/sdlc/templates/CLAUDE.md
	@for p in $(PLAYBOOKS); do \
		awk -v f="$$p" 'END { if (NR > 70) { print "  ✗ playbooks/" f " is " NR " lines, budget 70"; exit 1 } }' \
			plugins/sdlc/templates/playbooks/$$p.md || exit 1; \
	done
	@echo "  ✓ every playbook within 70 lines"
	@for c in $(COMMANDS); do \
		awk -v f="$$c" 'END { if (NR > 220) { print "  ✗ commands/" f ".md is " NR " lines, budget 220"; exit 1 } }' \
			plugins/sdlc/commands/$$c.md || exit 1; \
	done
	@echo "  ✓ every command within 220 lines"
	@for d in $(addprefix trackers/,$(TRACKERS)) $(addprefix browsers/,$(BROWSERS)); do \
		awk -v f="$$d" 'END { if (NR > 120) { print "  ✗ templates/" f ".md is " NR " lines, budget 120"; exit 1 } }' \
			plugins/sdlc/templates/$$d.md || exit 1; \
	done
	@echo "  ✓ every descriptor within 120 lines"
	@grep -rl 'TODO: SDLC-' plugins/sdlc/templates/browsers/ > /dev/null 2>&1 \
		&& (echo "  ✗ browser descriptor still has TODO bodies" && exit 1) \
		|| echo "  ✓ browser descriptors have no TODO bodies"
	@echo "Checking shell scripts..."
	@for s in $(SCRIPTS); do \
		bash -n "$$s" || (echo "  ✗ $$s SYNTAX ERROR" && exit 1); \
		test -x "$$s" || (echo "  ✗ $$s NOT EXECUTABLE" && exit 1); \
		echo "  ✓ $$s"; \
	done
	@command -v shellcheck > /dev/null 2>&1 && \
		(shellcheck -S warning plugins/sdlc/hooks/guard plugins/sdlc/hooks/session-start \
		            plugins/sdlc/bin/aisdlc evals/harness/run.sh evals/harness/selftest.sh \
		            evals/harness/stub-claude evals/harness/stub-gh && echo "  ✓ shellcheck clean") || \
		echo "  – shellcheck not installed, skipped"
	@if test -x plugins/sdlc/tests/run-tests; then \
		echo "Running sdlc hook tests..."; \
		plugins/sdlc/tests/run-tests; \
	fi
	@echo "All checks passed."

validate-slopguard: ## Validate the slop-guard plugin, if present
	@set -e; \
	test -d plugins/slop-guard || { echo "  – slop-guard not present, skipped"; exit 0; }; \
	jq . plugins/slop-guard/.claude-plugin/plugin.json > /dev/null && echo "  ✓ slopguard plugin.json"; \
	jq . plugins/slop-guard/hooks/hooks.json > /dev/null && echo "  ✓ slopguard hooks.json"; \
	jq . plugins/slop-guard/tools/tools.lock.json > /dev/null && echo "  ✓ slopguard tools.lock.json"; \
	if [ -f plugins/slop-guard/rules/stacks.json ]; then \
		jq . plugins/slop-guard/rules/stacks.json > /dev/null \
			&& echo "  ✓ slopguard stacks.json"; \
		jq -e '[to_entries[] | select(.value.tier != 1 and .value.tier != 2)] | length == 0' \
			plugins/slop-guard/rules/stacks.json > /dev/null \
			&& echo "  ✓ stacks.json: all tiers valid (1 or 2)" \
			|| (echo "  ✗ stacks.json: entry with invalid tier found" && exit 1); \
		jq -e '[to_entries[] | select((.value.anchors.files // [] | length == 0) and (.value.anchors.globs // [] | length == 0) and (.value.anchors.dirs // [] | length == 0) and (.value.anchors.manifest // {} | length == 0))] | length == 0' \
			plugins/slop-guard/rules/stacks.json > /dev/null \
			&& echo "  ✓ stacks.json: all entries have non-empty anchors" \
			|| (echo "  ✗ stacks.json: entry with empty or missing anchors found" && exit 1); \
		jq -e '(keys | map({(.): true}) | add) as $$known | [to_entries[] | select(.value.requires != null and .value.requires != "") | select($$known[.value.requires] == null)] | length == 0' \
			plugins/slop-guard/rules/stacks.json > /dev/null \
			&& echo "  ✓ stacks.json: requires refs are valid" \
			|| (echo "  ✗ stacks.json: requires references an unknown tag" && exit 1); \
		jq -e '(keys | map({(.): true}) | add) as $$known | [to_entries[] | (.value.implies // [])[] | select($$known[.] == null)] | length == 0' \
			plugins/slop-guard/rules/stacks.json > /dev/null \
			&& echo "  ✓ stacks.json: implies refs are valid" \
			|| (echo "  ✗ stacks.json: implies references an unknown tag" && exit 1); \
		jq -e '[to_entries[] | select(.value.context7 != null) | select((.value.context7 | type) != "string" or (.value.context7 | length) == 0)] | length == 0' \
			plugins/slop-guard/rules/stacks.json > /dev/null \
			&& echo "  ✓ stacks.json: context7 values are non-empty strings" \
			|| (echo "  ✗ stacks.json: context7 field empty or wrong type" && exit 1); \
	fi; \
	if [ -f plugins/slop-guard/rules/registries.json ]; then \
		jq . plugins/slop-guard/rules/registries.json > /dev/null \
			&& echo "  ✓ slopguard registries.json"; \
		jq -e '[to_entries[] | select((.value.url // "" | length) == 0)] | length == 0' \
			plugins/slop-guard/rules/registries.json > /dev/null \
			&& echo "  ✓ registries.json: all entries have non-empty url" \
			|| (echo "  ✗ registries.json: entry with empty or missing url" && exit 1); \
		jq -e '[to_entries[] | select((.value.latest_jq // "" | length) == 0)] | length == 0' \
			plugins/slop-guard/rules/registries.json > /dev/null \
			&& echo "  ✓ registries.json: all entries have non-empty latest_jq" \
			|| (echo "  ✗ registries.json: entry with empty or missing latest_jq" && exit 1); \
		jq -e '[to_entries[] | select((.value.published_jq // "" | length) == 0)] | length == 0' \
			plugins/slop-guard/rules/registries.json > /dev/null \
			&& echo "  ✓ registries.json: all entries have non-empty published_jq" \
			|| (echo "  ✗ registries.json: entry with empty or missing published_jq" && exit 1); \
		jq -e '[to_entries[] | select((.value.manifests // [] | length) == 0)] | length == 0' \
			plugins/slop-guard/rules/registries.json > /dev/null \
			&& echo "  ✓ registries.json: all entries have non-empty manifests" \
			|| (echo "  ✗ registries.json: entry with empty or missing manifests" && exit 1); \
		jq -e '[to_entries[] | select(.value.url | contains("{package}") | not)] | length == 0' \
			plugins/slop-guard/rules/registries.json > /dev/null \
			&& echo "  ✓ registries.json: all urls contain {package}" \
			|| (echo "  ✗ registries.json: url missing {package} placeholder" && exit 1); \
	fi; \
	test "$$(jq -r '.name' plugins/slop-guard/.claude-plugin/plugin.json)" = "slop-guard" \
		|| (echo "  ✗ slopguard plugin name mismatch" && exit 1); \
	test "$$(jq -r '.version' plugins/slop-guard/.claude-plugin/plugin.json)" = \
	     "$$(jq -r '.plugins[] | select(.name == "slop-guard") | .version' .claude-plugin/marketplace.json)" \
		&& echo "  ✓ slopguard version consistent" \
		|| (echo "  ✗ slopguard plugin and marketplace versions disagree" && exit 1); \
	jq . $(PORTABLE_SLOPGUARD_JSON) > /dev/null && echo "  ✓ plugins/slop-guard/plugin.json (portable)"; \
	test "$$(jq -r '.version' plugins/slop-guard/.claude-plugin/plugin.json)" = \
	     "$$(jq -r '.version' $(PORTABLE_SLOPGUARD_JSON))" \
		&& echo "  ✓ slopguard portable version consistent" \
		|| (echo "  ✗ slopguard .claude-plugin and portable plugin.json versions disagree" && exit 1); \
	for s in plugins/slop-guard/bin/slopguard plugins/slop-guard/hooks/session-start \
	          plugins/slop-guard/hooks/pre-* \
	          plugins/slop-guard/lib/*.sh plugins/slop-guard/tests/run-tests \
	          plugins/slop-guard/tests/*.sh; do \
		bash -n "$$s" || (echo "  ✗ $$s SYNTAX ERROR" && exit 1); \
	done; \
	echo "  ✓ slopguard shell syntax"; \
	if command -v shellcheck > /dev/null 2>&1; then \
		shellcheck -S warning plugins/slop-guard/bin/slopguard \
		            plugins/slop-guard/hooks/session-start plugins/slop-guard/hooks/pre-* \
		            plugins/slop-guard/lib/*.sh \
		            plugins/slop-guard/tests/run-tests plugins/slop-guard/tests/*.sh; \
		echo "  ✓ slopguard shellcheck clean"; \
	else \
		echo "  – shellcheck not installed, skipped"; \
	fi; \
	plugins/slop-guard/tests/run-tests; \
	plugins/slop-guard/scripts/validate-configs $(CONFIG_STRICT); \
	if command -v claude > /dev/null 2>&1; then \
		claude plugin validate plugins/slop-guard --strict; \
	else \
		echo "  – claude CLI not installed, plugin validate skipped"; \
	fi

# CI runs this step after installing the pinned toolchain via slopguard doctor --install.
tool-integration: ## Run parser integration tests against real tool binaries (CI-only; skips per tool when absent)
	@if test -x plugins/slop-guard/tests/tool-integration; then \
		plugins/slop-guard/tests/tool-integration; \
	else \
		echo "  – plugins/slop-guard/tests/tool-integration not found or not executable, skipping"; \
	fi

selftest: ## Verify the queue runner against a stub claude (no API calls, no cost)
	@evals/harness/selftest.sh

sandbox: ## Instantiate the eval sandbox with its approved specs → $(SANDBOX_DIR)
	@rm -rf "$(SANDBOX_DIR)"
	@mkdir -p "$(dir $(SANDBOX_DIR))"
	@cp -R evals/fixtures/sandbox "$(SANDBOX_DIR)"
	@for d in evals/harness/scenarios/*/; do \
		ticket=$$(jq -r '.ticket' "$$d/scenario.json"); \
		mkdir -p "$(SANDBOX_DIR)/specs/$$ticket"; \
		cp "$$d/spec.md" "$(SANDBOX_DIR)/specs/$$ticket/spec.md"; \
	done
	@cd "$(SANDBOX_DIR)" && git init -q -b main && \
		git config user.email sandbox@localhost && git config user.name "aisdlc sandbox" && \
		git add -A && git commit -q -m "chore: sandbox baseline with approved specs" && \
		git update-ref refs/remotes/origin/main HEAD
	@echo "Sandbox ready at $(SANDBOX_DIR)"
	@echo "  approved specs: $$(ls $(SANDBOX_DIR)/specs | tr '\n' ' ')"
	@echo ""
	@echo "  cd $(SANDBOX_DIR) && make verify        # baseline must be green"
	@echo "  aisdlc add SBX-1 --repo $(SANDBOX_DIR) --model haiku --no-pr --plugin-dir"
	@echo "  aisdlc run --repo $(SANDBOX_DIR) --once"

harness-eval: ## Run the harness eval: make harness-eval MODEL=haiku [SCENARIO=go-endpoint]
	@evals/harness/run.sh --model "$(or $(MODEL),sonnet)" \
		$(if $(SCENARIO),--scenario $(SCENARIO),) $(if $(KEEP),--keep,)

eval-dry: ## Spot-check the skill trigger eval sets locally (no API calls)
	@for f in plugins/sdlc/skills/*/agents/eval-set.json; do \
		name=$${f#plugins/sdlc/skills/}; name=$${name%/agents/eval-set.json}; \
		if jq empty "$$f" 2>/dev/null; then \
			t=$$(jq '[.[] | select(.should_trigger == true)]  | length' "$$f"); \
			f2=$$(jq '[.[] | select(.should_trigger == false)] | length' "$$f"); \
			printf "  ✓ %-16s trigger:%d  no-trigger:%d\n" "$$name" "$$t" "$$f2"; \
		else \
			printf "  ✗ %-16s INVALID JSON\n" "$$name"; exit 1; \
		fi; \
	done

templates: ## Copy raw templates into a project (no agent): make templates TARGET=~/code/app
ifndef TARGET
	$(error TARGET is required. Usage: make templates TARGET=/path/to/project)
endif
	@mkdir -p "$(TARGET)/.claude/playbooks" "$(TARGET)/.claude/rules" "$(TARGET)/specs"
	@cp -n plugins/sdlc/templates/CLAUDE.md "$(TARGET)/CLAUDE.md" 2>/dev/null || \
		echo "  kept existing $(TARGET)/CLAUDE.md"
	@cp -n plugins/sdlc/templates/sdlc.md "$(TARGET)/.claude/sdlc.md" 2>/dev/null || \
		echo "  kept existing $(TARGET)/.claude/sdlc.md"
	@cp -n plugins/sdlc/templates/playbooks/*.md "$(TARGET)/.claude/playbooks/" 2>/dev/null || true
	@echo "Templates copied to $(TARGET) — they still contain placeholders."
	@echo "Fill them in, delete the playbooks this repo has no use for, and write .claude/rules/."
	@echo "The better path is /sdlc:init, which writes all of this calibrated to the repo."

bump-patch: ## Bump patch version
	@$(MAKE) _bump VERSION=$$(jq -r '.version' $(PLUGIN_JSON) | awk -F. '{print $$1"."$$2"."$$3+1}')

bump-minor: ## Bump minor version
	@$(MAKE) _bump VERSION=$$(jq -r '.version' $(PLUGIN_JSON) | awk -F. '{print $$1"."$$2+1".0"}')

bump-major: ## Bump major version
	@$(MAKE) _bump VERSION=$$(jq -r '.version' $(PLUGIN_JSON) | awk -F. '{print $$1+1".0.0"}')

_bump:
ifndef VERSION
	$(error VERSION is required)
endif
	@jq '.version = "$(VERSION)"' $(PLUGIN_JSON) > /tmp/plugin.json && mv /tmp/plugin.json $(PLUGIN_JSON)
	@jq '(.plugins[] | select(.name == "sdlc") | .version) = "$(VERSION)" | .metadata.version = "$(VERSION)"' \
		$(MARKETPLACE_JSON) > /tmp/marketplace.json && mv /tmp/marketplace.json $(MARKETPLACE_JSON)
	@jq '.version = "$(VERSION)"' $(PORTABLE_SDLC_JSON) > /tmp/portable-sdlc.json && mv /tmp/portable-sdlc.json $(PORTABLE_SDLC_JSON)
	@jq '(.plugins[] | select(.name == "sdlc") | .version) = "$(VERSION)"' \
		$(GROK_MARKETPLACE) > /tmp/grok-marketplace.json && mv /tmp/grok-marketplace.json $(GROK_MARKETPLACE)
	@jq '(.plugins[] | select(.name == "sdlc") | .version) = "$(VERSION)" | .metadata.version = "$(VERSION)"' \
		$(OMP_MARKETPLACE) > /tmp/omp-marketplace.json && mv /tmp/omp-marketplace.json $(OMP_MARKETPLACE)
	@jq '.version = "$(VERSION)"' plugins/sdlc/package.json > /tmp/sdlc-pkg.json && mv /tmp/sdlc-pkg.json plugins/sdlc/package.json
	@echo "Version bumped to $(VERSION)"

bump-slopguard: ## Bump the slop-guard plugin patch version
	@$(MAKE) _bump-slopguard VERSION=$$(jq -r '.version' $(SLOPGUARD_PLUGIN_JSON) | awk -F. '{print $$1"."$$2"."$$3+1}')

_bump-slopguard:
ifndef VERSION
	$(error VERSION is required)
endif
	@jq '.version = "$(VERSION)"' $(SLOPGUARD_PLUGIN_JSON) > /tmp/plugin-sg.json && mv /tmp/plugin-sg.json $(SLOPGUARD_PLUGIN_JSON)
	@jq '(.plugins[] | select(.name == "slop-guard") | .version) = "$(VERSION)"' \
		$(MARKETPLACE_JSON) > /tmp/marketplace-sg.json && mv /tmp/marketplace-sg.json $(MARKETPLACE_JSON)
	@jq '.version = "$(VERSION)"' $(PORTABLE_SLOPGUARD_JSON) > /tmp/portable-sg.json && mv /tmp/portable-sg.json $(PORTABLE_SLOPGUARD_JSON)
	@jq '(.plugins[] | select(.name == "slop-guard") | .version) = "$(VERSION)"' \
		$(GROK_MARKETPLACE) > /tmp/grok-sg.json && mv /tmp/grok-sg.json $(GROK_MARKETPLACE)
	@jq '(.plugins[] | select(.name == "slop-guard") | .version) = "$(VERSION)"' \
		$(OMP_MARKETPLACE) > /tmp/omp-marketplace-sg.json && mv /tmp/omp-marketplace-sg.json $(OMP_MARKETPLACE)
	@jq '.version = "$(VERSION)"' plugins/slop-guard/package.json > /tmp/slopguard-pkg.json && mv /tmp/slopguard-pkg.json plugins/slop-guard/package.json
	@echo "slop-guard version bumped to $(VERSION)"
