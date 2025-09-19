# N8N-R8 Makefile
# Convenient commands for managing the N8N development environment

.PHONY: help start stop restart logs status clean backup restore reset
.PHONY: start-nginx start-traefik start-dev start-with-nodes stop-nginx stop-traefik start-secure
.PHONY: build pull update health check-env setup ssl-renew
.PHONY: build-nodes watch-nodes test-nodes
.PHONY: dev prod staging test test-unit test-integration test-validation test-coverage test-parallel test-basic
.PHONY: security-init security-scan security-report security-encrypt security-rotate security-status
.PHONY: docs-serve docs-build docs-validate
.PHONY: performance-test performance-baseline performance-monitor
.PHONY: quick-start quick-nginx quick-traefik quick-monitor quick-secure quick-test quick-full

# Default target
.DEFAULT_GOAL := help

# Colors for output
YELLOW := \033[1;33m
GREEN := \033[0;32m
RED := \033[0;31m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Project configuration
PROJECT_NAME := n8n-r8
COMPOSE_FILE := docker-compose.yml
COMPOSE_NGINX := docker-compose.nginx.yml
COMPOSE_TRAEFIK := docker-compose.traefik.yml

# Check if .env file exists
ENV_FILE := .env
ifeq (,$(wildcard $(ENV_FILE)))
    $(warning $(YELLOW)Warning: .env file not found. Please create it from .env.example$(NC))
endif

# Check if custom nodes directory exists
NODES_DIR := nodes
HAS_CUSTOM_NODES := $(shell test -d $(NODES_DIR) && test -f $(NODES_DIR)/package.json && echo "true" || echo "false")

##@ Help

help: ## Display this help message
	@echo "$(GREEN)N8N-R8 Development Environment$(NC)"
	@echo "$(BLUE)================================$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make $(YELLOW)<target>$(NC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Basic Operations

start: ## Start N8N with basic configuration
	@echo "$(GREEN)Starting N8N (basic configuration)...$(NC)"
	docker compose -f $(COMPOSE_FILE) up -d
	@$(MAKE) --no-print-directory _wait-for-services
	@$(MAKE) --no-print-directory _show-access-info

start-dev: ## Start N8N with direct access (development)
	@echo "$(GREEN)Starting N8N with direct access (development)...$(NC)"
	docker compose -f $(COMPOSE_FILE) up -d
	@$(MAKE) --no-print-directory _wait-for-services
	@$(MAKE) --no-print-directory _show-access-info

start-with-nodes: ## Start N8N with custom nodes mounted
	@echo "$(GREEN)Starting N8N with custom nodes...$(NC)"
	@if [ -x "./scripts/start-with-nodes.sh" ]; then \
		./scripts/start-with-nodes.sh -d; \
	else \
		echo "$(RED)Start with nodes script not found or not executable$(NC)"; \
		exit 1; \
	fi

stop: ## Stop all services
	@echo "$(RED)Stopping all services...$(NC)"
	docker compose -f $(COMPOSE_FILE) down
	docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_NGINX) down 2>/dev/null || true
	docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_TRAEFIK) down 2>/dev/null || true

restart: ## Restart all services
	@$(MAKE) --no-print-directory stop
	@$(MAKE) --no-print-directory start

##@ Proxy Configurations

start-direct: ## Start N8N with direct port access (development)
	@echo "$(GREEN)Starting N8N with direct access...$(NC)"
	@if [ -x "./scripts/start-direct.sh" ]; then \
		./scripts/start-direct.sh -d; \
	else \
		echo "$(RED)Direct start script not found or not executable$(NC)"; \
		exit 1; \
	fi

start-nginx: ## Start N8N with Nginx proxy
	@echo "$(GREEN)Starting N8N with Nginx proxy...$(NC)"
	@if [ -x "./scripts/start-nginx.sh" ]; then \
		./scripts/start-nginx.sh -d; \
	else \
		docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_NGINX) up -d; \
		$(MAKE) --no-print-directory _wait-for-services; \
		$(MAKE) --no-print-directory _show-nginx-info; \
	fi

start-traefik: ## Start N8N with Traefik proxy
	@echo "$(GREEN)Starting N8N with Traefik proxy...$(NC)"
	@if [ -x "./scripts/start-traefik.sh" ]; then \
		./scripts/start-traefik.sh -d; \
	else \
		docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_TRAEFIK) up -d; \
		$(MAKE) --no-print-directory _wait-for-services; \
		$(MAKE) --no-print-directory _show-traefik-info; \
	fi

stop-all: ## Stop all N8N services regardless of configuration
	@echo "$(RED)Stopping all N8N services...$(NC)"
	@if [ -x "./scripts/stop-all.sh" ]; then \
		./scripts/stop-all.sh -f; \
	else \
		echo "$(RED)Stop all script not found or not executable$(NC)"; \
		exit 1; \
	fi

start-traefik-staging: ## Start N8N with Traefik proxy (staging SSL)
	@echo "$(GREEN)Starting N8N with Traefik proxy (staging SSL)...$(NC)"
	@if [ -x "./scripts/start-traefik.sh" ]; then \
		./scripts/start-traefik.sh --staging -d; \
	else \
		$(MAKE) --no-print-directory start-traefik; \
	fi

stop-nginx: ## Stop Nginx proxy setup
	@echo "$(RED)Stopping Nginx proxy setup...$(NC)"
	docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_NGINX) down

stop-traefik: ## Stop Traefik proxy setup
	@echo "$(RED)Stopping Traefik proxy setup...$(NC)"
	docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_TRAEFIK) down

##@ Development

dev: ## Start in development mode with logs
	@echo "$(GREEN)Starting N8N in development mode...$(NC)"
	docker compose -f $(COMPOSE_FILE) up

dev-nginx: ## Start with Nginx in development mode with logs
	@echo "$(GREEN)Starting N8N with Nginx in development mode...$(NC)"
	docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_NGINX) up

dev-traefik: ## Start with Traefik in development mode with logs
	@echo "$(GREEN)Starting N8N with Traefik in development mode...$(NC)"
	docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_TRAEFIK) up

##@ Maintenance

logs: ## Show logs for all services
	docker compose -f $(COMPOSE_FILE) logs -f

logs-n8n: ## Show N8N logs only
	docker compose -f $(COMPOSE_FILE) logs -f n8n

logs-postgres: ## Show PostgreSQL logs only
	docker compose -f $(COMPOSE_FILE) logs -f postgres

logs-redis: ## Show Redis logs only
	docker compose -f $(COMPOSE_FILE) logs -f redis

logs-nginx: ## Show Nginx logs (if running)
	docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_NGINX) logs -f nginx 2>/dev/null || echo "$(YELLOW)Nginx not running$(NC)"

logs-traefik: ## Show Traefik logs (if running)
	docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_TRAEFIK) logs -f traefik 2>/dev/null || echo "$(YELLOW)Traefik not running$(NC)"

status: ## Show status of all services
	@echo "$(BLUE)Service Status:$(NC)"
	@docker compose -f $(COMPOSE_FILE) ps 2>/dev/null || echo "$(YELLOW)Basic services not running$(NC)"
	@echo ""
	@docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_NGINX) ps 2>/dev/null | grep -v "^NAME" | head -n -0 || true
	@docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_TRAEFIK) ps 2>/dev/null | grep -v "^NAME" | head -n -0 || true

health: ## Check health of all services
	@echo "$(BLUE)Health Check:$(NC)"
	@for service in n8n n8n-postgres n8n-redis; do \
		if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$$service"; then \
			health=$$(docker inspect --format='{{.State.Health.Status}}' $$service 2>/dev/null || echo "no-healthcheck"); \
			case $$health in \
				"healthy") echo "  ✅ $$service: $(GREEN)healthy$(NC)" ;; \
				"unhealthy") echo "  ❌ $$service: $(RED)unhealthy$(NC)" ;; \
				"starting") echo "  🔄 $$service: $(YELLOW)starting$(NC)" ;; \
				"no-healthcheck") echo "  ⚪ $$service: $(BLUE)no healthcheck$(NC)" ;; \
				*) echo "  ❓ $$service: $(YELLOW)unknown$(NC)" ;; \
			esac; \
		else \
			echo "  ⭕ $$service: $(RED)not running$(NC)"; \
		fi; \
	done

##@ Data Management

backup: ## Create a backup of all data
	@echo "$(GREEN)Creating backup...$(NC)"
	@if [ -x "./scripts/backup.sh" ]; then \
		./scripts/backup.sh; \
	else \
		echo "$(RED)Backup script not found or not executable$(NC)"; \
		exit 1; \
	fi

restore: ## Restore from backup (interactive)
	@echo "$(YELLOW)Available backups:$(NC)"
	@if [ -x "./scripts/restore.sh" ]; then \
		./scripts/restore.sh --list; \
		echo ""; \
		echo "To restore a specific backup, run:"; \
		echo "  make restore-specific BACKUP=<backup_name>"; \
	else \
		echo "$(RED)Restore script not found or not executable$(NC)"; \
	fi

restore-specific: ## Restore specific backup (use BACKUP=name)
	@if [ -z "$(BACKUP)" ]; then \
		echo "$(RED)Please specify BACKUP name: make restore-specific BACKUP=n8n_backup_20240101_120000$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Restoring backup: $(BACKUP)$(NC)"
	@if [ -x "./scripts/restore.sh" ]; then \
		./scripts/restore.sh $(BACKUP); \
	else \
		echo "$(RED)Restore script not found or not executable$(NC)"; \
		exit 1; \
	fi

reset: ## Reset all data (interactive)
	@echo "$(RED)This will reset all N8N data!$(NC)"
	@if [ -x "./scripts/reset.sh" ]; then \
		./scripts/reset.sh; \
	else \
		echo "$(RED)Reset script not found or not executable$(NC)"; \
		exit 1; \
	fi

reset-force: ## Force reset all data (no confirmation)
	@echo "$(RED)Force resetting all N8N data...$(NC)"
	@if [ -x "./scripts/reset.sh" ]; then \
		./scripts/reset.sh --force --full; \
	else \
		echo "$(RED)Reset script not found or not executable$(NC)"; \
		exit 1; \
	fi

##@ Docker Management

build: ## Build all images
	@echo "$(GREEN)Building images...$(NC)"
	docker compose -f $(COMPOSE_FILE) build

pull: ## Pull latest images
	@echo "$(GREEN)Pulling latest images...$(NC)"
	docker compose -f $(COMPOSE_FILE) pull

update: ## Update and restart services
	@echo "$(GREEN)Updating services...$(NC)"
	@$(MAKE) --no-print-directory pull
	@$(MAKE) --no-print-directory restart

clean: ## Clean up all containers and volumes
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	docker compose -f $(COMPOSE_FILE) down --remove-orphans
	docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_NGINX) down --remove-orphans 2>/dev/null || true
	docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_TRAEFIK) down --remove-orphans 2>/dev/null || true
	docker system prune -f
ifeq ($(HAS_CUSTOM_NODES),true)
	@echo "$(YELLOW)Cleaning custom nodes build artifacts...$(NC)"
	@cd $(NODES_DIR) && npm run clean 2>/dev/null || true
endif
	@echo "$(GREEN)Cleanup completed$(NC)"

clean-all: ## Clean up everything including volumes
	@echo "$(RED)Cleaning up everything including volumes...$(NC)"
	docker compose -f $(COMPOSE_FILE) down --volumes --remove-orphans
	docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_NGINX) down --volumes --remove-orphans 2>/dev/null || true
	docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_TRAEFIK) down --volumes --remove-orphans 2>/dev/null || true
	docker system prune -af --volumes
ifeq ($(HAS_CUSTOM_NODES),true)
	@echo "$(YELLOW)Cleaning custom nodes build artifacts...$(NC)"
	@cd $(NODES_DIR) && npm run clean 2>/dev/null || true
endif
	@echo "$(GREEN)Complete cleanup finished$(NC)"

ssl-renew: ## Renew SSL certificates
	@echo "$(GREEN)Renewing SSL certificates...$(NC)"
	@if docker ps --format "table {{.Names}}" | grep -q "traefik"; then \
		echo "$(BLUE)Restarting Traefik to renew certificates...$(NC)"; \
		docker compose -f $(COMPOSE_FILE) -f $(COMPOSE_TRAEFIK) restart traefik; \
	elif docker ps --format "table {{.Names}}" | grep -q "nginx"; then \
		echo "$(BLUE)Nginx detected - manual certificate renewal required$(NC)"; \
		echo "$(YELLOW)Please run: certbot renew && docker compose restart nginx$(NC)"; \
	else \
		echo "$(YELLOW)No reverse proxy detected. SSL renewal not applicable.$(NC)"; \
	fi

##@ Custom Nodes

build-nodes: ## Build custom nodes (if nodes/ exists)
ifeq ($(HAS_CUSTOM_NODES),true)
	@echo "$(GREEN)Building custom N8N nodes...$(NC)"
	@cd $(NODES_DIR) && chmod +x scripts/build.sh && ./scripts/build.sh build
	@echo "$(GREEN)✅ Custom nodes built successfully$(NC)"
else
	@echo "$(YELLOW)No custom nodes directory found ($(NODES_DIR)/)$(NC)"
	@echo "$(BLUE)To create custom nodes, run: mkdir -p $(NODES_DIR) && cd $(NODES_DIR) && npm init$(NC)"
endif

watch-nodes: ## Watch mode for custom node development
ifeq ($(HAS_CUSTOM_NODES),true)
	@echo "$(GREEN)Starting watch mode for custom nodes...$(NC)"
	@cd $(NODES_DIR) && chmod +x scripts/build.sh && ./scripts/build.sh watch
else
	@echo "$(YELLOW)No custom nodes directory found ($(NODES_DIR)/)$(NC)"
	@echo "$(BLUE)To create custom nodes, run: mkdir -p $(NODES_DIR) && cd $(NODES_DIR) && npm init$(NC)"
endif

test-nodes: ## Run custom node tests
ifeq ($(HAS_CUSTOM_NODES),true)
	@echo "$(GREEN)Running custom node tests...$(NC)"
	@cd $(NODES_DIR) && npm test
	@echo "$(GREEN)✅ Custom node tests completed$(NC)"
else
	@echo "$(YELLOW)No custom nodes directory found ($(NODES_DIR)/)$(NC)"
	@echo "$(BLUE)To create custom nodes, run: mkdir -p $(NODES_DIR) && cd $(NODES_DIR) && npm init$(NC)"
endif

##@ Setup and Configuration

setup: ## Initial setup and configuration check
	@echo "$(GREEN)Setting up N8N-R8 environment...$(NC)"
	@$(MAKE) --no-print-directory check-env
	@$(MAKE) --no-print-directory _create-directories
	@$(MAKE) --no-print-directory _set-permissions
	@echo "$(GREEN)Setup completed!$(NC)"

check-env: ## Check environment configuration
	@echo "$(BLUE)Checking environment configuration...$(NC)"
	@if [ ! -f "$(ENV_FILE)" ]; then \
		echo "$(RED)❌ .env file not found$(NC)"; \
		echo "$(YELLOW)Please create .env file with required variables$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)✅ .env file found$(NC)"; \
	fi
	@if [ ! -f "$(COMPOSE_FILE)" ]; then \
		echo "$(RED)❌ docker-compose.yml not found$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)✅ docker-compose.yml found$(NC)"; \
	fi
	@if ! docker info >/dev/null 2>&1; then \
		echo "$(RED)❌ Docker is not running$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)✅ Docker is running$(NC)"; \
	fi
	@echo "$(GREEN)Environment check passed!$(NC)"

##@ Information

info: ## Show configuration information
	@echo "$(BLUE)N8N-R8 Configuration Information$(NC)"
	@echo "$(BLUE)================================$(NC)"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Compose File: $(COMPOSE_FILE)"
	@echo "Environment File: $(ENV_FILE)"
	@echo ""
	@if [ -f "$(ENV_FILE)" ]; then \
		echo "$(BLUE)Environment Variables:$(NC)"; \
		grep -E "^[A-Z_]+" $(ENV_FILE) | head -10 | sed 's/=.*/=***/' || true; \
		echo ""; \
	fi
	@echo "$(BLUE)Available Services:$(NC)"
	@echo "  - N8N (Workflow Automation)"
	@echo "  - PostgreSQL (Database)"
	@echo "  - Redis (Cache & Queue)"
	@echo "  - Nginx (Reverse Proxy - optional)"
	@echo "  - Traefik (Reverse Proxy - optional)"
ifeq ($(HAS_CUSTOM_NODES),true)
	@echo "  - Custom Nodes ($(NODES_DIR)/ - available)"
else
	@echo "  - Custom Nodes (not configured)"
endif

urls: ## Show access URLs
	@$(MAKE) --no-print-directory _show-access-info

##@ Internal Helpers (not meant to be called directly)

_wait-for-services:
	@echo "$(YELLOW)Waiting for services to be ready...$(NC)"
	@sleep 5
	@for i in 1 2 3 4 5; do \
		if docker compose -f $(COMPOSE_FILE) ps | grep -q "healthy\|Up"; then \
			echo "$(GREEN)Services are ready!$(NC)"; \
			break; \
		fi; \
		echo "Waiting... ($$i/5)"; \
		sleep 10; \
	done

_show-access-info:
	@echo ""
	@echo "$(GREEN)🌐 Access Information:$(NC)"
	@echo "  N8N Web Interface: http://localhost:5678"
	@echo "  Default Login: admin / changeme123! (change in .env)"
ifeq ($(HAS_CUSTOM_NODES),true)
	@echo "  Custom Nodes: Mounted from $(NODES_DIR)/dist"
endif
	@echo ""
	@echo "$(BLUE)📊 Useful Commands:$(NC)"
	@echo "  View logs: make logs"
	@echo "  Stop services: make stop"
	@echo "  Check status: make status"
ifeq ($(HAS_CUSTOM_NODES),true)
	@echo "  Build nodes: make build-nodes"
	@echo "  Watch nodes: make watch-nodes"
endif

_show-nginx-info:
	@echo ""
	@echo "$(GREEN)🌐 Nginx Proxy Access:$(NC)"
	@echo "  N8N Web Interface: http://localhost"
	@echo "  Health Check: http://localhost/health"
	@echo ""
	@echo "$(BLUE)📊 Nginx Commands:$(NC)"
	@echo "  View logs: make logs-nginx"
	@echo "  Stop Nginx: make stop-nginx"

_show-traefik-info:
	@echo ""
	@echo "$(GREEN)🌐 Traefik Proxy Access:$(NC)"
	@echo "  N8N Web Interface: http://localhost"
	@echo "  Traefik Dashboard: http://localhost:8080"
	@echo ""
	@echo "$(BLUE)📊 Traefik Commands:$(NC)"
	@echo "  View logs: make logs-traefik"
	@echo "  Stop Traefik: make stop-traefik"

_create-directories:
	@echo "$(YELLOW)Creating necessary directories...$(NC)"
	@mkdir -p data/n8n data/postgres data/redis data/traefik/acme
	@mkdir -p nginx/ssl nginx/html traefik/logs backups
ifeq ($(HAS_CUSTOM_NODES),true)
	@mkdir -p $(NODES_DIR)/dist
endif
	@echo "$(GREEN)Directories created$(NC)"

_set-permissions:
	@echo "$(YELLOW)Setting permissions...$(NC)"
	@chmod -R 755 data/ 2>/dev/null || true
	@chmod 700 nginx/ssl 2>/dev/null || true
	@chmod +x scripts/*.sh 2>/dev/null || true
	@echo "$(GREEN)Permissions set$(NC)"

##@ Monitoring

monitor-basic: ## Start basic monitoring (script-based)
	@echo "$(GREEN)Starting basic monitoring...$(NC)"
	@if [ -x "./scripts/start-monitoring.sh" ]; then \
		./scripts/start-monitoring.sh basic -d; \
	else \
		echo "$(RED)Monitoring script not found or not executable$(NC)"; \
		exit 1; \
	fi

monitor-full: ## Start full monitoring stack (Prometheus, Grafana, etc.)
	@echo "$(GREEN)Starting full monitoring stack...$(NC)"
	@if [ -x "./scripts/start-monitoring.sh" ]; then \
		./scripts/start-monitoring.sh full -d; \
	else \
		echo "$(RED)Monitoring script not found or not executable$(NC)"; \
		exit 1; \
	fi

monitor-minimal: ## Start minimal monitoring (Prometheus + exporters)
	@echo "$(GREEN)Starting minimal monitoring...$(NC)"
	@if [ -x "./scripts/start-monitoring.sh" ]; then \
		./scripts/start-monitoring.sh minimal -d; \
	else \
		echo "$(RED)Monitoring script not found or not executable$(NC)"; \
		exit 1; \
	fi

monitor-stop: ## Stop all monitoring services
	@echo "$(RED)Stopping monitoring services...$(NC)"
	@if [ -x "./scripts/start-monitoring.sh" ]; then \
		./scripts/start-monitoring.sh stop; \
	else \
		echo "$(RED)Monitoring script not found$(NC)"; \
	fi

monitor-check: ## Run one-time health check
	@echo "$(BLUE)Running health check...$(NC)"
	@if [ -x "./monitoring/scripts/monitor.sh" ]; then \
		./monitoring/scripts/monitor.sh check; \
	else \
		echo "$(RED)Monitor script not found or not executable$(NC)"; \
		exit 1; \
	fi

monitor-disk: ## Check disk usage
	@echo "$(BLUE)Checking disk usage...$(NC)"
	@if [ -x "./monitoring/scripts/disk-monitor.sh" ]; then \
		./monitoring/scripts/disk-monitor.sh check; \
	else \
		echo "$(RED)Disk monitor script not found or not executable$(NC)"; \
		exit 1; \
	fi

monitor-logs: ## Show monitoring logs
	@echo "$(BLUE)Monitoring logs:$(NC)"
	@if [ -f "./monitoring/logs/monitor.log" ]; then \
		tail -f ./monitoring/logs/monitor.log; \
	else \
		echo "$(YELLOW)No monitoring logs found$(NC)"; \
	fi

##@ Systemd Services

systemd-list: ## List available systemd services
	@echo "$(BLUE)Available systemd services:$(NC)"
	@if [ -x "./scripts/install-systemd.sh" ]; then \
		./scripts/install-systemd.sh list; \
	else \
		echo "$(RED)Systemd script not found or not executable$(NC)"; \
		exit 1; \
	fi

systemd-install-basic: ## Install basic systemd service
	@echo "$(GREEN)Installing basic systemd service...$(NC)"
	@if [ -x "./scripts/install-systemd.sh" ]; then \
		sudo ./scripts/install-systemd.sh install basic; \
	else \
		echo "$(RED)Systemd script not found or not executable$(NC)"; \
		exit 1; \
	fi

systemd-install-nginx: ## Install nginx systemd service
	@echo "$(GREEN)Installing nginx systemd service...$(NC)"
	@if [ -x "./scripts/install-systemd.sh" ]; then \
		sudo ./scripts/install-systemd.sh install nginx; \
	else \
		echo "$(RED)Systemd script not found or not executable$(NC)"; \
		exit 1; \
	fi

systemd-install-traefik: ## Install traefik systemd service
	@echo "$(GREEN)Installing traefik systemd service...$(NC)"
	@if [ -x "./scripts/install-systemd.sh" ]; then \
		sudo ./scripts/install-systemd.sh install traefik; \
	else \
		echo "$(RED)Systemd script not found or not executable$(NC)"; \
		exit 1; \
	fi

systemd-enable: ## Enable systemd service (use SERVICE=name)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Please specify SERVICE name: make systemd-enable SERVICE=basic$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Enabling systemd service: $(SERVICE)$(NC)"
	@if [ -x "./scripts/install-systemd.sh" ]; then \
		sudo ./scripts/install-systemd.sh enable $(SERVICE); \
	else \
		echo "$(RED)Systemd script not found or not executable$(NC)"; \
		exit 1; \
	fi

systemd-start: ## Start systemd service (use SERVICE=name)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Please specify SERVICE name: make systemd-start SERVICE=basic$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Starting systemd service: $(SERVICE)$(NC)"
	@if [ -x "./scripts/install-systemd.sh" ]; then \
		sudo ./scripts/install-systemd.sh start $(SERVICE); \
	else \
		echo "$(RED)Systemd script not found or not executable$(NC)"; \
		exit 1; \
	fi

systemd-status: ## Show systemd service status (use SERVICE=name)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Please specify SERVICE name: make systemd-status SERVICE=basic$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Systemd service status: $(SERVICE)$(NC)"
	@if [ -x "./scripts/install-systemd.sh" ]; then \
		sudo ./scripts/install-systemd.sh status $(SERVICE); \
	else \
		echo "$(RED)Systemd script not found or not executable$(NC)"; \
		exit 1; \
	fi

##@ Testing

test: ## Run all tests (comprehensive test suite)
	@echo "$(GREEN)Running comprehensive test suite...$(NC)"
	@if [ -x "./tests/run_tests.sh" ]; then \
		./tests/run_tests.sh; \
	else \
		echo "$(RED)Test runner not found or not executable$(NC)"; \
		exit 1; \
	fi

test-unit: ## Run unit tests only
	@echo "$(BLUE)Running unit tests...$(NC)"
	@if [ -x "./tests/run_tests.sh" ]; then \
		./tests/run_tests.sh --unit; \
	else \
		echo "$(RED)Test runner not found or not executable$(NC)"; \
		exit 1; \
	fi

test-integration: ## Run integration tests only
	@echo "$(BLUE)Running integration tests...$(NC)"
	@if [ -x "./tests/run_tests.sh" ]; then \
		./tests/run_tests.sh --integration; \
	else \
		echo "$(RED)Test runner not found or not executable$(NC)"; \
		exit 1; \
	fi

test-validation: ## Run environment validation tests
	@echo "$(BLUE)Running validation tests...$(NC)"
	@if [ -x "./tests/run_tests.sh" ]; then \
		./tests/run_tests.sh --validation; \
	else \
		echo "$(RED)Test runner not found or not executable$(NC)"; \
		exit 1; \
	fi

test-coverage: ## Run tests with coverage reporting
	@echo "$(BLUE)Running tests with coverage...$(NC)"
	@if [ -x "./tests/run_tests.sh" ]; then \
		./tests/run_tests.sh --coverage --report html; \
	else \
		echo "$(RED)Test runner not found or not executable$(NC)"; \
		exit 1; \
	fi

test-parallel: ## Run tests in parallel
	@echo "$(BLUE)Running tests in parallel...$(NC)"
	@if [ -x "./tests/run_tests.sh" ]; then \
		./tests/run_tests.sh --parallel; \
	else \
		echo "$(RED)Test runner not found or not executable$(NC)"; \
		exit 1; \
	fi

test-basic: ## Run basic functionality tests (legacy)
	@echo "$(BLUE)Running basic functionality tests...$(NC)"
	@$(MAKE) --no-print-directory check-env
	@echo "$(GREEN)✅ Environment check passed$(NC)"
	@if docker compose -f $(COMPOSE_FILE) config >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Docker Compose configuration valid$(NC)"; \
	else \
		echo "$(RED)❌ Docker Compose configuration invalid$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)All tests passed!$(NC)"

##@ Security

security-init: ## Initialize security framework
	@echo "$(GREEN)Initializing security framework...$(NC)"
	@if [ -x "./security/secrets/secrets-manager.sh" ]; then \
		./security/secrets/secrets-manager.sh init; \
	else \
		echo "$(RED)Security manager not found or not executable$(NC)"; \
		exit 1; \
	fi

security-scan: ## Run comprehensive security scans
	@echo "$(BLUE)Running security scans...$(NC)"
	@if [ -x "./security/scanning/scan-containers.sh" ]; then \
		./security/scanning/scan-containers.sh; \
	else \
		echo "$(RED)Container scanner not found or not executable$(NC)"; \
		exit 1; \
	fi
	@if [ -x "./security/scanning/scan-dependencies.sh" ]; then \
		./security/scanning/scan-dependencies.sh; \
	else \
		echo "$(YELLOW)Dependency scanner not found$(NC)"; \
	fi

security-report: ## Generate security report
	@echo "$(BLUE)Generating security report...$(NC)"
	@if [ -x "./security/scanning/security-report.sh" ]; then \
		./security/scanning/security-report.sh; \
	else \
		echo "$(RED)Security report generator not found or not executable$(NC)"; \
		exit 1; \
	fi

security-encrypt: ## Encrypt environment file
	@echo "$(GREEN)Encrypting environment file...$(NC)"
	@if [ -x "./security/secrets/secrets-manager.sh" ]; then \
		./security/secrets/secrets-manager.sh encrypt --env-file .env; \
	else \
		echo "$(RED)Security manager not found or not executable$(NC)"; \
		exit 1; \
	fi

security-rotate: ## Rotate all secrets
	@echo "$(GREEN)Rotating secrets...$(NC)"
	@if [ -x "./security/secrets/secrets-manager.sh" ]; then \
		./security/secrets/secrets-manager.sh rotate; \
	else \
		echo "$(RED)Security manager not found or not executable$(NC)"; \
		exit 1; \
	fi

security-status: ## Show security status
	@echo "$(BLUE)Security status:$(NC)"
	@if [ -x "./security/secrets/secrets-manager.sh" ]; then \
		./security/secrets/secrets-manager.sh status; \
	else \
		echo "$(RED)Security manager not found or not executable$(NC)"; \
		exit 1; \
	fi

start-secure: ## Start with enhanced security
	@echo "$(GREEN)Starting with enhanced security...$(NC)"
	docker compose -f $(COMPOSE_FILE) -f security/docker-compose.security.yml up -d
	@$(MAKE) --no-print-directory _wait-for-services
	@$(MAKE) --no-print-directory _show-access-info

##@ Documentation

docs-serve: ## Serve documentation locally
	@echo "$(GREEN)Starting documentation server...$(NC)"
	@if command -v python3 >/dev/null 2>&1; then \
		echo "$(BLUE)Documentation available at: http://localhost:8000$(NC)"; \
		cd docs && python3 -m http.server 8000; \
	elif command -v python >/dev/null 2>&1; then \
		echo "$(BLUE)Documentation available at: http://localhost:8000$(NC)"; \
		cd docs && python -m SimpleHTTPServer 8000; \
	else \
		echo "$(RED)Python not found. Please install Python to serve documentation.$(NC)"; \
		exit 1; \
	fi

docs-build: ## Build documentation (if using static site generator)
	@echo "$(BLUE)Building documentation...$(NC)"
	@if [ -f "docs/package.json" ]; then \
		cd docs && npm install && npm run build; \
	else \
		echo "$(YELLOW)No documentation build system found. Using static files.$(NC)"; \
	fi

docs-validate: ## Validate documentation links and structure
	@echo "$(BLUE)Validating documentation...$(NC)"
	@find docs -name "*.md" -type f | while read file; do \
		echo "Checking: $$file"; \
		if ! grep -q "^# " "$$file"; then \
			echo "$(YELLOW)Warning: $$file may be missing a main heading$(NC)"; \
		fi; \
	done
	@echo "$(GREEN)Documentation validation completed$(NC)"

##@ Performance

performance-test: ## Run performance tests
	@echo "$(BLUE)Running performance tests...$(NC)"
	@if [ -x "./tests/run_tests.sh" ]; then \
		./tests/run_tests.sh --performance; \
	else \
		echo "$(RED)Performance tests not available$(NC)"; \
		exit 1; \
	fi

performance-baseline: ## Check performance against baselines
	@echo "$(BLUE)Checking performance baselines...$(NC)"
	@if [ -f "./docs/performance/baseline-recommendations.md" ]; then \
		echo "$(GREEN)Performance baselines documented in docs/performance/$(NC)"; \
		echo "$(BLUE)Current system resources:$(NC)"; \
		echo "  CPU cores: $$(nproc)"; \
		echo "  Memory: $$(free -h | grep '^Mem:' | awk '{print $$2}')"; \
		echo "  Disk space: $$(df -h . | tail -1 | awk '{print $$4}') available"; \
	else \
		echo "$(RED)Performance baseline documentation not found$(NC)"; \
		exit 1; \
	fi

performance-monitor: ## Start performance monitoring
	@echo "$(GREEN)Starting performance monitoring...$(NC)"
	@$(MAKE) --no-print-directory monitor-full

##@ Quick Actions

quick-start: setup start ## Quick start (setup + start)

quick-nginx: setup start-nginx ## Quick start with Nginx

quick-traefik: setup start-traefik ## Quick start with Traefik

quick-monitor: setup start monitor-basic ## Quick start with basic monitoring

quick-secure: setup security-init start-secure ## Quick start with security

quick-test: setup test-validation test-unit ## Quick test (validation + unit tests)

quick-full: setup security-init start-secure monitor-full ## Full setup with security and monitoring
