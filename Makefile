SHELL := /bin/bash
.DEFAULT_GOAL := help

help:
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | awk -F':.*?##' '{printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}'

reproduce: ## Recompute and verify every paper number from the committed data (~10 s)
	@./reproduce.sh

up: ## Start the Wazuh stack with the 1,000 events ingested (full-replay path)
	@./run.sh

fresh: ## Start from scratch (reprocesses the whole dataset, reproducible)
	@./run.sh --fresh

replay: ## Replay all four LLM rule sets against the running stack
	@scripts/replay-variants.sh

down: ## Stop the stack (keeps data)
	@cd stack && docker compose down

reset: ## Stop and remove volumes (clean state)
	@cd stack && docker compose down -v

logs: ## Tail the manager logs
	@cd stack && docker compose logs -f --tail=100 wazuh.manager

alerts: ## Count alerts generated per rule (top 40)
	@scripts/count-alerts.sh
