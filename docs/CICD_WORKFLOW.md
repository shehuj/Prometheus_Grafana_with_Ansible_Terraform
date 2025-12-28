# CI/CD Workflow Guide

## Overview

The deployment workflow follows GitFlow best practices with automated testing on PRs and deployments on main branch merges.

## Workflow Triggers

### 1. Pull Request to `dev` or `main` → Dry Run
- **Terraform**: Runs `terraform plan` (no apply)
- **Ansible**: Syntax check only (no deployment)
- **Result**: PR comment with plan preview

### 2. Merge to `main` → Production Deployment
- **Terraform**: Runs `terraform apply` 
- **Ansible**: Full deployment with Docker Compose
- **Result**: Live monitoring stack

### 3. Manual Trigger (workflow_dispatch) → Flexible
- **Actions**: plan, apply, or destroy
- **Environments**: production, staging, or dev
- **Use**: Emergency deployments or rollbacks

## Detailed Flow Diagrams

### Pull Request Flow (Dry Run)

```
┌──────────────────────────────────────────────────────────────┐
│ Developer Creates PR to dev/main                             │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│ Job 1: Terraform (Plan Only)                                 │
├──────────────────────────────────────────────────────────────┤
│ ✓ Checkout code                                              │
│ ✓ Setup Terraform                                            │
│ ✓ Configure AWS credentials                                  │
│ ✓ terraform init                                             │
│ ✓ terraform validate                                         │
│ ✓ terraform plan -out=tfplan        ← Plan only, no apply   │
│ ✓ Comment PR with plan output       ← Shows what will change│
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│ Job 2: Ansible Dry Run                                       │
├──────────────────────────────────────────────────────────────┤
│ ✓ Checkout code                                              │
│ ✓ Setup Python 3.12                                          │
│ ✓ Install Ansible 8.5.0                                      │
│ ✓ ansible-playbook --syntax-check   ← Syntax validation only│
│ ✓ Comment PR with validation result ← Confirms valid config │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│ PR Comments Added                                             │
├──────────────────────────────────────────────────────────────┤
│ 📋 Terraform Plan                                            │
│    └─► Shows infrastructure changes                          │
│                                                               │
│ ✅ Ansible Dry Run                                           │
│    └─► Syntax check passed                                   │
│    └─► Lists roles to be executed                            │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
                  ┌─────────────────┐
                  │ Review & Approve │
                  └─────────────────┘
```

### Main Branch Deployment Flow (Production)

```
┌──────────────────────────────────────────────────────────────┐
│ PR Merged to main                                             │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│ Job 1: Terraform (Full Apply)                                │
├──────────────────────────────────────────────────────────────┤
│ ✓ Checkout code                                              │
│ ✓ Setup Terraform                                            │
│ ✓ Configure AWS credentials                                  │
│ ✓ terraform init                                             │
│ ✓ terraform validate                                         │
│ ✓ terraform plan -out=tfplan                                 │
│ ✓ terraform apply -auto-approve     ← ACTUAL DEPLOYMENT     │
│ ✓ Get outputs (IP, SSH param)                                │
│ ✓ Generate Ansible inventory                                 │
│ ✓ Upload inventory as artifact                               │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│ Job 2: Ansible Configuration (Full Deployment)               │
├──────────────────────────────────────────────────────────────┤
│ ✓ Checkout code                                              │
│ ✓ Setup Python 3.12                                          │
│ ✓ Install Ansible 8.5.0                                      │
│ ✓ Configure AWS credentials                                  │
│ ✓ Download inventory artifact                                │
│ ✓ Retrieve SSH key from SSM                                  │
│ ✓ Wait for SSH to be ready                                   │
│ ✓ Wait for user-data to complete                             │
│ ✓ Run Ansible playbook                  ← ACTUAL CONFIG     │
│ ✓ Verify Prometheus health                                   │
│ ✓ Verify Grafana health                                      │
│ ✅ Deployment successful!                                     │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
                 ┌────────────────────┐
                 │ Monitoring Stack   │
                 │ Live & Accessible  │
                 └────────────────────┘
```

### Manual Workflow Dispatch

```
┌──────────────────────────────────────────────────────────────┐
│ GitHub Actions → Run workflow                                │
├──────────────────────────────────────────────────────────────┤
│ Select options:                                               │
│ • Action: [plan / apply / destroy]                           │
│ • Environment: [production / staging / dev]                  │
└──────────────────────────────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
            plan                    apply/destroy
                │                       │
                ▼                       ▼
        Show changes only      Execute deployment
```

## GitHub Secrets Required

Configure in: **Settings → Secrets and variables → Actions**

```yaml
AWS_ACCESS_KEY_ID         # AWS access key for Terraform/Ansible
AWS_SECRET_ACCESS_KEY     # AWS secret key
AWS_REGION                # AWS region (e.g., us-east-1)
GRAFANA_ADMIN_PASSWORD    # Grafana admin password
```

## Branch Strategy

```
main (production)
  │
  ├─► Merge here for production deployment
  │   └─► Triggers: terraform apply + ansible deploy
  │
dev (development)
  │
  ├─► Create PR here for testing
  │   └─► Triggers: terraform plan + ansible syntax check
  │
feature/* (feature branches)
  │
  └─► Create PR to dev branch
      └─► Triggers: terraform plan + ansible syntax check
```

## Workflow File Structure

```yaml
name: Deploy Monitoring Infrastructure

on:
  push:
    branches: [main]              # Deployment trigger
  pull_request:
    branches: [dev, main]         # Testing trigger
  workflow_dispatch:              # Manual trigger
    inputs:
      action: [plan, apply, destroy]
      environment: [production, staging, dev]

jobs:
  terraform:
    # Runs on: All events
    # Plan: Always
    # Apply: Only on main branch push
    
  ansible:
    # Runs on: main branch push only
    # Deploys: Full stack
    
  ansible-dry-run:
    # Runs on: PRs only
    # Validates: Syntax check
```

## PR Comments

### Example Terraform Plan Comment

```markdown
#### Terraform Plan 📋
<details><summary>Show Plan</summary>

```terraform
Terraform will perform the following actions:

  # aws_instance.monitoring will be created
  + resource "aws_instance" "monitoring" {
      + ami                    = "ami-12345678"
      + instance_type          = "t3.large"
      ...
    }

Plan: 15 to add, 0 to change, 0 to destroy.
```

</details>

**Event**: `pull_request`
**Branch**: `feature/add-alerting`
**Workflow**: `Deploy Monitoring Infrastructure`

*Pusher: @username*
```

### Example Ansible Check Comment

```markdown
#### Ansible Dry Run ✅

**Syntax Check**: Passed
**Playbook**: `ansible/playbooks/site.yml`

The Ansible playbook syntax is valid. Configuration will be applied when merged to main.

**Roles to be executed**:
- ✅ prometheus (Copy configuration files)
- ✅ grafana (Configure datasources)
- ✅ alertmanager (Create alert routing)
- ✅ blackbox-exporter (Configure probes)

**Note**: Full deployment will run on merge to main branch.

*Pusher: @username*
```

## Common Workflows

### 1. Making a Configuration Change

```bash
# 1. Create feature branch
git checkout -b feature/update-prometheus-rules

# 2. Make changes to configs/prometheus/alert-rules.yml
vim configs/prometheus/alert-rules.yml

# 3. Commit and push
git add configs/prometheus/alert-rules.yml
git commit -m "Add new alert for high memory usage"
git push origin feature/update-prometheus-rules

# 4. Create PR to dev branch
# → GitHub Actions runs terraform plan + ansible syntax check
# → Review PR comments to see what will change

# 5. Merge PR to dev (optional staging)
# → No deployment, just validation

# 6. Create PR from dev to main
# → GitHub Actions runs terraform plan + ansible syntax check again

# 7. Merge to main
# → GitHub Actions deploys to production
# → Prometheus reloads with new alert rules
```

### 2. Emergency Hotfix

```bash
# 1. Create hotfix branch from main
git checkout main
git checkout -b hotfix/critical-alert

# 2. Make urgent changes
vim configs/prometheus/alert-rules.yml

# 3. Commit and push
git add configs/prometheus/alert-rules.yml
git commit -m "Fix critical alert threshold"
git push origin hotfix/critical-alert

# 4. Create PR directly to main
# → Review terraform plan

# 5. Merge to main
# → Immediate deployment

# Alternative: Use workflow_dispatch for instant deploy
# → Go to Actions → Deploy Monitoring Infrastructure
# → Click "Run workflow"
# → Select: action=apply, environment=production
```

### 3. Infrastructure Changes

```bash
# 1. Update Terraform files
vim terraform/ec2.tf

# 2. Create PR to dev
# → See terraform plan in PR comments
# → Shows: +5 to add, 0 to change, 0 to destroy

# 3. Review and merge to main
# → Infrastructure updated automatically
```

## Best Practices

1. **Always test in dev first**: Create PR to dev before main
2. **Review plan output**: Check PR comments before merging
3. **Small, focused PRs**: One change per PR for easier review
4. **Descriptive commit messages**: Explain why, not just what
5. **Use workflow_dispatch for emergencies**: Skip PR process when needed
6. **Monitor after deployment**: Check Prometheus/Grafana after merge

## Rollback Procedure

If deployment fails or causes issues:

### Option 1: Revert via Git
```bash
git revert <commit-hash>
git push origin main
# → Triggers automatic deployment of previous state
```

### Option 2: Manual Rollback via Workflow
1. Go to Actions → Deploy Monitoring Infrastructure
2. Click "Run workflow"
3. Select `action: destroy` (to remove resources)
4. Or select `action: apply` with previous terraform.tfvars

### Option 3: Terraform State Rollback
```bash
# Locally
terraform workspace select production
terraform plan -out=rollback.tfplan
terraform apply rollback.tfplan
```

## Monitoring the Deployment

### During Deployment
- Watch GitHub Actions logs in real-time
- Check Terraform plan output
- Monitor Ansible playbook execution

### After Deployment
- Verify services:
  - Prometheus: `http://<IP>:9090/-/ready`
  - Grafana: `http://<IP>:3000/api/health`
- Check CloudWatch for instance health
- Review Prometheus targets: `http://<IP>:9090/targets`

## Troubleshooting

### PR dry run failing
- Check syntax errors in configs
- Review terraform plan output
- Ensure AWS credentials are valid

### Deployment stuck
- Check GitHub Actions logs
- Verify AWS resource limits
- Check security group rules

### Ansible playbook fails
- SSH to instance: `ssh -i key.pem ubuntu@<IP>`
- Check user-data completion: `cat /var/log/user-data-complete.log`
- Review Docker status: `docker ps`

---

**Status**: Production-ready CI/CD pipeline with automated testing and deployment.
