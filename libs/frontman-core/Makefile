.DEFAULT_GOAL := help
.PHONY: help build test test-watch test-coverage lint format clean

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build ReScript
	pnpm exec rescript build

test: build ## Run tests
	pnpm exec vitest run

test-watch: ## Run tests in watch mode
	pnpm exec vitest

test-coverage: build ## Run tests with coverage
	pnpm exec vitest run --coverage

lint: ## Check formatting
	pnpm exec rescript format --check

format: ## Format code
	pnpm exec rescript format

clean: ## Clean build artifacts
	pnpm exec rescript clean
