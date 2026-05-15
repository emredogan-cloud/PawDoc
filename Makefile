# PawDoc — top-level orchestration
#
# Conventions:
#   - All targets are idempotent (running twice is safe).
#   - Each subproject is invoked through its own canonical command — this file
#     adds no abstraction beyond aggregation.
#   - .PHONY for everything (no make is generating files here).

SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# ----- Paths -----------------------------------------------------------------
AI_SERVICE := ai-service
MOBILE     := mobile
SUPABASE   := supabase

# ----- Tooling ---------------------------------------------------------------
UV      := uv
FLUTTER := flutter
SBASE   := supabase

# =============================================================================
# Aggregation targets
# =============================================================================

.PHONY: help
help: ## Print all targets
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} \
	  /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup

.PHONY: setup
setup: setup-ai setup-mobile ## Bootstrap all services for first run

.PHONY: setup-ai
setup-ai: ## Install ai-service deps via uv
	cd $(AI_SERVICE) && $(UV) sync --all-extras

.PHONY: setup-mobile
setup-mobile: ## Install Flutter packages
	cd $(MOBILE) && $(FLUTTER) pub get

##@ Develop

.PHONY: ai-dev
ai-dev: ## Run AI service locally with auto-reload
	cd $(AI_SERVICE) && $(UV) run uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload

.PHONY: mobile-dev
mobile-dev: ## Run Flutter app in dev mode on attached device
	cd $(MOBILE) && $(FLUTTER) run --dart-define-from-file=env/dev.json

.PHONY: supabase-up
supabase-up: ## Start local Supabase stack
	cd $(SUPABASE) && $(SBASE) start

.PHONY: supabase-down
supabase-down: ## Stop local Supabase stack
	cd $(SUPABASE) && $(SBASE) stop

.PHONY: supabase-reset
supabase-reset: ## Reset local Supabase DB (DESTRUCTIVE, local only)
	cd $(SUPABASE) && $(SBASE) db reset

##@ Quality

.PHONY: lint
lint: lint-ai lint-mobile ## Run linters across all services

.PHONY: lint-ai
lint-ai: ## Lint + type-check ai-service
	cd $(AI_SERVICE) && $(UV) run ruff format --check . && $(UV) run ruff check . && $(UV) run mypy app

.PHONY: lint-mobile
lint-mobile: ## Lint + format-check mobile
	cd $(MOBILE) && dart format --output=none --set-exit-if-changed . && $(FLUTTER) analyze --fatal-infos --fatal-warnings

.PHONY: format
format: format-ai format-mobile ## Auto-format all code

.PHONY: format-ai
format-ai: ## Format ai-service with ruff
	cd $(AI_SERVICE) && $(UV) run ruff format . && $(UV) run ruff check --fix .

.PHONY: format-mobile
format-mobile: ## Format mobile with dart format
	cd $(MOBILE) && dart format .

.PHONY: test
test: test-ai test-mobile ## Run tests across all services

.PHONY: test-ai
test-ai: ## Run ai-service pytest
	cd $(AI_SERVICE) && $(UV) run pytest

.PHONY: test-mobile
test-mobile: ## Run Flutter tests
	cd $(MOBILE) && $(FLUTTER) test

##@ Build

.PHONY: build-ai
build-ai: ## Build ai-service Docker image locally
	cd $(AI_SERVICE) && docker build -t pawdoc-ai:dev .

.PHONY: build-mobile-ios
build-mobile-ios: ## Build mobile iOS release IPA
	cd $(MOBILE) && $(FLUTTER) build ipa --dart-define-from-file=env/prod.json --release

.PHONY: build-mobile-android
build-mobile-android: ## Build mobile Android release AAB
	cd $(MOBILE) && $(FLUTTER) build appbundle --dart-define-from-file=env/prod.json --release

##@ Housekeeping

.PHONY: clean
clean: clean-ai clean-mobile ## Remove generated artifacts

.PHONY: clean-ai
clean-ai: ## Remove ai-service venv + caches
	cd $(AI_SERVICE) && rm -rf .venv .pytest_cache .mypy_cache .ruff_cache __pycache__

.PHONY: clean-mobile
clean-mobile: ## flutter clean
	cd $(MOBILE) && $(FLUTTER) clean

.PHONY: pre-commit
pre-commit: ## Install pre-commit git hooks
	pip install --user pre-commit 2>/dev/null || true
	pre-commit install
