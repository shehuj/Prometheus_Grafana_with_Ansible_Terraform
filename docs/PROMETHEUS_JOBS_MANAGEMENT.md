# Managing Prometheus Scrape Jobs

## Overview

You can add custom Prometheus scrape jobs without redeploying the infrastructure by editing a simple configuration file on the monitoring server.

## Quick Start

### Adding a New Job

**1. SSH to the monitoring server:**
```bash
ssh -i ~/.ssh/monitoring-key ubuntu@<MONITORING_IP>
```

**2. Edit the custom jobs file:**
```bash
sudo vim /etc/prometheus/jobs.d/custom-jobs.yml
```

**3. Add your job** (remove the `[]` placeholder first):
```yaml
- job_name: 'my-web-app'
  static_configs:
    - targets: ['app-server:8080']
      labels:
        environment: 'production'
```

**4. Apply the configuration:**
```bash
sudo update-prometheus-config
```

**5. Verify** the job appears in Prometheus:
- Open: `http://<MONITORING_IP>:9090/targets`
- Look for your job in the list

## Directory Structure

```
/etc/prometheus/
├── prometheus-base.yml          # Base config (DO NOT EDIT - managed by Ansible)
├── prometheus.yml               # Active config (auto-generated)
├── jobs.d/
│   └── custom-jobs.yml         # YOUR JOBS HERE ← Edit this file
└── rules/
    └── alert-rules.yml         # Alert rules (managed by Ansible)
```

## The `update-prometheus-config` Script

This script:
1. Merges `prometheus-base.yml` with `jobs.d/custom-jobs.yml`
2. Generates `/etc/prometheus/prometheus.yml`
3. Reloads Prometheus automatically

**Usage:**
```bash
sudo update-prometheus-config
```

**Output:**
```
Merging Prometheus configurations...
Configuration merged successfully
Reloading Prometheus...
✓ Prometheus reloaded successfully
```

## Job Configuration Examples

### Example 1: Simple HTTP Application

```yaml
- job_name: 'my-api'
  static_configs:
    - targets: ['api-server-1:8080', 'api-server-2:8080']
      labels:
        environment: 'production'
        team: 'backend'
```

### Example 2: Application with Basic Auth

```yaml
- job_name: 'protected-app'
  basic_auth:
    username: 'prometheus'
    password: 'secret123'
  static_configs:
    - targets: ['secure-app:9090']
```

### Example 3: Multiple Target Groups

```yaml
- job_name: 'microservices'
  scrape_interval: 30s
  static_configs:
    - targets: ['service-a:8080', 'service-b:8080']
      labels:
        service_type: 'api'
        region: 'us-east-1'
    - targets: ['service-c:8080', 'service-d:8080']
      labels:
        service_type: 'worker'
        region: 'us-west-2'
```

### Example 4: MySQL Exporter

```yaml
- job_name: 'mysql'
  static_configs:
    - targets: ['mysql-exporter:9104']
      labels:
        database: 'primary'
        environment: 'production'
```

### Example 5: Redis Exporter

```yaml
- job_name: 'redis'
  static_configs:
    - targets: ['redis-exporter:9121']
      labels:
        cache_type: 'sessions'
```

### Example 6: Custom Metrics Interval

```yaml
- job_name: 'slow-changing-metrics'
  scrape_interval: 5m
  scrape_timeout: 30s
  static_configs:
    - targets: ['batch-processor:9090']
```

### Example 7: HTTPS with Custom CA

```yaml
- job_name: 'secure-service'
  scheme: https
  tls_config:
    ca_file: /etc/prometheus/ca.crt
    insecure_skip_verify: false
  static_configs:
    - targets: ['secure-app.internal:443']
```

## Complete Workflow Example

**Scenario**: Add monitoring for a new Node.js application

**1. SSH to monitoring server:**
```bash
ssh -i ~/.ssh/monitoring-key ubuntu@34.233.17.86
```

**2. Edit custom jobs:**
```bash
sudo vim /etc/prometheus/jobs.d/custom-jobs.yml
```

**3. Add the job** (replace the `[]` with):
```yaml
- job_name: 'nodejs-app'
  scrape_interval: 15s
  static_configs:
    - targets: 
        - 'nodejs-app-1.internal:9090'
        - 'nodejs-app-2.internal:9090'
      labels:
        app: 'user-service'
        environment: 'production'
        version: 'v2.1.0'

- job_name: 'postgres-exporter'
  static_configs:
    - targets: ['postgres-exporter.internal:9187']
      labels:
        database: 'users-db'
```

**4. Apply and verify:**
```bash
# Apply configuration
sudo update-prometheus-config

# Output should show:
# ✓ Prometheus reloaded successfully

# Verify in browser
open http://34.233.17.86:9090/targets
```

## Advanced: File-Based Service Discovery

For dynamic targets that change frequently, use file-based service discovery:

**1. Create a targets file:**
```bash
sudo vim /etc/prometheus/jobs.d/my-app-targets.json
```

**2. Add targets in JSON format:**
```json
[
  {
    "targets": ["app-1:8080", "app-2:8080"],
    "labels": {
      "job": "my-app",
      "environment": "production"
    }
  }
]
```

**3. Configure the job in custom-jobs.yml:**
```yaml
- job_name: 'dynamic-app'
  file_sd_configs:
    - files:
        - '/etc/prometheus/jobs.d/my-app-targets.json'
      refresh_interval: 30s
```

**4. Apply:**
```bash
sudo update-prometheus-config
```

**5. Update targets without reloading Prometheus:**
```bash
# Prometheus automatically picks up changes every 30s
sudo vim /etc/prometheus/jobs.d/my-app-targets.json
# No need to run update-prometheus-config!
```

## Troubleshooting

### Job Not Appearing

**Check if config is valid:**
```bash
# View the generated config
sudo cat /etc/prometheus/prometheus.yml

# Check Prometheus logs
sudo docker logs prometheus --tail 50
```

**Common issues:**
- YAML syntax error (indentation matters!)
- Missing `-` before `job_name`
- Targets not reachable from monitoring server

### Manual Reload

If `update-prometheus-config` fails:

```bash
# Check if Prometheus is running
sudo docker ps | grep prometheus

# Manual reload
curl -X POST http://localhost:9090/-/reload

# Or restart container
sudo docker restart prometheus
```

### Validate YAML Syntax

```bash
# Check your YAML is valid
python3 -c "import yaml; yaml.safe_load(open('/etc/prometheus/jobs.d/custom-jobs.yml'))"

# If no output, YAML is valid
# If error, fix the syntax
```

### View Active Configuration

```bash
# See what Prometheus is actually using
curl http://localhost:9090/api/v1/status/config | jq .data.yaml
```

## Best Practices

### 1. Use Meaningful Job Names
```yaml
# Good
- job_name: 'payment-service-production'

# Bad
- job_name: 'app1'
```

### 2. Add Descriptive Labels
```yaml
- job_name: 'api-servers'
  static_configs:
    - targets: ['api-1:8080']
      labels:
        environment: 'production'
        region: 'us-east-1'
        team: 'payments'
        version: 'v2.3.0'
```

### 3. Group Related Services
```yaml
- job_name: 'payment-stack'
  static_configs:
    - targets: ['payment-api:8080']
      labels:
        component: 'api'
    - targets: ['payment-worker:8080']
      labels:
        component: 'worker'
    - targets: ['payment-db-exporter:9104']
      labels:
        component: 'database'
```

### 4. Use Appropriate Scrape Intervals
```yaml
# Fast-changing metrics (default: 15s)
- job_name: 'high-frequency-app'
  scrape_interval: 10s

# Slow-changing metrics (save resources)
- job_name: 'batch-jobs'
  scrape_interval: 1m
```

### 5. Document Your Jobs
```yaml
# Payment processing services
# Maintained by: payments-team@company.com
# Alert: payments-oncall
- job_name: 'payment-service'
  static_configs:
    - targets: ['payment-api-1:8080', 'payment-api-2:8080']
```

## Backup and Version Control

**Backup your custom jobs:**
```bash
# On monitoring server
sudo cp /etc/prometheus/jobs.d/custom-jobs.yml ~/custom-jobs-backup-$(date +%Y%m%d).yml

# Download to local machine
scp -i ~/.ssh/monitoring-key ubuntu@<IP>:/etc/prometheus/jobs.d/custom-jobs.yml ./custom-jobs.yml
```

**Version control (recommended):**
```bash
# Store in your infrastructure repo
git add configs/prometheus/custom-jobs.yml
git commit -m "Add monitoring for new payment service"
git push

# Then copy to server and apply
scp configs/prometheus/custom-jobs.yml ubuntu@<IP>:/tmp/
ssh ubuntu@<IP> 'sudo mv /tmp/custom-jobs.yml /etc/prometheus/jobs.d/ && sudo update-prometheus-config'
```

## Monitoring Your Monitoring

**Check scrape health:**
```bash
# All targets status
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, instance, health}'

# Failed targets only
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health!="up") | {job, instance, lastError}'
```

**Check scrape duration:**
```promql
scrape_duration_seconds{job="my-app"}
```

**Alert on failed scrapes:**
```yaml
# Add to alert-rules.yml
- alert: ScrapeFailed
  expr: up{job="my-app"} == 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Failed to scrape {{ $labels.job }}"
```

## Summary

**To add a new job:**
1. SSH to server
2. Edit `/etc/prometheus/jobs.d/custom-jobs.yml`
3. Run `sudo update-prometheus-config`
4. Verify at `http://<IP>:9090/targets`

**Key files:**
- `/etc/prometheus/jobs.d/custom-jobs.yml` - Your jobs
- `/usr/local/bin/update-prometheus-config` - Update script
- `/etc/prometheus/prometheus.yml` - Active config (auto-generated)

**Ansible never overwrites custom-jobs.yml**, so your changes persist across deployments! 🎉
