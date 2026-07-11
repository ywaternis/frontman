.DEFAULT_GOAL := help
.PHONY: help install test test-watch test-coverage lint dev build clean check publish

SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install project dependencies
	pnpm install

test: build ## Run test suite
	pnpm exec vitest run

test-watch: build ## Run tests in watch mode
	pnpm exec vitest

test-coverage: build ## Run tests with coverage
	pnpm exec vitest run --coverage

lint: ## Run linters and code formatters
	pnpm exec rescript format --check

dev: clean ## Start development server with build watch
	pnpm exec rescript watch

build: clean ## Build the project for production
	pnpm exec rescript build

clean: ## Clean build artifacts and temporary files
	pnpm exec rescript clean

check: lint test ## Run all checks (lint + test)

publish: build ## Build and publish to npm (pass OTP=<code> for 2FA)
	@PKG=$$(node -e "const p=require('./package.json'); console.log(p.name+'@'+p.version)"); \
	if pnpm view "$$PKG" version >/dev/null 2>&1; then \
		echo "Skipping $$PKG — already published"; \
		exit 0; \
	fi; \
	pnpm publish $(if $(OTP),--otp=$(OTP))
