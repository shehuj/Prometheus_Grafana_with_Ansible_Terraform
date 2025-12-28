# Deployment Fixes Applied

## Issues Fixed

### 1. Ansible Version Issue
**Problem**: GitHub Actions workflow was trying to install `ansible==2.15.0`, which doesn't exist.

**Root Cause**: Ansible changed its versioning scheme. Version 2.15 is now `ansible-core 2.15`, distributed as part of `ansible 8.x`.

**Fix**: Updated `.github/workflows/deploy.yml:26`
```yaml
# Before
ANSIBLE_VERSION: '2.15.0'

# After  
ANSIBLE_VERSION: '8.5.0'
```

### 2. Ansible Roles Not Found
**Problem**: Ansible couldn't find roles because it was looking in `playbooks/roles/` instead of `ansible/roles/`.

**Root Cause**: No ansible.cfg file to specify the roles path.

**Fix**: Created `ansible/ansible.cfg` with:
```ini
roles_path = ./roles:~/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles
```

### 3. SSH Key Authentication Failure
**Problem**: SSH authentication failed with "Load key error in libcrypto" and "Permission denied (publickey)".

**Root Cause**: 
- Workflow was looking for key in GitHub Secrets (`MONITORING_SSH_KEY`)
- Terraform generates the key and stores it in AWS SSM Parameter Store
- The workflow wasn't retrieving it from SSM

**Fix**: Updated `.github/workflows/deploy.yml`

1. Added Terraform output for SSM parameter name:
```yaml
- name: Get Terraform Outputs
  run: |
    echo "ssh_key_param=$(terraform output -raw ssh_private_key_ssm_parameter)" >> $GITHUB_OUTPUT
```

2. Added job output to pass SSM parameter name to Ansible job:
```yaml
terraform:
  outputs:
    ssh_key_param: ${{ steps.tf_outputs.outputs.ssh_key_param }}
```

3. Updated SSH configuration to retrieve key from SSM:
```yaml
- name: Configure SSH
  env:
    SSH_KEY_PARAM: ${{ needs.terraform.outputs.ssh_key_param }}
  run: |
    aws ssm get-parameter \
      --name "$SSH_KEY_PARAM" \
      --with-decryption \
      --query 'Parameter.Value' \
      --output text > ~/.ssh/id_rsa
```

4. Added SSH readiness wait loop (EC2 might still be initializing):
```bash
for i in {1..30}; do
  if ssh -o ConnectTimeout=5 ubuntu@$MONITORING_IP "echo SSH is ready"; then
    break
  fi
  sleep 10
done
```

## GitHub Secrets Required

Only 4 secrets are needed (updated from previous 5):

1. `AWS_ACCESS_KEY_ID` - AWS access key
2. `AWS_SECRET_ACCESS_KEY` - AWS secret key  
3. `AWS_REGION` - AWS region (e.g., us-east-1)
4. `GRAFANA_ADMIN_PASSWORD` - Grafana admin password

**Removed**: `MONITORING_SSH_KEY` - No longer needed; retrieved from SSM automatically

## Workflow Flow

The updated deployment flow:

1. **Terraform Job**:
   - Deploys infrastructure
   - Generates SSH key pair
   - Stores private key in SSM Parameter Store
   - Outputs SSM parameter name and monitoring IP
   - Creates Ansible inventory file

2. **Ansible Job**:
   - Retrieves SSM parameter name from Terraform job output
   - Downloads Ansible inventory artifact
   - Retrieves SSH private key from SSM
   - Waits for SSH to be ready
   - Runs Ansible playbook to configure monitoring stack
   - Verifies deployment

## Testing

To test the deployment:

1. Set up GitHub Secrets
2. Push to main branch or trigger workflow manually
3. Monitor workflow execution in GitHub Actions
4. Access services:
   - Prometheus: `http://<IP>:9090`
   - Grafana: `http://<IP>:3000`
   - AlertManager: `http://<IP>:9093`

## Files Modified

- `.github/workflows/deploy.yml` - Fixed Ansible version, SSH key retrieval
- `ansible/ansible.cfg` - Created to specify roles path
- `README.md` - Updated prerequisites and GitHub Secrets documentation

## Additional Improvements

1. **SSH Retry Logic**: Added 30 attempts with 10-second delays to wait for EC2 to be ready
2. **Better Logging**: Added echo statements to show SSH key parameter name and connection status
3. **AWS Credentials**: Ansible job now configures AWS credentials to access SSM
4. **Error Handling**: Improved error messages for debugging

---

**Status**: All critical deployment issues resolved. Workflow should now complete successfully.
