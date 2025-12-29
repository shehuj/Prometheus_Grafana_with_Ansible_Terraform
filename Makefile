# Prometheus/Grafana Monitoring Stack Makefile
# Convenience commands for common operations

.PHONY: help deploy cleanup health logs

# Default target
help:
	@echo "Prometheus/Grafana Monitoring Management"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy              Deploy monitoring stack"
	@echo "  update              Update existing deployment"
	@echo ""
	@echo "Cleanup:"
	@echo "  cleanup-safe        Stop services, preserve data"
	@echo "  cleanup-stop        Stop services only (easy restart)"
	@echo "  cleanup             Complete cleanup (remove data)"
	@echo "  cleanup-full        Destroy everything including infrastructure"
	@echo "  cleanup-dry-run     Preview what would be removed"
	@echo ""
	@echo "Operations:"
	@echo "  health              Run health checks"
	@echo "  reload-prometheus   Reload Prometheus configuration"
	@echo "  add-job             Add custom Prometheus job"
	@echo ""
	@echo "Monitoring:"
	@echo "  logs                Show all service logs"
	@echo "  logs-prometheus     Show Prometheus logs"
	@echo "  logs-grafana        Show Grafana logs"
	@echo "  status              Check service status"
	@echo ""
	@echo "Infrastructure:"
	@echo "  tf-plan             Terraform plan"
	@echo "  tf-apply            Terraform apply"
	@echo "  tf-destroy          Terraform destroy"

# Ansible inventory
INVENTORY := ansible/inventory/hosts
PLAYBOOKS := ansible/playbooks

# Deployment targets
deploy:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOKS)/site.yml

update: deploy

# Cleanup targets
cleanup-safe:
	@echo "Running safe cleanup (preserving data)..."
	./scripts/cleanup.sh --preserve-data

cleanup-stop:
	@echo "Stopping services only..."
	./scripts/cleanup.sh --stop-only

cleanup:
	@echo "Running cleanup (removing data)..."
	@echo "WARNING: This will remove data volumes!"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		./scripts/cleanup.sh; \
	fi

cleanup-full:
	@echo "Running full cleanup (destroying infrastructure)..."
	@echo "WARNING: This will destroy all AWS resources!"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		./scripts/cleanup.sh --full-destroy; \
	fi

cleanup-dry-run:
	./scripts/cleanup.sh --dry-run

# Operations
health:
	@echo "Checking monitoring stack health..."
	@ansible monitoring -i $(INVENTORY) -a "cd /opt/monitoring && docker compose ps" -b

reload-prometheus:
	@echo "Reloading Prometheus configuration..."
	@ansible monitoring -i $(INVENTORY) -a "ssh ubuntu@$(shell cat $(INVENTORY) | grep -oP '\\d+\\.\\d+\\.\\d+\\.\\d+') 'sudo /usr/local/bin/update-prometheus-config'" || \
	ansible monitoring -i $(INVENTORY) -a "curl -X POST http://localhost:9090/-/reload" -b

add-job:
	@echo "Edit custom jobs file:"
	@echo "  ssh ubuntu@<monitoring-ip>"
	@echo "  sudo vim /etc/prometheus/jobs.d/custom-jobs.yml"
	@echo "  sudo update-prometheus-config"
	@echo ""
	@echo "Or see: docs/PROMETHEUS_JOBS_MANAGEMENT.md"

# Monitoring
logs:
	@ansible monitoring -i $(INVENTORY) -a "cd /opt/monitoring && docker compose logs --tail=50" -b

logs-prometheus:
	@ansible monitoring -i $(INVENTORY) -a "docker logs prometheus --tail 50" -b

logs-grafana:
	@ansible monitoring -i $(INVENTORY) -a "docker logs grafana --tail 50" -b

status:
	@echo "=== Docker Compose Services ==="
	@ansible monitoring -i $(INVENTORY) -a "cd /opt/monitoring && docker compose ps" -b
	@echo ""
	@echo "=== Node Exporter Status ==="
	@ansible monitoring -i $(INVENTORY) -a "systemctl status node_exporter --no-pager" -b
	@echo ""
	@echo "=== Disk Usage ==="
	@ansible monitoring -i $(INVENTORY) -a "df -h /var/lib/docker" -b

# Infrastructure management
tf-plan:
	cd terraform && terraform plan

tf-apply:
	cd terraform && terraform apply

tf-destroy:
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform && terraform destroy; \
	fi

# Quick commands for development
dev-up: tf-apply
	@echo "Waiting for instance to be ready..."
	@sleep 30
	@$(MAKE) deploy
	@echo "Development environment is up!"
	@echo "Access Prometheus: http://<monitoring-ip>:9090"
	@echo "Access Grafana: http://<monitoring-ip>:3000"

dev-down: cleanup-stop
	@echo "Development environment stopped (data preserved)"

dev-reset: cleanup deploy
	@echo "Development environment reset with fresh data"
