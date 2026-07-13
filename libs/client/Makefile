.DEFAULT_GOAL := help
.PHONY: help install test test-coverage lint format dev dev-hot build build-lib clean serve preview check

SHELL := /bin/bash
PATH := ./node_modules/.bin:$(PATH)

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install project dependencies
	pnpm install

test: build ## Run test suite
	pnpm exec vitest run

test-coverage: build ## Run tests with coverage
	pnpm exec vitest run --coverage

lint: ## Run linters and code formatters
	pnpm exec biome check .

format: ## Format code with biome
	pnpm exec biome check --write .

dev: 
	pnpm exec vite

dev-build-watch: ## Watch and build in development mode
	pnpm exec vite build --mode development --watch

dev-hot: ## Start development server with hot reload
	pnpm exec vite --mode development

build: ## Build the project for production
	$(MAKE) clean
	pnpm exec rescript build

build-lib: ## Build the project as a library
	$(MAKE) clean
	pnpm exec rescript build
	pnpm exec vite build --mode library

build-standalone: ## Build standalone bundle (React bundled) for Cloudflare Pages
	$(MAKE) clean
	pnpm exec rescript build
	pnpm exec vite build --config vite.config.standalone.ts

clean: ## Clean build artifacts and temporary files
	rm -rf dist

serve: ## Serve production build
	pnpm exec vite preview --port 5173 --host

preview: ## Preview production build
	pnpm exec vite preview

publish:
	$(MAKE) build-lib
	pnpm publish

check: lint ## Run all checks (lint + test)
