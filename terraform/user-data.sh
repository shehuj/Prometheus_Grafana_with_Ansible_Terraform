#!/bin/bash
# User Data Script for Monitoring Server
# Runs on first boot to prepare the instance

set -e

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install basic tools
apt-get install -y \
    curl \
    wget \
    vim \
    git \
    htop \
    unzip \
    python3 \
    python3-pip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install AWS CLI v2
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# Create directories for monitoring data
mkdir -p /opt/monitoring/{prometheus,grafana,alertmanager}
mkdir -p /var/lib/prometheus
mkdir -p /var/lib/grafana
mkdir -p /var/lib/alertmanager

# Set ownership
chown -R 65534:65534 /var/lib/prometheus  # nobody user for Prometheus
chown -R 472:472 /var/lib/grafana  # grafana user

# Create directory for configurations
mkdir -p /etc/prometheus
mkdir -p /etc/grafana
mkdir -p /etc/alertmanager

# Set hostname
hostnamectl set-hostname monitoring-server-${environment}

# Configure sysctl for Prometheus
cat >> /etc/sysctl.conf <<EOF
# Prometheus optimizations
vm.max_map_count=262144
fs.file-max=65536
EOF
sysctl -p

# Install node_exporter
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.7.0*

# Create node_exporter systemd service
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=nobody
Group=nogroup
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Signal completion
echo "User data script completed successfully" > /var/log/user-data-complete.log
