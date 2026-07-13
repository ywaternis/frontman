.DEFAULT_GOAL := help
.PHONY: help install test test-watch test-coverage build clean lint format check

SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install project dependencies
	pnpm install

build: ## Build the project
	pnpm exec rescript build
dev: ## Build the project in watch mode
	pnpm exec rescript watch

test: build ## Run test suite
	pnpm exec vitest run

test-watch: ## Run tests in watch mode
	pnpm exec vitest watch

test-coverage: build ## Run tests with coverage
	pnpm exec vitest run --coverage

lint: ## Check code formatting
	pnpm exec rescript format --check

format: ## Format code
	pnpm exec rescript format

check: lint test ## Run all checks (lint + test)

clean: ## Clean build artifacts and temporary files
	rm -rf src/*.res.mjs src/*.res.mjs.map test/*.res.mjs test/*.res.mjs.map
