.PHONY: help validate validate-slopguard selftest sandbox harness-eval eval-dry templates \
        bump-patch bump-minor bump-major bump-slopguard

PLUGIN_JSON := plugins/sdlc/.claude-plugin/plugin.json
SLOPGUARD_PLUGIN_JSON := plugins/slop-guard/.claude-plugin/plugin.json
MARKETPLACE_JSON := .claude-plugin/marketplace.json
SANDBOX_DIR := $(or $(TMPDIR),/tmp)/aisdlc-sandbox
SCRIPTS := plugins/sdlc/hooks/run-hook.cmd plugins/sdlc/hooks/session-start \
           plugins/sdlc/hooks/guard plugins/sdlc/bin/aisdlc \
           evals/harness/run.sh evals/harness/selftest.sh evals/harness/stub-claude
COMMANDS := init spec mockup implement qa ship
SKILLS := spec-authoring task-router dense-testing harness-eval
PLAYBOOKS := api-endpoint db-change ui-feature service infra-change testing

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

validate: validate-slopguard ## Validate manifests, required files, and shell scripts
	@echo "Validating JSON..."
	@jq . $(MARKETPLACE_JSON) > /dev/null && echo "  ✓ marketplace.json"
	@jq . $(PLUGIN_JSON) > /dev/null && echo "  ✓ plugin.json"
	@jq . plugins/sdlc/hooks/hooks.json > /dev/null && echo "  ✓ hooks.json"
	@for f in evals/harness/scenarios/*/scenario.json; do \
		jq . "$$f" > /dev/null && echo "  ✓ $$f"; \
	done
	@echo "Checking plugin name matches the command namespace..."
	@test "$$(jq -r '.name' $(PLUGIN_JSON))" = "$$(jq -r '.plugins[0].name' $(MARKETPLACE_JSON))" \
		&& echo "  ✓ plugin name consistent" \
		|| (echo "  ✗ plugin.json and marketplace.json disagree on the plugin name" && exit 1)
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
	test -d plugins/slop-guard || { echo "  – slop-guard not present, skipped"; exit 0; }; \
	jq . plugins/slop-guard/.claude-plugin/plugin.json > /dev/null && echo "  ✓ slopguard plugin.json"; \
	jq . plugins/slop-guard/hooks/hooks.json > /dev/null && echo "  ✓ slopguard hooks.json"; \
	jq . plugins/slop-guard/tools/tools.lock.json > /dev/null && echo "  ✓ slopguard tools.lock.json"; \
	test "$$(jq -r '.name' plugins/slop-guard/.claude-plugin/plugin.json)" = "slop-guard" \
		|| (echo "  ✗ slopguard plugin name mismatch" && exit 1); \
	for s in plugins/slop-guard/bin/slopguard plugins/slop-guard/lib/*.sh \
	          plugins/slop-guard/tests/run-tests; do \
		bash -n "$$s" || (echo "  ✗ $$s SYNTAX ERROR" && exit 1); \
	done; \
	echo "  ✓ slopguard shell syntax"; \
	command -v shellcheck > /dev/null 2>&1 && \
		(shellcheck -S warning plugins/slop-guard/bin/slopguard \
		            plugins/slop-guard/lib/*.sh \
		            plugins/slop-guard/tests/run-tests && echo "  ✓ slopguard shellcheck clean") || \
		echo "  – shellcheck not installed, skipped"; \
	plugins/slop-guard/tests/run-tests; \
	command -v claude > /dev/null 2>&1 && claude plugin validate plugins/slop-guard --strict \
		|| echo "  – claude CLI not installed, plugin validate skipped"

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
	@echo "Version bumped to $(VERSION)"

bump-slopguard: ## Bump the slop-guard plugin patch version (make bump-slopguard VERSION=x.y.z)
	@$(MAKE) _bump-slopguard VERSION=$$(jq -r '.version' $(SLOPGUARD_PLUGIN_JSON) | awk -F. '{print $$1"."$$2"."$$3+1}')

_bump-slopguard:
ifndef VERSION
	$(error VERSION is required)
endif
	@jq '.version = "$(VERSION)"' $(SLOPGUARD_PLUGIN_JSON) > /tmp/plugin-sg.json && mv /tmp/plugin-sg.json $(SLOPGUARD_PLUGIN_JSON)
	@jq '(.plugins[] | select(.name == "slop-guard") | .version) = "$(VERSION)"' \
		$(MARKETPLACE_JSON) > /tmp/marketplace-sg.json && mv /tmp/marketplace-sg.json $(MARKETPLACE_JSON)
	@echo "slop-guard version bumped to $(VERSION)"
