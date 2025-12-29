# Node Exporter and Blackbox Exporter Fix

## Issue

Node Exporter and Blackbox Exporter were not displaying metrics in Prometheus. The services appeared to not be running.

## Root Cause

There were two critical issues in `ansible/playbooks/site.yml`:

### 1. Missing node-exporter Role

The `node-exporter` role was not included in the roles list, meaning the node exporter was never installed.

**Before:**
```yaml
roles:
  - prometheus
  - grafana
  - alertmanager
  - blackbox-exporter
```

**After:**
```yaml
roles:
  - prometheus
  - grafana
  - alertmanager
  - node-exporter  # Added
  - blackbox-exporter
```

### 2. Wrong Service Name

The playbook tried to verify a service called `node_exporter`, but the actual systemd service installed by the role is called `prometheus-node-exporter`.

**Before (line 50):**
```yaml
- name: Verify node_exporter is running
  systemd:
    name: node_exporter  # Wrong service name
    state: started
    enabled: yes
```

**After:**
```yaml
- name: Verify node_exporter is running
  systemd:
    name: prometheus-node-exporter  # Correct service name
    state: started
    enabled: yes
```

## Fix Applied

**Changed files:**
- `ansible/playbooks/site.yml` - Added node-exporter role and fixed service name

**New files:**
- `scripts/verify-exporters.sh` - Diagnostic script to verify exporters are working

## How to Apply the Fix

### Option 1: Redeploy with GitHub Actions

1. **Push the fixes to your repository** (already done if you see this doc)
2. **Navigate to:** GitHub Actions → Deploy Monitoring Infrastructure
3. **Click "Run workflow"**
4. **Select your environment** and run

The deployment will now properly install and configure both exporters.

### Option 2: Manual Fix on Existing Server

If you want to fix an existing deployment without full redeployment:

```bash
# SSH to your monitoring server
ssh ubuntu@<monitoring-server-ip>

# 1. Install Node Exporter
sudo apt-get update
sudo apt-get install -y prometheus-node-exporter

# 2. Configure Node Exporter
sudo tee /etc/default/prometheus-node-exporter <<EOF
ARGS="--web.listen-address=:9100"
EOF

# 3. Start and enable Node Exporter
sudo systemctl restart prometheus-node-exporter
sudo systemctl enable prometheus-node-exporter

# 4. Verify Node Exporter is running
systemctl status prometheus-node-exporter
curl http://localhost:9100/metrics

# 5. Verify Blackbox Exporter container is running
docker ps | grep blackbox-exporter

# If blackbox is not running:
cd /opt/monitoring
sudo docker compose up -d blackbox-exporter

# 6. Reload Prometheus to pick up the targets
docker exec prometheus kill -HUP 1
# Or use the reload endpoint:
curl -X POST http://localhost:9090/-/reload
```

### Option 3: Run Ansible Playbook Manually

```bash
# From your local machine
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

## Verification

After applying the fix, verify the exporters are working:

### Using the Verification Script

```bash
# SSH to your monitoring server
ssh ubuntu@<monitoring-server-ip>

# Download and run the verification script
curl -O https://raw.githubusercontent.com/YOUR_REPO/scripts/verify-exporters.sh
chmod +x verify-exporters.sh
sudo ./verify-exporters.sh
```

### Manual Verification

1. **Check Node Exporter:**
   ```bash
   # Check service status
   systemctl status prometheus-node-exporter

   # Check metrics endpoint
   curl http://localhost:9100/metrics | head -20
   ```

2. **Check Blackbox Exporter:**
   ```bash
   # Check container status
   docker ps | grep blackbox-exporter

   # Check metrics endpoint
   curl http://localhost:9115/metrics | head -20
   ```

3. **Check Prometheus Targets:**
   - Open browser: `http://<monitoring-server-ip>:9090/targets`
   - Verify both targets show status: **UP**
     - `node-exporter (localhost:9100)`
     - `blackbox (localhost:9115)`

## Expected Results

### Node Exporter

**Metrics endpoint:** `http://<server-ip>:9100/metrics`

Should return system metrics like:
```
# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 12345.67
node_cpu_seconds_total{cpu="0",mode="system"} 234.56
...
# HELP node_memory_MemTotal_bytes Memory information field MemTotal_bytes.
# TYPE node_memory_MemTotal_bytes gauge
node_memory_MemTotal_bytes 4.294967296e+09
```

### Blackbox Exporter

**Metrics endpoint:** `http://<server-ip>:9115/metrics`

Should return blackbox exporter's own metrics:
```
# HELP blackbox_exporter_build_info A metric with a constant '1' value...
# TYPE blackbox_exporter_build_info gauge
blackbox_exporter_build_info{version="..."} 1
...
```

**Probe metrics** (via Prometheus):
```
probe_success{instance="http://prometheus:9090",job="blackbox"} 1
probe_duration_seconds{instance="http://prometheus:9090",job="blackbox"} 0.123
```

### Prometheus Targets Page

Visit: `http://<server-ip>:9090/targets`

You should see:

| Endpoint | State | Labels | Last Scrape |
|----------|-------|--------|-------------|
| http://localhost:9100/metrics | **UP** | job="node-exporter" | X seconds ago |
| http://localhost:9115 | **UP** | job="blackbox" | X seconds ago |

## Common Issues

### Issue: Node Exporter Service Fails to Start

**Error:**
```
Job for prometheus-node-exporter.service failed because the control process exited with error code.
```

**Root Causes:**
1. Service configuration not loaded before starting
2. Port 9100 already in use
3. Systemd unit file issues

**Fix Applied:**
The node-exporter role now:
1. Stops the service if it auto-started after installation
2. Checks if port 9100 is available
3. Configures the service properly
4. Reloads systemd daemon
5. Starts the service with proper configuration
6. Provides detailed diagnostics if startup fails

**Manual Fix:**
```bash
# Check systemd unit configuration
systemctl cat prometheus-node-exporter

# Check if port is in use
netstat -tlnp | grep :9100

# Check service status
systemctl status prometheus-node-exporter

# Check logs
journalctl -xeu prometheus-node-exporter -n 50

# Try manual start
sudo systemctl stop prometheus-node-exporter
sudo systemctl daemon-reload
sudo systemctl start prometheus-node-exporter
```

## Troubleshooting

### Node Exporter Still Not Working

```bash
# Check if installed
dpkg -l | grep prometheus-node-exporter

# Check service logs
sudo journalctl -u prometheus-node-exporter -n 50

# Check if port is listening
sudo netstat -tlnp | grep 9100

# Manually test metrics
curl -v http://localhost:9100/metrics
```

### Blackbox Exporter Still Not Working

```bash
# Check container logs
docker logs blackbox-exporter

# Check if config file exists
ls -la /etc/blackbox_exporter/config.yml
cat /etc/blackbox_exporter/config.yml

# Restart container
cd /opt/monitoring
docker compose restart blackbox-exporter

# Check container is running
docker ps | grep blackbox
```

### Prometheus Not Scraping Targets

```bash
# Check Prometheus config
cat /etc/prometheus/prometheus.yml

# Check Prometheus logs
docker logs prometheus | tail -50

# Reload Prometheus config
curl -X POST http://localhost:9090/-/reload

# Check Prometheus targets API
curl http://localhost:9090/api/v1/targets | jq
```

## Related Files

- **Ansible Playbook:** `ansible/playbooks/site.yml`
- **Node Exporter Role:** `ansible/roles/node-exporter/tasks/main.yml`
- **Blackbox Exporter Role:** `ansible/roles/blackbox-exporter/tasks/main.yml`
- **Prometheus Config:** `configs/prometheus/prometheus.yml`
- **Verification Script:** `scripts/verify-exporters.sh`

## Prevention

To prevent this issue in the future:

1. **Always include all required roles** in the playbook's roles list
2. **Use correct service names** - check the role's tasks/handlers for the actual service name
3. **Add verification steps** to the playbook to catch missing services early
4. **Run the verification script** after deployment

## Summary

The exporters weren't running because:
1. Node exporter role was never executed (missing from roles list)
2. Service verification used wrong service name (node_exporter vs prometheus-node-exporter)

The fix adds the node-exporter role and corrects the service name, ensuring both exporters are properly installed and running.
