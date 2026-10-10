# Makefile for HowToBeHuman
# Simplifies common development and deployment tasks
# Uses: uv (Python), pnpm (JavaScript)

.PHONY: help install dev build test lint format type-check clean deploy logs status open-frontend install-hooks uninstall-hooks

# Cross-platform browser open + frontend URL
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  OPEN_CMD = open
else ifeq ($(OS),Windows_NT)
  OPEN_CMD = start
else
  OPEN_CMD = xdg-open
endif
FRONTEND_URL = http://localhost:3000

# Default target
help:
	@echo "HowToBeHuman - Available Commands:"
	@echo ""
	@echo "Development:"
	@echo "  make install        Install all dependencies (backend + frontend)"
	@echo "  make dev            Start development environment with Docker Compose"
	@echo "  make dev-backend    Start only backend dev server (uv)"
	@echo "  make dev-frontend   Start only frontend dev server (pnpm, hot reload)"
	@echo "  make dev-docker     Start dev environment in Docker (hot reload)"
	@echo "  make build          Build production Docker images"
	@echo ""
	@echo "Testing & Quality:"
	@echo "  make test           Run all tests"
	@echo "  make test-backend   Run backend tests (unit + e2e)"
	@echo "  make test-e2e       Run e2e tests only (real Docker images)"
	@echo "  make test-frontend  Run frontend tests (pnpm test)"
	@echo "  make test-playwright Run Playwright e2e (Docker stack + browser)"
	@echo "  make test-backend-coverage  Backend coverage gate (100%)"
	@echo "  make test-frontend-coverage Frontend coverage gate (100%)"
	@echo "  make lint           Run all linters"
	@echo "  make lint-backend   Run backend linter (uv run ruff)"
	@echo "  make lint-frontend  Run frontend linter (pnpm lint)"
	@echo "  make format         Format code (uv run black + pnpm format)"
	@echo "  make type-check     Run type checkers (mypy + tsc)"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy         Deploy to Digital Ocean App Platform"
	@echo "  make deploy-dry     Show deployment spec without deploying"
	@echo "  make logs           Follow app logs on Digital Ocean"
	@echo "  make status         Check app status on Digital Ocean"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean          Remove build artifacts and containers"
	@echo "  make clean-all      Deep clean (including .venv, node_modules, images)"
	@echo "  make reset          Clean and reinstall everything"
	@echo ""
	@echo "Utilities:"
	@echo "  make env-check      Check installed tool versions"
	@echo "  make shell-backend  Open shell in backend container"
	@echo "  make shell-frontend Open shell in frontend container"
	@echo "  make install-hooks  Install git hooks (commit/push checks)"

# =============================================================================
# Development
# =============================================================================

install: install-backend install-frontend

install-backend:
	@echo "📦 Installing backend dependencies with uv..."
	cd backend && uv sync --all-groups

install-frontend:
	@echo "📦 Installing frontend dependencies with pnpm..."
	cd frontend && pnpm install

lock:
	@echo "🔒 Regenerating lockfiles..."
	cd backend && uv lock
	cd frontend && pnpm install --lockfile-only
	@echo "✅ Commit backend/uv.lock and frontend/pnpm-lock.yaml"

dev:
	@echo "🚀 Starting development environment (production-like)..."
	@$(MAKE) open-frontend
	docker-compose up --build

dev-backend:
	@echo "🚀 Starting backend dev server with uv..."
	cd backend && uv run python app.py

dev-frontend:
	@echo "🚀 Starting frontend dev server with pnpm..."
	@$(MAKE) open-frontend
	cd frontend && pnpm run dev

dev-docker:
	@echo "🚀 Starting development environment in Docker (hot reload)..."
	@$(MAKE) open-frontend
	docker-compose --profile dev up --build backend-dev frontend-dev

# Open frontend in browser (non-blocking, delayed so server can start)
open-frontend:
	@echo "🌐 Opening $(FRONTEND_URL) in browser..."
	@(sleep 5; $(OPEN_CMD) $(FRONTEND_URL) >/dev/null 2>&1 &)

build:
	@echo "🏗️  Building production Docker images..."
	docker-compose build

build-backend:
	docker build -f backend/Dockerfile -t how-to-be-human-backend .

build-frontend:
	docker build -f frontend/Dockerfile -t how-to-be-human-frontend .

# =============================================================================
# Testing
# =============================================================================

test: test-backend test-frontend

test-backend:
	@echo "🧪 Running backend tests with uv (unit + e2e, needs Docker for e2e)..."
	cd backend && uv run pytest -v --tb=short

test-backend-unit:
	@echo "🧪 Running backend unit tests only..."
	cd backend && uv run pytest -m "not e2e" -v --tb=short

test-e2e:
	@echo "🧪 Running end-to-end tests against real Docker images..."
	cd backend && uv run pytest -m e2e -v --tb=short

test-frontend:
	@echo "🧪 Running frontend tests with pnpm..."
	cd frontend && pnpm test

test-playwright:
	@echo "🧪 Running Playwright e2e against Docker stack (http://localhost:3000)..."
	@docker compose up -d --build
	@trap 'docker compose down >/dev/null 2>&1' EXIT INT TERM; \
		echo "⏳ Waiting for app health..."; \
		for i in $$(seq 1 90); do \
			curl -sf http://localhost:3000/api/health >/dev/null 2>&1 && break; \
			sleep 2; \
		done; \
		curl -sf http://localhost:3000/api/health >/dev/null 2>&1 || (echo "❌ App did not become healthy"; exit 1); \
		cd frontend && pnpm exec playwright test

test-backend-coverage:
	@echo "🧪 Running backend tests with coverage (gate: 100%)..."
	cd backend && uv run pytest -m "not e2e" --cov=app --cov-report=term-missing --cov-report=html

test-frontend-coverage:
	@echo "🧪 Running frontend tests with coverage (gate: 100% lines/functions/branches/statements)..."
	cd frontend && pnpm coverage

# =============================================================================
# Linting & Formatting
# =============================================================================

lint: lint-backend lint-frontend

lint-backend:
	@echo "🔍 Linting backend with uv..."
	cd backend && uv run ruff check .

lint-frontend:
	@echo "🔍 Linting frontend with pnpm..."
	cd frontend && pnpm lint

format: format-backend format-frontend

format-backend:
	@echo "✨ Formatting backend with uv..."
	cd backend && uv run black . --line-length=100

format-frontend:
	@echo "✨ Formatting frontend with pnpm..."
	cd frontend && pnpm format

type-check: type-check-backend type-check-frontend

type-check-backend:
	@echo "🔍 Type checking backend with uv..."
	cd backend && uv run mypy .

type-check-frontend:
	@echo "🔍 Type checking frontend with pnpm..."
	cd frontend && pnpm typecheck

# =============================================================================
# Deployment
# =============================================================================

deploy:
	@echo "🚀 Deploying to Digital Ocean App Platform..."
	@./scripts/deploy.sh

deploy-dry:
	@echo "📋 Deployment spec (.do/app.yaml):"
	@cat .do/app.yaml

logs:
	@echo "📝 Fetching logs..."
	@APP_ID=$$(doctl apps list --format ID,Spec.Name --no-header | grep how-to-be-human | awk '{print $$1}'); \
	if [ -z "$$APP_ID" ]; then echo "App not found"; exit 1; fi; \
	doctl apps logs $$APP_ID --follow

logs-backend:
	@APP_ID=$$(doctl apps list --format ID,Spec.Name --no-header | grep how-to-be-human | awk '{print $$1}'); \
	doctl apps logs $$APP_ID --type=backend --follow

logs-frontend:
	@APP_ID=$$(doctl apps list --format ID,Spec.Name --no-header | grep how-to-be-human | awk '{print $$1}'); \
	doctl apps logs $$APP_ID --type=frontend --follow

status:
	@echo "📊 App status:"
	@doctl apps list --format ID,Spec.Name,DefaultIngress,Status,CreatedAt

status-detail:
	@APP_ID=$$(doctl apps list --format ID,Spec.Name --no-header | grep how-to-be-human | awk '{print $$1}'); \
	doctl apps get $$APP_ID

# =============================================================================
# Git Hooks
# =============================================================================

install-hooks:
	@echo "🪝 Installing git hooks (pre-commit: unit+coverage, pre-push: all tests incl. e2e)..."
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-commit .githooks/pre-push
	@echo "✅ Hooks installed. Bypass with --no-verify."

uninstall-hooks:
	@echo "🪝 Removing git hooks..."
	git config --unset core.hooksPath || true
	@echo "✅ Hooks removed (git default hooks apply again)."

# =============================================================================
# Database (if using managed DB)
# =============================================================================

db-shell:
	@APP_ID=$$(doctl apps list --format ID,Spec.Name --no-header | grep how-to-be-human | awk '{print $$1}'); \
	DB_ID=$$(doctl apps get $$APP_ID --format Spec.Databases[].Name,Spec.Databases[].Engine --no-header | head -1 | awk '{print $$1}'); \
	doctl databases connection-pool $$DB_ID --format Name,ConnectionURI --no-header

db-migrate:
	@echo "🗄️  Running database migrations..."
	cd backend && uv run flask db upgrade 2>/dev/null || echo "Flask-Migrate not configured"

# =============================================================================
# Maintenance
# =============================================================================

clean:
	@echo "🧹 Cleaning build artifacts..."
	docker-compose down -v --remove-orphans 2>/dev/null || true
	docker system prune -f --volumes 2>/dev/null || true
	rm -rf frontend/build frontend/dist
	rm -rf backend/__pycache__ backend/.pytest_cache backend/*.egg-info
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true

clean-all: clean
	@echo "🧹 Deep cleaning..."
	rm -rf backend/.venv
	rm -rf frontend/node_modules
	docker image prune -a -f 2>/dev/null || true

reset: clean-all install
	@echo "✅ Reset complete!"

# =============================================================================
# Utilities
# =============================================================================

shell-backend:
	docker-compose exec backend sh

shell-frontend:
	docker-compose exec frontend sh

db-backup:
	@echo "💾 Backing up database..."
	@APP_ID=$$(doctl apps list --format ID,Spec.Name --no-header | grep how-to-be-human | awk '{print $$1}'); \
	DB_ID=$$(doctl apps get $$APP_ID --format Spec.Databases[].Name --no-header | head -1); \
	doctl databases backup $$DB_ID

env-check:
	@echo "🔍 Checking environment..."
	@echo "Docker: $$(docker --version)"
	@echo "Docker Compose: $$(docker-compose --version)"
	@echo "Python: $$(python3 --version)"
	@echo "uv: $$(uv --version 2>/dev/null || echo 'not installed')"
	@echo "Node: $$(node --version)"
	@echo "pnpm: $$(pnpm --version 2>/dev/null || echo 'not installed')"
	@echo "doctl: $$(doctl version 2>/dev/null || echo 'not installed')"

# =============================================================================
# CI Helpers (used by GitHub Actions)
# =============================================================================

ci-install: install-backend install-frontend

ci-test: test-backend test-frontend

ci-lint: lint-backend lint-frontend

ci-build: build-backend build-frontend