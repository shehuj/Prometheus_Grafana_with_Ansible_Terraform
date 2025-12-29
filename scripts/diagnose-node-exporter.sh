#!/bin/bash
# Comprehensive Node Exporter Diagnostic and Fix Script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "Node Exporter Diagnostic & Fix"
echo -e "==========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo -e "${YELLOW}This script should be run with sudo${NC}"
   echo "Usage: sudo $0"
   exit 1
fi

echo "1. Checking if prometheus-node-exporter is installed..."
if dpkg -l | grep -q prometheus-node-exporter; then
    echo -e "${GREEN}✓ Package is installed${NC}"
    dpkg -l | grep prometheus-node-exporter
else
    echo -e "${RED}✗ Package is NOT installed${NC}"
    echo "Installing prometheus-node-exporter..."
    apt-get update
    apt-get install -y prometheus-node-exporter
fi
echo ""

echo "2. Checking service status..."
systemctl status prometheus-node-exporter --no-pager -l || true
echo ""

echo "3. Checking if port 9100 is in use..."
if netstat -tlnp | grep :9100; then
    echo -e "${GREEN}✓ Port 9100 is in use${NC}"
else
    echo -e "${RED}✗ Port 9100 is NOT in use${NC}"
fi
echo ""

echo "4. Checking systemd unit file..."
systemctl cat prometheus-node-exporter | head -20
echo ""

echo "5. Checking configuration file..."
if [ -f /etc/default/prometheus-node-exporter ]; then
    echo -e "${GREEN}✓ Config file exists${NC}"
    cat /etc/default/prometheus-node-exporter
else
    echo -e "${YELLOW}⚠ Config file does not exist, creating...${NC}"
    echo 'ARGS="--web.listen-address=:9100"' > /etc/default/prometheus-node-exporter
fi
echo ""

echo "6. Checking recent logs..."
journalctl -xeu prometheus-node-exporter -n 50 --no-pager || true
echo ""

echo -e "${BLUE}=========================================="
echo "Attempting to fix..."
echo -e "==========================================${NC}"
echo ""

echo "Step 1: Stopping service..."
systemctl stop prometheus-node-exporter || true

echo "Step 2: Ensuring config is correct..."
cat > /etc/default/prometheus-node-exporter <<'EOF'
ARGS="--web.listen-address=:9100"
EOF
echo -e "${GREEN}✓ Config updated${NC}"

echo "Step 3: Reloading systemd daemon..."
systemctl daemon-reload
echo -e "${GREEN}✓ Daemon reloaded${NC}"

echo "Step 4: Starting service..."
if systemctl start prometheus-node-exporter; then
    echo -e "${GREEN}✓ Service started${NC}"
else
    echo -e "${RED}✗ Failed to start service${NC}"
    echo "Checking what went wrong..."
    journalctl -xeu prometheus-node-exporter -n 20 --no-pager
    exit 1
fi

echo "Step 5: Enabling service..."
systemctl enable prometheus-node-exporter
echo -e "${GREEN}✓ Service enabled${NC}"

echo ""
echo -e "${BLUE}=========================================="
echo "Verification"
echo -e "==========================================${NC}"
echo ""

echo "Service status:"
systemctl status prometheus-node-exporter --no-pager -l
echo ""

echo "Port status:"
netstat -tlnp | grep :9100
echo ""

echo "Testing metrics endpoint..."
sleep 2
if curl -s http://localhost:9100/metrics | head -20; then
    echo ""
    echo -e "${GREEN}✓✓✓ Node Exporter is working!${NC}"
    echo ""
    echo "Metrics endpoint: http://localhost:9100/metrics"
    echo "Sample metrics shown above."
else
    echo -e "${RED}✗ Metrics endpoint not responding${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}=========================================="
echo "Summary"
echo -e "==========================================${NC}"
echo ""
echo -e "${GREEN}Node Exporter is now running and accessible!${NC}"
echo ""
echo "Access metrics at:"
echo "  http://localhost:9100/metrics"
echo "  http://$(hostname -I | awk '{print $1}'):9100/metrics"
echo ""
echo "Service is enabled and will start automatically on boot."
echo ""
