# ══════════════════════════════════════════════════════════════
# Dotfiles Makefile
# ══════════════════════════════════════════════════════════════

.PHONY: help test test-verbose test-tmux test-no-tmux \
        lint lint-shell lint-lua \
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

test: ## Run all tests
	@./scripts/run-tests.sh

test-verbose: ## Run all tests with verbose output
	@./scripts/run-tests.sh --verbose

test-tmux: ## Run only tmux-dependent tests
	@./scripts/run-tests.sh --tmux-only

test-no-tmux: ## Run tests that don't require tmux
	@./scripts/run-tests.sh --no-tmux

test-libs: ## Run library tests only
	@./scripts/_lib/test-install-libs.sh
	@./tmux/.tmux/scripts/_lib/test-tmux-libs.sh

test-scripts: ## Run tmux script tests only
	@for t in tmux/.tmux/scripts/tests/test-*.sh; do \
		"$$t" || exit 1; \
	done

test-integration: ## Run integration tests only
	@for t in scripts/tests/test-*.sh; do \
		"$$t" || exit 1; \
	done

# ──────────────────────────────────────────────────────────────
# Linting
# ──────────────────────────────────────────────────────────────

lint: lint-shell lint-lua ## Run all linters

lint-shell: ## Run ShellCheck on shell scripts
	@printf '\033[1;36mRunning ShellCheck...\033[0m\n'
	@shellcheck -x install.sh scripts/install/*.sh scripts/_lib/*.sh
	@shellcheck -x tmux/.tmux/scripts/*.sh tmux/.tmux/scripts/_lib/*.sh
	@shellcheck -x scripts/dotfiles scripts/run-tests.sh
	@shellcheck -x launchers/*
	@printf '\033[0;32m✓ ShellCheck passed\033[0m\n'

lint-lua: ## Run luacheck on Neovim config
	@printf '\033[1;36mRunning luacheck...\033[0m\n'
	@luacheck nvim/lua/ --no-unused-args --no-max-line-length
	@printf '\033[0;32m✓ luacheck passed\033[0m\n'

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
	@./tmux/.tmux/scripts/tests/cleanup-tests.sh

clean-dry: ## Preview test cleanup (dry run)
	@./tmux/.tmux/scripts/tests/cleanup-tests.sh --dry-run
