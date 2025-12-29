# Cleanup Workflow Guide

## Overview

The automated cleanup workflow provides a safe, auditable way to clean up the Prometheus/Grafana monitoring infrastructure through GitHub Actions.

## Features

- ✅ **4 cleanup levels** - From simple service stop to full infrastructure destruction
- ✅ **Safety validations** - Confirmation required for destructive operations
- ✅ **Environment protection** - Production safeguards
- ✅ **Automated reporting** - Creates issue with cleanup summary
- ✅ **Audit trail** - All actions logged in GitHub Actions
- ✅ **Manual trigger only** - Prevents accidental cleanup

---

## Cleanup Levels

### Level 1: Stop Services

**What happens:**
- Docker Compose services stopped
- Containers kept (quick restart)
- Data volumes preserved
- Infrastructure running

**Use case:** Temporary maintenance, testing

**Cost:** Infrastructure costs continue (~$30-50/month)

**Trigger:**
```
Cleanup Level: stop-services
Confirmation: Not required
```

**To restart:**
```bash
# SSH to server
ssh ubuntu@<monitoring-ip>
cd /opt/monitoring
sudo docker compose up -d
```

---

### Level 2: Remove Containers

**What happens:**
- Docker services stopped and removed
- Containers deleted
- Data volumes **PRESERVED**
- Infrastructure running

**Use case:** Redeploying with config changes

**Cost:** Infrastructure costs continue (~$30-50/month)

**Trigger:**
```
Cleanup Level: remove-containers
Confirmation: Not required
```

**Data preserved:**
- Prometheus metrics history
- Grafana dashboards and settings
- AlertManager data

---

### Level 3: Full Cleanup

**What happens:**
- Services and containers removed
- Data volumes **DELETED**
- Infrastructure **STILL RUNNING**

**Use case:** Fresh start with clean data

**Cost:** Infrastructure costs continue (~$30-50/month)

**Trigger:**
```
Cleanup Level: full-cleanup
Confirmation: Type "CLEANUP" required
```

**⚠️ WARNING:** All historical data will be permanently lost!

---

### Level 4: Destroy Infrastructure

**What happens:**
- Terraform infrastructure destroyed
- EC2 instances terminated
- VPC and networking removed
- All data deleted

**Use case:** Project termination, cost optimization

**Cost:** $0 (all resources deleted)

**Trigger:**
```
Cleanup Level: destroy-infrastructure
Confirmation: Type "CLEANUP" required
Environment: Cannot be "production"
```

**⚠️ WARNING:** Complete teardown! Requires full redeployment to restore.

---

## How to Use

### Access the Workflow

1. **Navigate to GitHub Actions**
   ```
   Repository → Actions → Cleanup Monitoring Infrastructure
   ```

2. **Click "Run workflow"**

3. **Fill in the form:**
   - **Cleanup level:** Choose from dropdown
   - **Confirmation:** Type "CLEANUP" (for levels 3 & 4)
   - **Environment:** Select environment

4. **Click "Run workflow" button**

### Example: Stop Services

```
Cleanup level: stop-services
Confirmation: (leave empty)
Environment: dev
```

### Example: Full Cleanup

```
Cleanup level: full-cleanup
Confirmation: CLEANUP
Environment: dev
```

### Example: Destroy Infrastructure

```
Cleanup level: destroy-infrastructure
Confirmation: CLEANUP
Environment: staging
```

---

## Safety Features

### 1. Confirmation Requirement

**Levels 3 & 4 require typing "CLEANUP":**

```yaml
inputs:
  confirmation:
    description: 'Type "CLEANUP" to confirm'
    required: false
```

**Validation:**
- Workflow fails if confirmation not provided
- Prevents accidental destructive operations
- Clear error message if validation fails

### 2. Production Protection

**Production environment restrictions:**
- Infrastructure destruction **BLOCKED**
- Requires manual Terraform destroy
- Prevents accidental production teardown

```bash
# Production infrastructure destroy blocked
if environment == "production" && cleanup_level == "destroy-infrastructure":
  ERROR: Production infrastructure destruction requires manual approval
```

### 3. Validation Step

**Pre-cleanup validation:**
- Checks confirmation for destructive ops
- Validates environment selection
- Displays cleanup plan before execution

### 4. Audit Trail

**Every cleanup creates:**
- GitHub Actions run log
- Cleanup report issue
- Terraform state changes (if infrastructure destroyed)

---

## Workflow Steps

### 1. Validate Inputs

**Checks:**
- Confirmation for destructive operations
- Production environment restrictions
- Cleanup plan display

**Output:**
```
Environment: dev
Cleanup Level: full-cleanup
Triggered by: @username
```

### 2. Ansible Cleanup (Levels 1-3)

**Actions:**
- Retrieves infrastructure info from Terraform
- Configures SSH access to monitoring server
- Runs Ansible cleanup playbook with appropriate flags
- Verifies cleanup completion

**Output:**
```
✓ Found monitoring server: 1.2.3.4
✓ Running cleanup: Full cleanup including data volumes
✓ Cleanup completed successfully
```

### 3. Terraform Destroy (Level 4)

**Actions:**
- Displays resources to be destroyed
- 10-second warning period
- Executes terraform destroy
- Verifies destruction completion

**Output:**
```
⚠️  Resources to be DESTROYED:
- EC2 instance
- VPC and subnets
- Security groups

🔥 Destroying infrastructure...
✅ Infrastructure destroyed
```

### 4. Create Cleanup Report

**Creates GitHub issue with:**
- Cleanup summary
- Environment and level
- Success/failure status
- Next steps guidance

**Example issue:**
```markdown
## Cleanup Report

**Triggered by:** @username
**Environment:** dev
**Cleanup Level:** full-cleanup
**Date:** 2025-12-29T10:30:00Z

### Results
| Step | Status |
|------|--------|
| Ansible Cleanup | ✅ success |
| Terraform Destroy | ⏭️ skipped |

### Next Steps
- Infrastructure still running (incurring costs)
- Consider destroying infrastructure if not needed
```

---

## Post-Cleanup Actions

### After Stop Services

**Restart services:**
```bash
# Option 1: SSH and restart
ssh ubuntu@<ip>
cd /opt/monitoring
sudo docker compose up -d

# Option 2: Re-run deployment workflow
GitHub Actions → Deploy Monitoring Infrastructure → Run workflow
```

### After Remove Containers

**Redeploy stack:**
```bash
# Data volumes will be reused
GitHub Actions → Deploy Monitoring Infrastructure → Run workflow
```

### After Full Cleanup

**Fresh deployment:**
```bash
# All data deleted, fresh start
GitHub Actions → Deploy Monitoring Infrastructure → Run workflow

# Historical metrics: GONE
# Grafana dashboards: GONE (except provisioned ones)
```

### After Destroy Infrastructure

**Complete redeployment:**
```bash
# 1. Create infrastructure
cd terraform
terraform apply

# 2. Deploy monitoring stack
cd ../ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# OR use GitHub Actions workflow
```

---

## Monitoring the Cleanup

### View Workflow Progress

1. **Navigate to Actions tab**
2. **Click on running workflow**
3. **Expand job steps to see progress**

### Check Cleanup Status

**Real-time logs:**
```
GitHub Actions → Workflow run → Job → Step
```

**Steps to watch:**
- Validate Cleanup Request
- Run Ansible Cleanup
- Verify cleanup
- Create Cleanup Report Issue

### Review Cleanup Report

**After completion:**
1. Navigate to **Issues** tab
2. Find issue titled: "Cleanup Report - [env] - [level]"
3. Review summary and next steps

---

## Troubleshooting

### Workflow Fails at Validation

**Error:** "Confirmation required"

**Solution:**
```
Type "CLEANUP" exactly in the confirmation field
```

### Workflow Fails at Ansible Step

**Error:** "No infrastructure found"

**Solution:**
```
Infrastructure may not be deployed
- Check Terraform state
- Verify EC2 instances exist
- May be already cleaned up
```

### SSH Connection Fails

**Error:** "Failed to retrieve SSH key from SSM"

**Solution:**
```
- Verify AWS credentials in GitHub Secrets
- Check SSM parameter exists
- Verify IAM permissions for SSM access
```

### Terraform Destroy Fails

**Error:** "Resources still exist"

**Solution:**
```bash
# Manual cleanup may be needed
# 1. Check AWS Console for remaining resources
# 2. Delete manually if stuck
# 3. Remove from Terraform state:
terraform state rm <resource>
```

---

## Best Practices

### ✅ DO

1. **Always review cleanup plan before confirming**
   - Check which environment
   - Verify cleanup level
   - Confirm you have the right permissions

2. **Use appropriate cleanup level**
   - Stop services for temporary shutdown
   - Remove containers for config changes
   - Full cleanup for fresh start
   - Destroy only when project is done

3. **Check cleanup report after completion**
   - Verify expected results
   - Review next steps
   - Confirm resources cleaned up

4. **Backup important data before full cleanup**
   ```bash
   # Export Grafana dashboards
   # Download Prometheus snapshots (if needed)
   ```

### ❌ DON'T

1. **Don't use destroy for production without approval**
   - Workflow blocks this
   - Use manual Terraform destroy if needed

2. **Don't skip confirmation for destructive ops**
   - Type "CLEANUP" as required
   - Prevents accidents

3. **Don't cleanup during active monitoring**
   - Coordinate with team
   - Schedule during maintenance window

4. **Don't forget about costs**
   - Level 1-3 keep infrastructure running
   - Level 4 stops all costs

---

## Workflow Triggers

### Manual Only

```yaml
on:
  workflow_dispatch:
    inputs:
      cleanup_level: ...
```

**Why manual only:**
- Prevents accidental cleanup
- Requires conscious decision
- Provides audit trail via GitHub user

### Cannot be Triggered by:

- ❌ Git push
- ❌ Pull request
- ❌ Schedule (cron)
- ❌ External webhook

**Only triggered manually** through GitHub Actions UI.

---

## Comparison: Workflow vs Script

| Feature | GitHub Workflow | Shell Script |
|---------|----------------|--------------|
| Location | Cloud (GitHub Actions) | Local or SSH |
| Access | GitHub web UI | Command line |
| Audit trail | Automatic | Manual logging |
| Permissions | GitHub secrets | Local credentials |
| Reporting | Automatic issue | Manual |
| Safety | Multi-level validation | Script-level only |
| Cost | Free (GitHub Actions) | Free |

**When to use each:**

**Use Workflow:**
- Team environments
- Want audit trail
- Need approval process
- Automated reporting desired

**Use Script:**
- Local development
- Quick cleanup
- Testing
- Learning/debugging

---

## Security Considerations

### Secrets Required

```yaml
secrets:
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  AWS_REGION
```

**Protected by:**
- GitHub repository secrets
- Encrypted in transit
- Never logged in output

### Permissions

**Workflow permissions:**
```yaml
permissions:
  contents: read
  issues: write
```

**Minimal permissions:**
- Read code
- Create cleanup report issues
- No write access to code

### AWS IAM

**Required permissions:**
- EC2 describe/terminate
- SSM GetParameter
- Terraform state access (S3, DynamoDB)

---

## Cleanup Report Example

```markdown
## Cleanup Report

**Triggered by:** @johndoe
**Environment:** `dev`
**Cleanup Level:** `full-cleanup`
**Date:** 2025-12-29T15:30:00Z

### Results

| Step | Status |
|------|--------|
| Ansible Cleanup | ✅ success |
| Terraform Destroy | ⏭️ skipped |

### Cleanup Actions

- 🗑️ Containers removed
- 💾 Data volumes deleted
- 🖥️ Infrastructure still running

**Warning:** All metrics and dashboards deleted

### Next Steps

- Infrastructure still running (incurring costs)
- Consider destroying infrastructure if not needed
- Fresh deployment will start with empty metrics

---
*Automated cleanup report from GitHub Actions*
```

---

## Quick Reference

### Cleanup Levels

```bash
# Level 1: Stop only
Cleanup level: stop-services
Confirmation: (none)

# Level 2: Remove containers
Cleanup level: remove-containers
Confirmation: (none)

# Level 3: Full cleanup
Cleanup level: full-cleanup
Confirmation: CLEANUP

# Level 4: Destroy infrastructure
Cleanup level: destroy-infrastructure
Confirmation: CLEANUP
Environment: dev or staging only
```

### Cost Impact

| Level | Monthly Cost After Cleanup |
|-------|---------------------------|
| 1. Stop services | ~$30-50 |
| 2. Remove containers | ~$30-50 |
| 3. Full cleanup | ~$30-50 |
| 4. Destroy infrastructure | $0 |

---

## Summary

The cleanup workflow provides:

- ✅ Safe, auditable cleanup through GitHub Actions
- ✅ 4 cleanup levels for different scenarios
- ✅ Automatic validation and safety checks
- ✅ Cleanup reports via GitHub Issues
- ✅ Production environment protection
- ✅ Complete audit trail

**Access:** GitHub Repository → Actions → Cleanup Monitoring Infrastructure → Run workflow

**Documentation:** See also:
- Manual cleanup: `docs/CLEANUP_GUIDE.md`
- Cleanup script: `scripts/cleanup.sh`
- Ansible playbook: `ansible/playbooks/cleanup.yml`
