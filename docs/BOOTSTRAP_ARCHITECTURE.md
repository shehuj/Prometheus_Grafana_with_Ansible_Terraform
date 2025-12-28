# Bootstrap Architecture

## Division of Responsibilities

The deployment is split between **Terraform user-data** (bootstrap) and **Ansible** (configuration) to optimize deployment speed and avoid conflicts.

### Phase 1: Terraform user-data.sh (Bootstrap)
**When**: Runs automatically on EC2 first boot via cloud-init  
**Purpose**: Install system dependencies and set up the environment

**Responsibilities**:
- ✅ System updates (`apt-get update && upgrade`)
- ✅ Install Docker and Docker Compose
- ✅ Install AWS CLI v2
- ✅ Install CloudWatch Agent
- ✅ Install node_exporter (system metrics)
- ✅ Create directory structure:
  - `/etc/prometheus`, `/etc/grafana`, `/etc/alertmanager`
  - `/var/lib/prometheus`, `/var/lib/grafana`, `/var/lib/alertmanager`
- ✅ Set correct ownership and permissions
- ✅ Configure system settings (sysctl for Prometheus)
- ✅ Start node_exporter service
- ✅ Signal completion: `/var/log/user-data-complete.log`

**Why user-data**: Fast, runs in parallel with Terraform, ensures Docker is ready when Ansible runs

### Phase 2: Ansible Playbook (Configuration)
**When**: Runs after Terraform completes via GitHub Actions or manually  
**Purpose**: Deploy and configure monitoring applications

**Responsibilities**:
- ✅ Wait for user-data to complete
- ✅ Verify Docker installation
- ✅ Copy Prometheus configuration files
- ✅ Copy Grafana datasource configuration
- ✅ Create AlertManager configuration
- ✅ Configure Blackbox Exporter
- ✅ Deploy Docker Compose stack (Prometheus, Grafana, AlertManager)
- ✅ Wait for services to be healthy
- ✅ Display access information

**Why Ansible**: Declarative config management, idempotent, easy to update configurations

## Workflow Timeline

```
┌─────────────────────────────────────────────────────────────┐
│ Terraform Apply                                             │
├─────────────────────────────────────────────────────────────┤
│ 1. Create VPC, Subnets, Security Groups                     │
│ 2. Create S3 bucket, IAM roles                              │
│ 3. Launch EC2 instance with user-data.sh                    │
│    └─► user-data.sh starts running (background)             │
│ 4. Generate SSH key, store in SSM                           │
│ 5. Output monitoring IP, inventory file                     │
│ 6. Complete (2-3 minutes)                                   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Ansible Playbook (GitHub Actions or Manual)                 │
├─────────────────────────────────────────────────────────────┤
│ 1. Retrieve SSH key from SSM Parameter Store                │
│ 2. Wait for SSH to be ready (retry loop)                    │
│ 3. Pre-tasks:                                               │
│    └─► Wait for /var/log/user-data-complete.log             │
│    └─► Verify Docker installed                              │
│ 4. Run roles:                                               │
│    └─► prometheus: Copy configs                             │
│    └─► grafana: Copy datasource config                      │
│    └─► alertmanager: Create config                          │
│    └─► blackbox-exporter: Create config                     │
│ 5. Deploy Docker Compose stack                              │
│ 6. Wait for services to be healthy                          │
│ 7. Complete (3-5 minutes)                                   │
└─────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### 1. Why Split Bootstrap and Configuration?

**Speed**: 
- user-data runs in parallel with Terraform
- Docker is ready when Ansible starts
- No waiting for package installation in Ansible

**Clarity**:
- user-data = system-level dependencies
- Ansible = application configuration
- Clear separation of concerns

**Reliability**:
- user-data runs once on first boot (immutable)
- Ansible can be re-run to update configs
- No conflicts from re-installing packages

### 2. Why Wait for user-data Completion?

The Ansible pre_task waits for `/var/log/user-data-complete.log`:

```yaml
- name: Wait for cloud-init to complete
  ansible.builtin.wait_for:
    path: /var/log/user-data-complete.log
    timeout: 600
```

**Why**: 
- user-data might still be running when Ansible connects
- Prevents race conditions
- Ensures Docker is fully installed before deployment

### 3. Roles Removed from Ansible

These roles were **removed** because user-data handles them:
- ❌ `docker` - Installed by user-data.sh
- ❌ `node-exporter` - Installed and configured by user-data.sh

These roles **remain** because they configure applications:
- ✅ `prometheus` - Copies config files
- ✅ `grafana` - Copies datasource config
- ✅ `alertmanager` - Creates alert routing config
- ✅ `blackbox-exporter` - Creates probe config

## Updating the Stack

### To update system packages (Docker, node_exporter):
1. Modify `terraform/user-data.sh`
2. Run `terraform apply`
3. Terminate and recreate EC2 instance (or create new AMI)

### To update monitoring configs (Prometheus rules, Grafana datasources):
1. Modify files in `configs/` directory
2. Run Ansible playbook: `ansible-playbook -i inventory/hosts.ini playbooks/site.yml`
3. Ansible will copy new configs and reload services

### To update monitoring versions (Prometheus 2.49, Grafana 10.3):
1. Modify `ansible/playbooks/site.yml` version variables
2. Run Ansible playbook
3. Docker Compose will pull new images and restart containers

## Troubleshooting

### user-data failed or incomplete
```bash
# SSH to instance
ssh -i ~/.ssh/monitoring-key ubuntu@<IP>

# Check user-data logs
sudo cat /var/log/cloud-init-output.log

# Check completion status
ls -la /var/log/user-data-complete.log

# Check Docker
docker --version
docker ps
```

### Ansible timing out waiting for user-data
```bash
# The wait timeout is 600 seconds (10 minutes)
# If user-data takes longer, increase timeout in site.yml:

- name: Wait for cloud-init to complete
  ansible.builtin.wait_for:
    path: /var/log/user-data-complete.log
    timeout: 900  # Increase to 15 minutes
```

---

**Status**: Optimized bootstrap architecture with clear separation of concerns.
