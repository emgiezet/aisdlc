.PHONY: help validate validate-slopguard selftest sandbox harness-eval eval-dry templates \
        bump-patch bump-minor bump-major bump-slopguard

PLUGIN_JSON          := plugins/sdlc/.claude-plugin/plugin.json
SLOPGUARD_PLUGIN_JSON := plugins/slop-guard/.claude-plugin/plugin.json
PORTABLE_SDLC_JSON   := plugins/sdlc/plugin.json
PORTABLE_SLOPGUARD_JSON := plugins/slop-guard/plugin.json
MARKETPLACE_JSON     := .claude-plugin/marketplace.json
CODEX_MARKETPLACE    := .agents/plugins/marketplace.json
GROK_MARKETPLACE     := .grok-plugin/marketplace.json
SANDBOX_DIR := $(or $(TMPDIR),/tmp)/aisdlc-sandbox
SCRIPTS := plugins/sdlc/hooks/run-hook.cmd plugins/sdlc/hooks/session-start \
           plugins/sdlc/hooks/guard plugins/sdlc/bin/aisdlc \
           evals/harness/run.sh evals/harness/selftest.sh evals/harness/stub-claude
WORKFLOW_SKILLS := init spec mockup implement qa ship
SKILLS := spec-authoring task-router dense-testing harness-eval
PLAYBOOKS := api-endpoint db-change ui-feature service infra-change testing

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

validate: validate-slopguard ## Validate manifests, required files, and shell scripts
	@echo "Validating JSON..."
	@jq . $(MARKETPLACE_JSON) > /dev/null && echo "  ✓ .claude-plugin/marketplace.json"
	@jq . $(PLUGIN_JSON) > /dev/null && echo "  ✓ sdlc/.claude-plugin/plugin.json"
	@jq . $(PORTABLE_SDLC_JSON) > /dev/null && echo "  ✓ plugins/sdlc/plugin.json"
	@jq . $(CODEX_MARKETPLACE) > /dev/null && echo "  ✓ .agents/plugins/marketplace.json"
	@jq . $(GROK_MARKETPLACE) > /dev/null && echo "  ✓ .grok-plugin/marketplace.json"
	@jq . plugins/sdlc/hooks/hooks.json > /dev/null && echo "  ✓ sdlc hooks.json"
	@for f in evals/harness/scenarios/*/scenario.json; do \
		jq . "$$f" > /dev/null && echo "  ✓ $$f"; \
	done
	@echo "Checking source paths and name consistency across all marketplaces..."
	@for plugin in sdlc slop-guard; do \
		codex_path=$$(jq -r ".plugins[] | select(.name==\"$$plugin\") | .source.path" $(CODEX_MARKETPLACE)); \
		test -n "$$codex_path" \
			|| (echo "  ✗ $$plugin: not found in Codex marketplace" && exit 1); \
		codex_dir="$${codex_path#./}"; \
		test -d "$$codex_dir" \
			|| (echo "  ✗ $$plugin: Codex source.path $$codex_path not found" && exit 1); \
		test -f "$$codex_dir/plugin.json" \
			|| (echo "  ✗ $$plugin: $$codex_dir/plugin.json missing" && exit 1); \
		mname=$$(jq -r '.name' "$$codex_dir/plugin.json"); \
		test "$$mname" = "$$plugin" \
			|| (echo "  ✗ $$plugin: manifest name '$$mname' != marketplace entry" && exit 1); \
		echo "  ✓ Codex: $$plugin → $$codex_dir (name: $$mname)"; \
		grok_path=$$(jq -r ".plugins[] | select(.name==\"$$plugin\") | .source.path" $(GROK_MARKETPLACE)); \
		test -n "$$grok_path" \
			|| (echo "  ✗ $$plugin: not found in Grok marketplace" && exit 1); \
		grok_dir="$${grok_path#./}"; \
		test -d "$$grok_dir" \
			|| (echo "  ✗ $$plugin: Grok source.path $$grok_path not found" && exit 1); \
		test -f "$$grok_dir/plugin.json" \
			|| (echo "  ✗ $$plugin: $$grok_dir/plugin.json missing" && exit 1); \
		grok_mname=$$(jq -r '.name' "$$grok_dir/plugin.json"); \
		test "$$grok_mname" = "$$plugin" \
			|| (echo "  ✗ $$plugin: Grok manifest name '$$grok_mname' != marketplace entry" && exit 1); \
		echo "  ✓ Grok: $$plugin → $$grok_dir (name: $$grok_mname)"; \
	done
	@SDLC_CLAUDE_V=$$(jq -r '.version' $(PLUGIN_JSON)); \
	 SDLC_PORT_V=$$(jq -r '.version' $(PORTABLE_SDLC_JSON)); \
	 SDLC_MKT_V=$$(jq -r '.plugins[] | select(.name=="sdlc") | .version' $(MARKETPLACE_JSON)); \
	 SDLC_GROK_V=$$(jq -r '.plugins[] | select(.name=="sdlc") | .version' $(GROK_MARKETPLACE)); \
	 test "$$SDLC_CLAUDE_V" = "$$SDLC_PORT_V" \
	   && test "$$SDLC_CLAUDE_V" = "$$SDLC_MKT_V" \
	   && test "$$SDLC_CLAUDE_V" = "$$SDLC_GROK_V" \
	   && echo "  ✓ sdlc version consistent ($$SDLC_CLAUDE_V)" \
	   || (echo "  ✗ sdlc version mismatch: claude=$$SDLC_CLAUDE_V portable=$$SDLC_PORT_V marketplace=$$SDLC_MKT_V grok=$$SDLC_GROK_V" && exit 1)
	@echo "Checking required files..."
	@for c in $(WORKFLOW_SKILLS); do \
		test -f plugins/sdlc/skills/$$c/SKILL.md && echo "  ✓ skills/$$c/SKILL.md" || \
		(echo "  ✗ skills/$$c/SKILL.md MISSING" && exit 1); \
	done
	@for s in $(SKILLS); do \
		test -f plugins/sdlc/skills/$$s/SKILL.md && echo "  ✓ skills/$$s/SKILL.md" || \
		(echo "  ✗ skills/$$s/SKILL.md MISSING" && exit 1); \
		test -f plugins/sdlc/skills/$$s/agents/eval-set.json || \
		(echo "  ✗ skills/$$s/agents/eval-set.json MISSING" && exit 1); \
	done
	@test -f plugins/sdlc/agents/auto-qa.md && echo "  ✓ agents/auto-qa.md" || \
		(echo "  ✗ agents/auto-qa.md MISSING" && exit 1)
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
	@echo "Checking shell scripts..."
	@for s in $(SCRIPTS); do \
		bash -n "$$s" || (echo "  ✗ $$s SYNTAX ERROR" && exit 1); \
		test -x "$$s" || (echo "  ✗ $$s NOT EXECUTABLE" && exit 1); \
		echo "  ✓ $$s"; \
	done
	@command -v shellcheck > /dev/null 2>&1 && \
		(shellcheck -S warning plugins/sdlc/hooks/guard plugins/sdlc/hooks/session-start \
		            plugins/sdlc/bin/aisdlc evals/harness/run.sh evals/harness/selftest.sh \
		            evals/harness/stub-claude && echo "  ✓ shellcheck clean") || \
		echo "  – shellcheck not installed, skipped"
	@echo "All checks passed."

validate-slopguard: ## Validate the slop-guard plugin, if present
	@set -e; \
	test -d plugins/slop-guard \
		|| (echo "  ✗ plugins/slop-guard missing — bundled plugin is required" && exit 1); \
	jq . plugins/slop-guard/.claude-plugin/plugin.json > /dev/null && echo "  ✓ slopguard plugin.json"; \
	jq . plugins/slop-guard/hooks/hooks.json > /dev/null && echo "  ✓ slopguard hooks.json"; \
	jq . plugins/slop-guard/tools/tools.lock.json > /dev/null && echo "  ✓ slopguard tools.lock.json"; \
	test "$$(jq -r '.name' plugins/slop-guard/.claude-plugin/plugin.json)" = "slop-guard" \
		|| (echo "  ✗ slopguard plugin name mismatch" && exit 1); \
	test "$$(jq -r '.version' plugins/slop-guard/.claude-plugin/plugin.json)" = \
	     "$$(jq -r '.plugins[] | select(.name == "slop-guard") | .version' .claude-plugin/marketplace.json)" \
		&& echo "  ✓ slopguard Claude adapter version consistent" \
		|| (echo "  ✗ slopguard plugin and marketplace versions disagree" && exit 1); \
	jq . $(PORTABLE_SLOPGUARD_JSON) > /dev/null && echo "  ✓ plugins/slop-guard/plugin.json"; \
	test "$$(jq -r '.version' plugins/slop-guard/.claude-plugin/plugin.json)" = \
	     "$$(jq -r '.version' $(PORTABLE_SLOPGUARD_JSON))" \
		&& echo "  ✓ slopguard portable manifest version consistent" \
		|| (echo "  ✗ slopguard .claude-plugin and portable plugin.json versions disagree" && exit 1); \
	SG_GROK_V=$$(jq -r '.plugins[] | select(.name=="slop-guard") | .version' $(GROK_MARKETPLACE)); \
	test -n "$$SG_GROK_V" && test "$$SG_GROK_V" != "null" \
		|| (echo "  ✗ slop-guard not versioned in Grok marketplace" && exit 1); \
	test "$$SG_GROK_V" = "$$(jq -r '.version' plugins/slop-guard/.claude-plugin/plugin.json)" \
		&& echo "  ✓ slopguard Grok marketplace version consistent" \
		|| (echo "  ✗ slopguard Grok marketplace version disagrees" && exit 1); \
	jq -e '.plugins[] | select(.name == "slop-guard")' $(CODEX_MARKETPLACE) > /dev/null \
		&& echo "  ✓ slop-guard present in Codex marketplace" \
		|| (echo "  ✗ slop-guard missing from Codex marketplace" && exit 1); \
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
	plugins/slop-guard/scripts/validate-configs; \
	if command -v claude > /dev/null 2>&1; then \
		claude plugin validate plugins/slop-guard --strict; \
	else \
		echo "  – claude CLI not installed, plugin validate skipped"; \
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
	@jq '.version = "$(VERSION)"' $(PORTABLE_SDLC_JSON) > /tmp/portable-sdlc.json && mv /tmp/portable-sdlc.json $(PORTABLE_SDLC_JSON)
	@jq '(.plugins[] | select(.name == "sdlc") | .version) = "$(VERSION)" | .metadata.version = "$(VERSION)"' \
		$(MARKETPLACE_JSON) > /tmp/marketplace.json && mv /tmp/marketplace.json $(MARKETPLACE_JSON)
	@jq '(.plugins[] | select(.name == "sdlc") | .version) = "$(VERSION)"' \
		$(GROK_MARKETPLACE) > /tmp/grok-marketplace.json && mv /tmp/grok-marketplace.json $(GROK_MARKETPLACE)
	@echo "Version bumped to $(VERSION)"

bump-slopguard: ## Bump the slop-guard plugin patch version
	@$(MAKE) _bump-slopguard VERSION=$$(jq -r '.version' $(SLOPGUARD_PLUGIN_JSON) | awk -F. '{print $$1"."$$2"."$$3+1}')

_bump-slopguard:
ifndef VERSION
	$(error VERSION is required)
endif
	@jq '.version = "$(VERSION)"' $(SLOPGUARD_PLUGIN_JSON) > /tmp/plugin-sg.json && mv /tmp/plugin-sg.json $(SLOPGUARD_PLUGIN_JSON)
	@jq '.version = "$(VERSION)"' $(PORTABLE_SLOPGUARD_JSON) > /tmp/portable-sg.json && mv /tmp/portable-sg.json $(PORTABLE_SLOPGUARD_JSON)
	@jq '(.plugins[] | select(.name == "slop-guard") | .version) = "$(VERSION)"' \
		$(MARKETPLACE_JSON) > /tmp/marketplace-sg.json && mv /tmp/marketplace-sg.json $(MARKETPLACE_JSON)
	@jq '(.plugins[] | select(.name == "slop-guard") | .version) = "$(VERSION)"' \
		$(GROK_MARKETPLACE) > /tmp/grok-marketplace-sg.json && mv /tmp/grok-marketplace-sg.json $(GROK_MARKETPLACE)
	@echo "slop-guard version bumped to $(VERSION)"
