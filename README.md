# Production-Ready Monitoring Infrastructure with Prometheus & Grafana

A fully automated, production-grade monitoring solution deployed on AWS using Terraform, Ansible, and GitHub Actions. This infrastructure provides real-time metrics collection, visualization, and alerting for your applications and infrastructure.

## Architecture Overview

This solution deploys a complete monitoring stack on AWS:

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    VPC (10.0.0.0/16)                  │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────┐     │  │
│  │  │      EC2 Instance (Monitoring Server)       │     │  │
│  │  │                                             │     │  │
│  │  │  ┌──────────────┐  ┌──────────────┐        │     │  │
│  │  │  │ Prometheus   │  │   Grafana    │        │     │  │
│  │  │  │   :9090      │◄─┤    :3000     │        │     │  │
│  │  │  └──────┬───────┘  └──────────────┘        │     │  │
│  │  │         │                                   │     │  │
│  │  │         │          ┌──────────────┐        │     │  │
│  │  │         ├─────────►│ AlertManager │        │     │  │
│  │  │         │          │    :9093     │        │     │  │
│  │  │         │          └──────────────┘        │     │  │
│  │  │         │                                   │     │  │
│  │  │         │          ┌──────────────┐        │     │  │
│  │  │         ├─────────►│Node Exporter │        │     │  │
│  │  │         │          │    :9100     │        │     │  │
│  │  │         │          └──────────────┘        │     │  │
│  │  │         │                                   │     │  │
│  │  │         │          ┌──────────────┐        │     │  │
│  │  │         └─────────►│   Blackbox   │        │     │  │
│  │  │                    │   Exporter   │        │     │  │
│  │  │                    │    :9115     │        │     │  │
│  │  │                    └──────────────┘        │     │  │
│  │  └─────────────────────────────────────────────┘     │  │
│  │                                                       │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────┐         ┌──────────────────┐          │
│  │   S3 Bucket     │         │   CloudWatch     │          │
│  │  (Backups)      │         │    Alarms        │          │
│  └─────────────────┘         └──────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### Components

- **Prometheus (v2.48.1)**: Time-series database for metrics collection and storage
- **Grafana (10.2.3)**: Visualization and dashboarding platform
- **AlertManager (v0.26.0)**: Alert routing and notification management
- **Node Exporter**: System-level metrics (CPU, memory, disk, network)
- **Blackbox Exporter**: Endpoint health monitoring (HTTP probes)

### Infrastructure Components

- **VPC**: Isolated network with public subnet
- **EC2 Instance**: t3.large instance running monitoring stack
- **Security Groups**: Fine-grained network access control
- **S3 Bucket**: Encrypted storage for backups with lifecycle policies
- **CloudWatch**: Instance monitoring and alarms
- **IAM Roles**: Secure service permissions
- **SNS Topics**: Alert notifications

## Features

- **Fully Automated Deployment**: One-command deployment via Terraform and Ansible
- **High Availability**: Health checks, auto-recovery, and backup strategies
- **Security Hardened**:
  - Encrypted S3 storage
  - IMDSv2 for EC2 metadata
  - Restrictive security groups
  - SSH key auto-generation
- **Cost Optimized**:
  - S3 lifecycle policies (STANDARD → IA → GLACIER)
  - Right-sized instances
  - Configurable retention periods
- **Production Ready**:
  - Pre-configured alert rules
  - Grafana datasources auto-provisioned
  - Comprehensive health checks
  - Automated backups

## Prerequisites

Before deploying this infrastructure, ensure you have:

### Required Tools

- **Terraform** >= 1.6.0 ([Install](https://developer.hashicorp.com/terraform/downloads))
- **Ansible** >= 8.0.0 ([Install](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html))
- **AWS CLI** ([Install](https://aws.amazon.com/cli/))
- **Git**

### AWS Requirements

- AWS account with appropriate permissions
- AWS credentials configured (`aws configure`)
- Permissions to create:
  - VPC, Subnets, Route Tables, Internet Gateway
  - EC2 instances, Security Groups
  - S3 buckets
  - IAM roles and policies
  - CloudWatch alarms and SNS topics
  - SSM Parameter Store parameters

### GitHub Secrets (for CI/CD)

Configure these secrets in your GitHub repository:

```
AWS_ACCESS_KEY_ID         # AWS access key
AWS_SECRET_ACCESS_KEY     # AWS secret key
AWS_REGION                # AWS region (e.g., us-east-1)
MONITORING_SSH_KEY        # Will be auto-generated by Terraform
GRAFANA_ADMIN_PASSWORD    # Grafana admin password
```

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/Prometheus_Grafana_with_Ansible_Terraform.git
cd Prometheus_Grafana_with_Ansible_Terraform
```

### 2. Set Up Terraform Backend

Create the S3 bucket and DynamoDB table for Terraform state:

```bash
cd scripts
chmod +x setup-backend.sh
./setup-backend.sh
cd ..
```

### 3. Configure Variables

Create a `terraform/terraform.tfvars` file:

```hcl
project_name = "monitoring"
environment  = "production"
aws_region   = "us-east-1"

# Network Configuration
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
availability_zones  = ["us-east-1a", "us-east-1b"]

# EC2 Configuration
instance_type    = "t3.large"
volume_size      = 50
monitoring_enabled = true

# Access Control
allowed_ssh_cidrs = ["YOUR_IP/32"]  # Replace with your IP
allowed_web_cidrs = ["0.0.0.0/0"]   # Open to all, or restrict

# Monitoring Configuration
prometheus_retention_days = 30
backup_retention_days     = 90

# Tags
tags = {
  Project     = "Monitoring"
  Environment = "Production"
  ManagedBy   = "Terraform"
}
```

### 4. Deploy Infrastructure

#### Option A: Manual Deployment

```bash
# Initialize Terraform
cd terraform
terraform init

# Review the plan
terraform plan

# Apply the infrastructure
terraform apply

# Note the outputs (monitoring server IP, SSH command, etc.)
terraform output
```

#### Option B: GitHub Actions Deployment

1. Push your code to the `main` branch
2. GitHub Actions will automatically:
   - Run `terraform plan`
   - Apply infrastructure changes
   - Configure the server with Ansible
   - Verify the deployment

Or trigger manually:

1. Go to Actions → Deploy Monitoring Infrastructure
2. Click "Run workflow"
3. Select action: `plan`, `apply`, or `destroy`

### 5. Configure with Ansible

If deploying manually (GitHub Actions does this automatically):

```bash
# Wait for EC2 instance to be ready (2-3 minutes)
sleep 180

# Generate inventory from Terraform
cd ../ansible
terraform output -raw ansible_inventory > inventory/hosts.ini

# Run the playbook
export GRAFANA_ADMIN_PASSWORD="your-secure-password"
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -v
```

### 6. Access Your Monitoring Stack

After deployment completes (5-10 minutes total):

**Prometheus**: `http://<MONITORING_IP>:9090`
- Metrics explorer and query interface
- Alert rule management

**Grafana**: `http://<MONITORING_IP>:3000`
- Username: `admin`
- Password: Your `GRAFANA_ADMIN_PASSWORD`
- Pre-configured Prometheus datasource

**AlertManager**: `http://<MONITORING_IP>:9093`
- Alert management and silencing

Get the monitoring IP:
```bash
cd terraform
terraform output monitoring_server_public_ip
```

## Configuration

### Prometheus Configuration

Edit `configs/prometheus/prometheus.yml` to add your application targets:

```yaml
scrape_configs:
  # Add your custom application
  - job_name: 'my-application'
    static_configs:
      - targets: ['your-app-server:8080']
        labels:
          environment: 'production'
          team: 'backend'
```

### Alert Rules

Add custom alerts in `configs/prometheus/alert-rules.yml`:

```yaml
groups:
  - name: application_alerts
    interval: 30s
    rules:
      - alert: ApplicationDown
        expr: up{job="my-application"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Application is down"
          description: "{{ $labels.instance }} has been down for 5 minutes"
```

### Grafana Dashboards

Import community dashboards:

1. Log into Grafana
2. Navigate to Dashboards → Import
3. Use these dashboard IDs:
   - **1860**: Node Exporter Full
   - **3662**: Prometheus 2.0 Overview
   - **7587**: Prometheus Blackbox Exporter

Or create custom dashboards using the Prometheus datasource.

### Resource Limits

Adjust service resources in `ansible/playbooks/site.yml`:

```yaml
prometheus:
  deploy:
    resources:
      limits:
        cpus: '2.0'      # Adjust based on workload
        memory: 2G       # Increase for more metrics
      reservations:
        cpus: '1.0'
        memory: 1G
```

## Monitoring Capabilities

### Pre-Configured Metrics

Out of the box, you'll monitor:

**System Metrics** (Node Exporter):
- CPU usage, load average
- Memory utilization
- Disk space and I/O
- Network traffic
- System uptime

**Service Health** (Blackbox Exporter):
- HTTP endpoint availability
- Response times
- SSL certificate expiration

**Prometheus Internals**:
- TSDB compaction status
- Query performance
- Storage utilization

### Pre-Configured Alerts

Default alert rules include:

- **InstanceDown**: Instance unreachable for 5 minutes
- **HighCPUUsage**: CPU > 80% for 10 minutes
- **HighMemoryUsage**: Memory > 85% for 10 minutes
- **DiskSpaceLow**: Disk space < 15%
- **PrometheusTSDBCompactionsFailing**: TSDB issues

## Operational Guide

### Viewing Metrics

**Prometheus Query Examples**:

```promql
# CPU usage per instance
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk space available
(node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100
```

### Managing Alerts

**View Active Alerts**:
- Prometheus: `http://<IP>:9090/alerts`
- AlertManager: `http://<IP>:9093`

**Silence Alerts**:
1. Go to AlertManager UI
2. Click "New Silence"
3. Set matchers (e.g., `alertname="HighCPUUsage"`)
4. Set duration and comment

### Backup and Restore

**Manual Backup**:
```bash
# SSH into monitoring server
ssh -i ~/.ssh/monitoring-key ubuntu@<MONITORING_IP>

# Create backup
sudo tar -czf /tmp/prometheus-backup-$(date +%Y%m%d).tar.gz /var/lib/prometheus
sudo tar -czf /tmp/grafana-backup-$(date +%Y%m%d).tar.gz /var/lib/grafana

# Upload to S3
aws s3 cp /tmp/prometheus-backup-*.tar.gz s3://monitoring-backups-<account-id>/
aws s3 cp /tmp/grafana-backup-*.tar.gz s3://monitoring-backups-<account-id>/
```

**Automated Backups**:
S3 lifecycle policies automatically manage backup retention:
- 0-30 days: STANDARD storage
- 30-90 days: STANDARD_IA (Infrequent Access)
- 90-365 days: GLACIER
- 365+ days: Automatically deleted

### Updating Services

**Update Docker Images**:

Edit `ansible/playbooks/site.yml` and change version variables:

```yaml
vars:
  prometheus_version: "v2.49.0"  # Update version
  grafana_version: "10.3.0"
```

Re-run Ansible:
```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -v
```

### Scaling Considerations

**Increase Retention**:

Edit `terraform/terraform.tfvars`:
```hcl
prometheus_retention_days = 60  # Increase from 30
```

Apply changes:
```bash
terraform apply
```

**Upgrade Instance Size**:

Edit `terraform/terraform.tfvars`:
```hcl
instance_type = "t3.xlarge"  # Upgrade from t3.large
volume_size   = 100          # Increase storage
```

Apply and let Terraform handle the migration.

## Troubleshooting

### Issue: Cannot access Grafana/Prometheus

**Check Security Group**:
```bash
# Verify your IP is allowed
aws ec2 describe-security-groups --group-ids <SG_ID>

# Update if needed
terraform apply
```

**Check Services**:
```bash
ssh -i ~/.ssh/monitoring-key ubuntu@<IP>
sudo docker ps
sudo docker logs prometheus
sudo docker logs grafana
```

### Issue: Prometheus not scraping targets

**Verify Configuration**:
```bash
# SSH to server
ssh -i ~/.ssh/monitoring-key ubuntu@<IP>

# Check config
cat /etc/prometheus/prometheus.yml

# Check Prometheus logs
sudo docker logs prometheus

# Reload config
curl -X POST http://localhost:9090/-/reload
```

**Check Targets**:
Navigate to `http://<IP>:9090/targets` and verify target status.

### Issue: High disk usage

**Check Prometheus TSDB**:
```bash
# SSH to server
du -sh /var/lib/prometheus/*

# Reduce retention if needed
sudo docker stop prometheus
# Edit retention in site.yml
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

### Issue: Terraform state locked

**Unlock State**:
```bash
# Get lock ID from error message
terraform force-unlock <LOCK_ID>
```

### Issue: Ansible connection timeout

**Verify SSH Access**:
```bash
# Test SSH connection
ssh -i ~/.ssh/monitoring-key ubuntu@<IP>

# Check security group allows SSH from your IP
# Verify instance is running
aws ec2 describe-instances --instance-ids <INSTANCE_ID>
```

### Issue: GitHub Actions deployment fails

**Check Secrets**:
- Verify all required secrets are configured
- Ensure AWS credentials have correct permissions

**Check Workflow Logs**:
- Navigate to Actions tab
- Click on failed workflow
- Review step-by-step logs

## Cost Breakdown

Estimated monthly costs (us-east-1 region):

| Service | Specification | Monthly Cost |
|---------|--------------|--------------|
| EC2 (t3.large) | On-Demand | ~$60.74 |
| EBS (50 GB) | gp3 SSD | ~$4.00 |
| S3 Storage | 10 GB backups | ~$0.23 |
| Data Transfer | 10 GB outbound | ~$0.90 |
| CloudWatch | Basic monitoring | ~$3.00 |
| **Total** | | **~$68.87/month** |

**Cost Optimization Tips**:

1. **Reserved Instances**: Save up to 72% with 1-year or 3-year commitments
2. **Spot Instances**: Not recommended for production monitoring
3. **Reduce Retention**: Lower `prometheus_retention_days` to reduce storage
4. **S3 Lifecycle**: Already implemented for backup cost optimization
5. **Right-Size Instance**: Monitor actual usage and downgrade if possible

## Security Considerations

### Implemented Security Measures

1. **Network Security**:
   - Restrictive security groups (principle of least privilege)
   - Configurable CIDR blocks for SSH and web access
   - Private subnet option for enhanced security

2. **Encryption**:
   - S3 server-side encryption (AES-256)
   - EBS volume encryption
   - Encrypted Terraform state in S3

3. **Access Control**:
   - IAM roles with minimal required permissions
   - Auto-generated SSH keys stored in SSM Parameter Store
   - No hardcoded credentials

4. **Instance Security**:
   - IMDSv2 required (protects against SSRF attacks)
   - Automatic security updates via user-data
   - CloudWatch monitoring and alarms

### Additional Hardening (Recommended)

1. **Enable HTTPS**:
   ```bash
   # Use AWS Certificate Manager + ALB
   # Or configure nginx reverse proxy with Let's Encrypt
   ```

2. **Enable Grafana Authentication**:
   ```yaml
   # Configure OAuth, LDAP, or SAML in Grafana
   GF_AUTH_GOOGLE_ENABLED: "true"
   GF_AUTH_GOOGLE_CLIENT_ID: "your-client-id"
   ```

3. **Restrict Web Access**:
   ```hcl
   # In terraform.tfvars
   allowed_web_cidrs = ["YOUR_OFFICE_IP/32"]  # Instead of 0.0.0.0/0
   ```

4. **Enable VPC Flow Logs**:
   ```hcl
   # In terraform.tfvars
   enable_flow_logs = true
   ```

5. **Set Up AlertManager Notifications**:
   ```yaml
   # Configure email, Slack, PagerDuty in alertmanager.yml
   receivers:
     - name: 'team-email'
       email_configs:
         - to: 'alerts@example.com'
   ```

## Maintenance

### Regular Tasks

**Weekly**:
- Review Grafana dashboards for anomalies
- Check alert history in AlertManager
- Verify backup creation in S3

**Monthly**:
- Review CloudWatch costs
- Update Grafana dashboards
- Test alert notifications
- Review and update alert thresholds

**Quarterly**:
- Update Docker images to latest stable versions
- Review and optimize Prometheus retention
- Audit IAM permissions
- Test disaster recovery procedures

### Updating the Stack

**Update Terraform Modules**:
```bash
cd terraform
terraform get -update
terraform plan
terraform apply
```

**Update Ansible Playbooks**:
```bash
cd ansible
git pull origin main
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -v
```

## Disaster Recovery

### Backup Strategy

1. **Prometheus Data**: Stored in EBS with snapshots
2. **Grafana Dashboards**: Exported to S3 nightly
3. **Configuration Files**: Version controlled in Git
4. **State Files**: Terraform state in S3 with versioning

### Recovery Procedure

**Complete Infrastructure Loss**:
```bash
# 1. Restore Terraform state (if needed)
aws s3 cp s3://monitoring-terraform-state/prometheus-grafana/terraform.tfstate ./

# 2. Re-deploy infrastructure
terraform apply -auto-approve

# 3. Restore data from S3
ssh -i ~/.ssh/monitoring-key ubuntu@<NEW_IP>
aws s3 cp s3://monitoring-backups/latest-prometheus-backup.tar.gz /tmp/
sudo tar -xzf /tmp/latest-prometheus-backup.tar.gz -C /

# 4. Restart services
sudo docker restart prometheus grafana
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:

- Open a GitHub Issue
- Check existing documentation
- Review Terraform/Ansible logs

## Acknowledgments

- [Prometheus](https://prometheus.io/) - Monitoring system and time series database
- [Grafana](https://grafana.com/) - Analytics and monitoring platform
- [AlertManager](https://prometheus.io/docs/alerting/latest/alertmanager/) - Alert routing
- [Terraform](https://www.terraform.io/) - Infrastructure as Code
- [Ansible](https://www.ansible.com/) - Configuration management

## Changelog

### v1.0.0 (2025-12-28)
- Initial release
- Terraform infrastructure for AWS
- Ansible playbooks for configuration
- GitHub Actions CI/CD pipeline
- Pre-configured Prometheus, Grafana, AlertManager
- Comprehensive documentation

---

Built with automation and best practices for production monitoring infrastructure.
