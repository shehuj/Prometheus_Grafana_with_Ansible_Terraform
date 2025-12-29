# Monitoring Stack Cleanup Guide

## Overview

This guide covers how to safely clean up your Prometheus/Grafana monitoring infrastructure, with options ranging from temporarily stopping services to completely destroying all resources.

## Quick Start

### Using the Cleanup Script (Recommended)

```bash
# See all options
./scripts/cleanup.sh --help

# Stop services but keep data (safest)
./scripts/cleanup.sh --preserve-data

# Temporary shutdown (easy restart)
./scripts/cleanup.sh --stop-only

# Complete cleanup
./scripts/cleanup.sh

# Preview what would be removed
./scripts/cleanup.sh --dry-run
```

### Using Ansible Directly

```bash
# Basic cleanup (removes containers and volumes)
ansible-playbook -i ansible/inventory/hosts \
  ansible/playbooks/cleanup.yml

# Preserve data volumes
ansible-playbook -i ansible/inventory/hosts \
  ansible/playbooks/cleanup.yml \
  -e preserve_data=true

# Stop only (keep containers)
ansible-playbook -i ansible/inventory/hosts \
  ansible/playbooks/cleanup.yml \
  -e stop_only=true
```

---

## Cleanup Levels

### Level 1: Stop Services Only

**What happens:**
- Docker Compose services stopped
- Containers kept (can restart quickly)
- Data volumes preserved
- Infrastructure running

```bash
./scripts/cleanup.sh --stop-only
```

**Use case:** Temporary maintenance or testing

**To restart:**
```bash
cd /opt/monitoring
sudo docker compose up -d
```

---

### Level 2: Remove Containers, Preserve Data

**What happens:**
- Docker Compose services stopped and removed
- Containers deleted
- Data volumes preserved
- Infrastructure running

```bash
./scripts/cleanup.sh --preserve-data
```

**Use case:** Redeploying with configuration changes

**Data preserved:**
- `/var/lib/docker/volumes/prometheus_data` - Metrics history
- `/var/lib/docker/volumes/grafana_data` - Dashboards and settings
- `/var/lib/docker/volumes/alertmanager_data` - Alert data

---

### Level 3: Complete Application Cleanup (Default)

**What happens:**
- Services stopped and removed
- Containers deleted
- **Data volumes deleted**
- Infrastructure running

```bash
./scripts/cleanup.sh
```

**Use case:** Fresh start with clean data

**Warning:** All historical data will be lost!

---

### Level 4: Full Infrastructure Destruction

**What happens:**
- Services and containers removed
- Data volumes deleted
- **EC2 instance destroyed**
- **VPC and networking destroyed**

```bash
./scripts/cleanup.sh --full-destroy
```

**Use case:** Project termination

---

## What Gets Cleaned Up

### Docker Compose Services
- **Prometheus** (port 9090)
- **Grafana** (port 3000)
- **AlertManager** (port 9093)
- **Blackbox Exporter** (port 9115)

### System Services
- **Node Exporter** (systemd service on port 9100)
  - Stopped but not disabled
  - Can be restarted or disabled manually

### Docker Volumes
- `prometheus_data` - Time-series metrics database
- `grafana_data` - Dashboards, datasources, settings
- `alertmanager_data` - Alert state and history

### Docker Networks
- `monitoring` - Overlay network for services

### Configuration Files
- `/etc/prometheus/prometheus.yml` - Active config (regenerated on deploy)
- `/etc/prometheus/jobs.d/custom-jobs.yml` - **PRESERVED** (your custom jobs)
- `/opt/monitoring/docker-compose.yml` - Removed by default

### Infrastructure (with --full-destroy)
- EC2 instance (t3.medium monitoring server)
- VPC and subnets
- Security groups
- EBS volumes
- Elastic IP (if assigned)

---

## Safety Features

### Confirmation Prompts

**1. Initial Confirmation**
```
Do you want to proceed? (yes/no):
```

**2. Volume Deletion Warning**
```
⚠️  WARNING: You are about to delete the following volumes:
- prometheus_data (contains metrics history)
- grafana_data (contains dashboards and settings)
- alertmanager_data (contains alert data)

This will PERMANENTLY DELETE all monitoring data

Press Ctrl+C and then 'A' to abort, or Enter to continue
```

**3. Infrastructure Destruction**
```
Type 'DESTROY' to confirm infrastructure destruction:
```

### Dry Run Mode

Test cleanup without making changes:

```bash
./scripts/cleanup.sh --dry-run
```

Shows:
- Resources that would be removed
- Actions that would be taken
- Warnings and confirmations

---

## Common Scenarios

### Scenario 1: Restart Monitoring Services

**Goal:** Restart services after configuration changes

```bash
# Stop services but keep everything
./scripts/cleanup.sh --stop-only

# Make changes to configs
vim /etc/prometheus/jobs.d/custom-jobs.yml

# Restart
cd /opt/monitoring
sudo docker compose up -d
```

---

### Scenario 2: Fresh Deployment with Same Data

**Goal:** Redeploy stack, keep historical data

```bash
# Remove containers, keep volumes
./scripts/cleanup.sh --preserve-data

# Redeploy
ansible-playbook -i ansible/inventory/hosts \
  ansible/playbooks/site.yml
```

**Result:** New containers, old metrics retained

---

### Scenario 3: Clean Slate

**Goal:** Start fresh with no old data

```bash
# Complete cleanup
./scripts/cleanup.sh

# Redeploy
ansible-playbook -i ansible/inventory/hosts \
  ansible/playbooks/site.yml
```

---

### Scenario 4: Shut Down for Weekend

**Goal:** Save costs, easy restart

```bash
# Friday evening - stop services
./scripts/cleanup.sh --stop-only

# OR stop EC2 instance
aws ec2 stop-instances --instance-ids <instance-id>

# Monday morning - restart
aws ec2 start-instances --instance-ids <instance-id>
# Wait for startup, then:
ssh ubuntu@<ip> "cd /opt/monitoring && sudo docker compose up -d"
```

---

### Scenario 5: Complete Teardown

**Goal:** Remove everything

```bash
# Nuclear option
./scripts/cleanup.sh --full-destroy

# Verify
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=prometheus-monitoring"
# Should return no instances
```

---

## Manual Cleanup Steps

If you prefer to run commands manually:

### 1. Stop Docker Compose

```bash
# SSH to monitoring server
ssh -i ~/.ssh/monitoring-key ubuntu@<monitoring-ip>

# Stop services
cd /opt/monitoring
sudo docker compose down

# Or stop and remove volumes
sudo docker compose down --volumes
```

### 2. Remove Containers (if not using compose)

```bash
sudo docker rm -f prometheus grafana alertmanager blackbox-exporter
```

### 3. Stop Node Exporter

```bash
sudo systemctl stop node_exporter

# Optional: disable from starting on boot
sudo systemctl disable node_exporter
```

### 4. Remove Volumes (Destructive!)

```bash
# List volumes
sudo docker volume ls

# Remove specific volumes
sudo docker volume rm prometheus_data
sudo docker volume rm grafana_data
sudo docker volume rm alertmanager_data
```

### 5. Clean Up Files

```bash
# Remove compose file
sudo rm /opt/monitoring/docker-compose.yml

# Remove deployment marker
sudo rm /opt/monitoring/.deployed

# Optional: remove entire monitoring directory
sudo rm -rf /opt/monitoring
```

### 6. Destroy Infrastructure

```bash
# On your local machine
cd terraform
terraform destroy
```

---

## Verification

### After Cleanup

```bash
# Check containers
docker ps -a
# Expected: No monitoring containers

# Check volumes
docker volume ls
# Expected: No prometheus/grafana volumes (unless preserved)

# Check services
systemctl status node_exporter
# Expected: inactive (if stopped)

# Check compose
ls -la /opt/monitoring/
# Expected: Empty or directory not found

# Check AWS resources (if full destroy)
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=prometheus-monitoring"
# Expected: No instances
```

---

## Troubleshooting

### Containers Won't Stop

**Error:** `Cannot stop container X: operation timeout`

**Solution:**
```bash
# Force kill
sudo docker kill prometheus grafana alertmanager blackbox-exporter

# Or force remove
sudo docker rm -f prometheus grafana alertmanager blackbox-exporter
```

---

### Volume in Use

**Error:** `volume is in use`

**Solution:**
```bash
# Check what's using it
docker ps -a --filter volume=prometheus_data

# Stop and remove the container
docker rm -f <container_id>

# Try removing volume again
docker volume rm prometheus_data
```

---

### Node Exporter Won't Stop

**Error:** Service fails to stop

**Solution:**
```bash
# Force stop
sudo systemctl kill node_exporter

# Check logs
journalctl -u node_exporter -n 50

# Reinstall if corrupted
sudo systemctl stop node_exporter
sudo rm /usr/local/bin/node_exporter
# Redeploy to reinstall
```

---

### Terraform Destroy Fails

**Error:** Resources still exist

**Solution:**
```bash
# Refresh state
cd terraform
terraform refresh

# Retry destroy
terraform destroy

# If stuck, manually remove from AWS Console
# Then remove from state:
terraform state rm <resource>
```

---

## Recovery

### If Volumes Accidentally Deleted

**Best case:** You don't have backups for this project (no backup role exists)

**Options:**
1. Accept data loss and start fresh
2. Restore from external backup if you created one manually
3. Import historical data if you exported it previously

---

### If Infrastructure Destroyed by Mistake

```bash
# Reprovision infrastructure
cd terraform
terraform apply

# Wait for instance to be ready
sleep 60

# Redeploy monitoring stack
cd ../ansible
ansible-playbook -i inventory/hosts playbooks/site.yml
```

---

## Cost Implications

### Cleanup Levels and Costs

| Level | Monthly Cost | Description |
|-------|-------------|-------------|
| Stop services only | ~$30-50 | EC2 running, services stopped |
| Remove containers | ~$30-50 | EC2 running, containers removed |
| Remove volumes | ~$30-50 | EC2 running, data deleted |
| Destroy infrastructure | $0 | Everything removed |

### Recommendations

- **Development:** Destroy infrastructure when not in use
- **Staging:** Stop services during off-hours
- **Production:** Never full destroy without approval

---

## Best Practices

### ✅ DO

1. **Backup critical dashboards before cleanup**
   ```bash
   # Export Grafana dashboards
   ssh ubuntu@<ip>
   curl http://localhost:3000/api/search | jq . > dashboards-backup.json
   ```

2. **Use dry-run to preview**
   ```bash
   ./scripts/cleanup.sh --dry-run
   ```

3. **Preserve data during testing**
   ```bash
   ./scripts/cleanup.sh --preserve-data
   ```

4. **Document custom jobs before cleanup**
   ```bash
   # Backup custom jobs
   scp ubuntu@<ip>:/etc/prometheus/jobs.d/custom-jobs.yml ./
   ```

### ❌ DON'T

1. Don't remove volumes in production without exports
2. Don't run full destroy without verifying environment
3. Don't cleanup during monitoring-critical periods
4. Don't forget to backup custom Grafana dashboards

---

## Automation Integration

### Scheduled Cleanup (Dev Environments)

```bash
# Crontab for weekend shutdown
0 18 * * 5 /path/to/scripts/cleanup.sh --stop-only

# Monday restart
0 8 * * 1 ssh ubuntu@<ip> "cd /opt/monitoring && docker compose up -d"
```

---

## Summary

**Quick Reference:**

```bash
# Stop only (easy restart)
./scripts/cleanup.sh --stop-only

# Safe cleanup (keep data)
./scripts/cleanup.sh --preserve-data

# Complete cleanup (remove data)
./scripts/cleanup.sh

# Nuclear option (destroy everything)
./scripts/cleanup.sh --full-destroy

# Test what would happen
./scripts/cleanup.sh --dry-run
```

**Remember:** Custom Prometheus jobs in `/etc/prometheus/jobs.d/custom-jobs.yml` are preserved!
