# ══════════════════════════════════════════════════════════════
# Dotfiles Makefile
# ══════════════════════════════════════════════════════════════

.PHONY: help test test-verbose test-tmux test-no-tmux test-failures \
        lint lint-shell lint-zsh lint-lua theme-check \
        test-libs test-scripts test-integration \
        install install-minimal install-core install-full \
        check clean

.DEFAULT_GOAL := help

# ──────────────────────────────────────────────────────────────
# Help
# ──────────────────────────────────────────────────────────────

help: ## Show this help message
	@printf '\033[1;36mDotfiles Makefile\033[0m\n'
	@printf '\033[36m══════════════════════════════════════════════════════════════\033[0m\n\n'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[0;32m%-18s\033[0m %s\n", $$1, $$2}'
	@printf '\n'

# ──────────────────────────────────────────────────────────────
# Testing
# ──────────────────────────────────────────────────────────────

TEST_FLAGS ?=
ifdef VERBOSE
TEST_FLAGS += --verbose
endif

test: ## Run all tests (VERBOSE=1 for verbose output)
	@./scripts/run-tests.sh $(TEST_FLAGS)

test-verbose: ## Run all tests with verbose output
	@./scripts/run-tests.sh --verbose

test-tmux: ## Run only tmux-dependent tests
	@./scripts/run-tests.sh --tmux-only

test-no-tmux: ## Run tests that don't require tmux
	@./scripts/run-tests.sh --no-tmux

test-failures: ## Run tests, show only failures and skips with context
	@./scripts/run-tests.sh --verbose 2>&1 | grep -E '(FAIL|SKIP|✗|skipped|failed)' -B2 -A5 --color=never || printf '\033[0;32m✓ No failures or skips found\033[0m\n'

test-libs: ## Run library tests only
	@./scripts/_lib/test-install-libs.sh
	@./tmux/scripts/_lib/test-tmux-libs.sh

test-scripts: ## Run tmux script tests only
	@for t in tmux/scripts/tests/test-*.sh; do \
		"$$t" || exit 1; \
	done

test-integration: ## Run integration tests only
	@for t in scripts/tests/test-*.sh; do \
		"$$t" || exit 1; \
	done

# ──────────────────────────────────────────────────────────────
# Linting
# ──────────────────────────────────────────────────────────────

lint: lint-shell lint-zsh lint-lua theme-check ## Run all linters

lint-shell: ## Run ShellCheck on shell scripts
	@printf '\033[1;36mRunning ShellCheck...\033[0m\n'
	@shellcheck -x install.sh scripts/install/*.sh scripts/install/slices/*.sh scripts/_lib/*.sh
	@shellcheck -x tmux/scripts/*/*.sh tmux/scripts/_lib/*.sh
	@shellcheck -x scripts/dotfiles scripts/run-tests.sh
	@shellcheck -x launchers/*
	@printf '\033[0;32m✓ ShellCheck passed\033[0m\n'

lint-zsh: ## Syntax-check zsh framework with zsh -n (shellcheck has no zsh dialect)
	@printf '\033[1;36mChecking zsh syntax...\033[0m\n'
	@if ! command -v zsh >/dev/null 2>&1; then \
		printf '\033[0;33m! zsh not installed, skipping\033[0m\n'; \
	else \
		for f in zsh/*.zsh zsh/*.template scripts/hooks/*.zsh; do \
			zsh -n "$$f" || exit 1; \
		done; \
		printf '\033[0;32m✓ zsh syntax passed\033[0m\n'; \
	fi

lint-lua: ## Run luacheck on Neovim config
	@printf '\033[1;36mRunning luacheck...\033[0m\n'
	@luacheck nvim/lua/ --config nvim/.luacheckrc
	@printf '\033[0;32m✓ luacheck passed\033[0m\n'

theme-check: ## Run WCAG contrast checker on all themes
	@printf '\033[1;36mRunning theme contrast checks...\033[0m\n'
	@./scripts/theme-contrast-check --all
	@printf '\033[0;32m✓ All themes passed contrast checks\033[0m\n'

# ──────────────────────────────────────────────────────────────
# Installation
# ──────────────────────────────────────────────────────────────

install: ## Run full installation
	@./install.sh

install-minimal: ## Run minimal installation (zsh + tmux)
	@./install.sh --minimal

install-core: ## Run core installation (+ nvim, ghostty, AI tools)
	@./install.sh --core

install-full: ## Run full installation (+ Hammerspoon, Karabiner)
	@./install.sh --full

check: ## Run installation checks only
	@./install.sh --check-only

# ──────────────────────────────────────────────────────────────
# Maintenance
# ──────────────────────────────────────────────────────────────

clean: ## Clean up orphaned test resources
	@./tmux/scripts/tests/cleanup-tests.sh

clean-dry: ## Preview test cleanup (dry run)
	@./tmux/scripts/tests/cleanup-tests.sh --dry-run
