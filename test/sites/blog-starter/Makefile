.DEFAULT_GOAL := help
.PHONY: help install dev dev-ssl debug build start clean

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## Install dependencies
	pnpm install

dev: ## Start development server with Turbopack
	pnpm run dev

dev-ssl: ## Start development server with HTTPS
	pnpm run dev:ssl

debug: ## Start development server with Node inspector
	pnpm run debug

build: ## Build for production
	pnpm run build

start: ## Start production server
	pnpm run start

clean: ## Clean build artifacts
	rm -rf .next

