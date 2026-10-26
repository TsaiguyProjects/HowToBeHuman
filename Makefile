# Makefile for HowToBeHuman (MediaWiki on OVHcloud VPS-2)
#
# Production stack (docker-compose.prod.yml):
#   wiki (MediaWiki 1.43 LTS) + db (MariaDB 11.4) + caddy (auto HTTPS)
# Docs: vps/README.md

.PHONY: help prod-up prod-down prod-logs vps-provision vps-deploy vps-status vps-logs wiki-update clean env-check

help:
	@echo "HowToBeHuman (MediaWiki) - Available Commands:"
	@echo ""
	@echo "Production (local, uses .env for DOMAIN/MW_*):"
	@echo "  make prod-up        Start prod stack (docker-compose.prod.yml)"
	@echo "  make prod-down      Stop prod stack"
	@echo "  make prod-logs      Follow prod stack logs"
	@echo "  make wiki-update    Run MediaWiki update.php (after enabling extensions)"
	@echo ""
	@echo "VPS (OVHcloud VPS-2, needs VPS_HOST/VPS_USER/APP_DIR env):"
	@echo "  make vps-provision  Print one-time VPS provisioning command"
	@echo "  make vps-deploy     Deploy via SSH (git pull + compose up)"
	@echo "  make vps-status     Show container status on VPS"
	@echo "  make vps-logs       Follow logs on VPS"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean          Stop prod stack and prune Docker resources"
	@echo "  make env-check      Check installed tool versions"

# =============================================================================
# Production (MediaWiki)
# =============================================================================

prod-up:
	@echo "🚀 Starting production stack (docker-compose.prod.yml)..."
	docker compose -f docker-compose.prod.yml up -d --build

prod-down:
	docker compose -f docker-compose.prod.yml down

prod-restart: prod-down prod-up

prod-logs:
	docker compose -f docker-compose.prod.yml logs --follow --tail=100

wiki-update:
	@echo "🔄 Running MediaWiki update.php..."
	docker compose -f docker-compose.prod.yml exec wiki php maintenance/update.php --quick

# =============================================================================
# VPS (OVHcloud VPS-2: 4 vCores / 8GB / 75GB NVMe, ~$8.50/mo)
# See vps/README.md for ordering, DNS, and first-deploy steps.
# =============================================================================

vps-provision:
	@echo "1. Order VPS-2 2027 (Ubuntu 24.04) in OVHcloud manager (us.ovhcloud.com/vps/)."
	@echo "2. scp vps/provision.sh root@\$$VPS_HOST:/tmp/ && ssh root@\$$VPS_HOST 'APP_DIR=/opt/how-to-be-human DEPLOY_USER=deploy bash /tmp/provision.sh'"
	@echo "   Full steps: see vps/README.md"

vps-deploy:
	@echo "🚀 Deploying to VPS ($${VPS_HOST:?Set VPS_HOST} as $${VPS_USER:-deploy})..."
	ssh $${VPS_USER:-deploy}@$${VPS_HOST} 'cd $${APP_DIR:-/opt/how-to-be-human} && ./vps/deploy.sh'

vps-status:
	ssh $${VPS_USER:-deploy}@$${VPS_HOST} 'cd $${APP_DIR:-/opt/how-to-be-human} && docker compose -f docker-compose.prod.yml ps'

vps-logs:
	ssh $${VPS_USER:-deploy}@$${VPS_HOST} 'cd $${APP_DIR:-/opt/how-to-be-human} && docker compose -f docker-compose.prod.yml logs --tail=100 --follow'

# =============================================================================
# Maintenance
# =============================================================================

clean:
	@echo "🧹 Cleaning Docker resources..."
	docker compose -f docker-compose.prod.yml down -v --remove-orphans 2>/dev/null || true
	docker system prune -f --volumes 2>/dev/null || true

env-check:
	@echo "🔍 Checking environment..."
	@echo "Docker: $$(docker --version)"
	@echo "Docker Compose: $$(docker compose version)"
