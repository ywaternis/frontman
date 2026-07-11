.DEFAULT_GOAL := help
.PHONY: help install dev build preview type-check clean

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	pnpm install

dev: ## Start development server
	pnpm run dev

build: ## Build for production (runs vue-tsc first)
	pnpm run build

preview: ## Preview production build
	pnpm run preview

type-check: ## Run vue-tsc type checking
	pnpm run type-check

clean: ## Clean build artifacts
	rm -rf dist node_modules/.vite
