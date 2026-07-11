.DEFAULT_GOAL := help
.PHONY: help build test test-watch lint format clean publish

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build ReScript + bundle with tsup
	pnpm run build

publish: build ## Build and publish to npm (pass OTP=<code> for 2FA)
	@PKG=$$(node -e "const p=require('./package.json'); console.log(p.name+'@'+p.version)"); \
	if pnpm view "$$PKG" version >/dev/null 2>&1; then \
		echo "Skipping $$PKG — already published"; \
		exit 0; \
	fi; \
	pnpm publish $(if $(OTP),--otp=$(OTP))

test: build ## Run tests
	pnpm exec vitest run

test-watch: ## Run tests in watch mode
	pnpm exec vitest

lint: ## Check formatting
	pnpm exec rescript format --check src test

format: ## Format code
	pnpm exec rescript format src test

clean: ## Clean build artifacts
	pnpm exec rescript clean
