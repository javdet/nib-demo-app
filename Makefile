COMPOSE      := docker compose
DEV_COMPOSE  := docker compose -f docker-compose.dev.yml

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ------------------------------------------------------------------ stacks --

.PHONY: up
up: ## Build and run the whole stack on http://localhost:8080
	$(COMPOSE) up --build -d
	@echo "shop:  http://localhost:8080"
	@echo "api:   http://localhost:8000/docs"

.PHONY: down
down: ## Stop the stack (keeps the database volume)
	$(COMPOSE) down

.PHONY: clean
clean: ## Stop the stack and delete the database volume
	$(COMPOSE) down -v
	$(DEV_COMPOSE) down -v

.PHONY: logs
logs: ## Tail every service
	$(COMPOSE) logs -f

.PHONY: dev
dev: ## Run Postgres + the reloading API on :8000
	$(DEV_COMPOSE) up --build -d
	@echo "api:   http://localhost:8000/docs"
	@echo "next:  make web"

.PHONY: web
web: ## Run the Vite dev server on :5173 (needs `make dev` first)
	cd frontend && npm install && npm run dev

.PHONY: psql
psql: ## Open a psql shell against the dev database
	$(DEV_COMPOSE) exec db psql -U nib -d nibshop

# -------------------------------------------------------------------- test --

.PHONY: test
test: test-backend test-frontend ## Run every test suite

.PHONY: test-backend
test-backend: ## pytest (SQLite, no services needed)
	cd backend && python3 -m venv .venv 2>/dev/null || true
	cd backend && .venv/bin/pip install -q -r requirements-dev.txt
	cd backend && .venv/bin/python -m pytest -q

.PHONY: test-frontend
test-frontend: ## vitest + tsc + eslint
	cd frontend && npm install --silent && npm run lint && npm run test && npm run build

.PHONY: lint
lint: ## ruff over the backend
	cd backend && .venv/bin/ruff check . && .venv/bin/ruff format --check .

.PHONY: fmt
fmt: ## Format the backend with ruff
	cd backend && .venv/bin/ruff check --fix . && .venv/bin/ruff format .

# --------------------------------------------------------------- migrations --

.PHONY: migrate
migrate: ## Apply migrations against the dev database
	$(DEV_COMPOSE) exec backend alembic upgrade head

.PHONY: migration
migration: ## Autogenerate a migration: make migration m="add wishlists"
	$(DEV_COMPOSE) exec backend alembic revision --autogenerate -m "$(m)"

.PHONY: seed
seed: ## Re-seed the catalogue in the dev database
	$(DEV_COMPOSE) exec backend python -m app.seed
