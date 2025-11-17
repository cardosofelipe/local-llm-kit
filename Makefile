.PHONY: help setup start start-headless stop restart status logs reset clean

# Default target
.DEFAULT_GOAL := help

help:
	@echo "Local-LLM-Kit - Self-hosted LLM Stack"
	@echo ""
	@echo "Available commands:"
	@echo "  make setup          - Interactive first-time setup"
	@echo "  make start          - Start all services"
	@echo "  make start-headless - Start without opening browser"
	@echo "  make stop           - Stop all services"
	@echo "  make restart        - Restart all services"
	@echo "  make status         - Check service health"
	@echo "  make logs           - View logs (all services)"
	@echo "  make logs-SERVICE   - View logs for specific service"
	@echo "  make reset          - Full reset (WARNING: deletes data)"
	@echo "  make clean          - Remove generated files only"
	@echo ""
	@echo "Examples:"
	@echo "  make logs-ollama    - View only Ollama logs"
	@echo "  make logs-open-webui - View only Open-WebUI logs"

setup:
	@./setup.sh

start:
	@./start.sh

start-headless:
	@./start.sh --headless

stop:
	@./stop.sh

restart: stop start

status:
	@echo "Service Status:"
	@echo "══════════════════════════════════════════════════════════════"
	@docker compose ps
	@echo ""
	@echo "Access Points:"
	@echo "  Open-WebUI: http://localhost:$${OPEN_WEBUI_PORT:-11300}"
	@echo "  SearXNG:    http://localhost:$${SEARXNG_PORT:-11380}"

logs:
	@docker compose logs -f

logs-%:
	@docker compose logs -f $*

reset:
	@echo "══════════════════════════════════════════════════════════════"
	@echo "  WARNING: This will delete ALL data and configuration!"
	@echo "══════════════════════════════════════════════════════════════"
	@echo ""
	@echo "This will:"
	@echo "  - Stop all containers"
	@echo "  - Delete all volumes and data"
	@echo "  - Remove docker-compose.yml and .env"
	@echo "  - Delete setup marker"
	@echo ""
	@read -p "Are you absolutely sure? Type 'yes' to confirm: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker compose down -v; \
		if [ -d data/ ]; then \
			echo "Removing data directory (may require sudo)..."; \
			docker run --rm -v "$(shell pwd)/data:/data" alpine sh -c "rm -rf /data/*" || \
			sudo rm -rf data/; \
		fi; \
		rm -f .setup-complete docker-compose.yml .env; \
		rm -f config/searxng/*; \
		touch data/.gitkeep; \
		echo ""; \
		echo "✓ Reset complete. Run 'make setup' to reinitialize."; \
	else \
		echo "Reset cancelled."; \
	fi

clean:
	@echo "Removing generated files..."
	@rm -f docker-compose.yml .env .setup-complete
	@echo "✓ Generated files removed"
	@echo ""
	@echo "Data preserved in data/ directory"
	@echo "Run 'make setup' to reconfigure"
