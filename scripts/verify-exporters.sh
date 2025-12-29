#!/bin/bash
# Verify Node Exporter and Blackbox Exporter are working

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "Exporter Verification Script"
echo "======================================"
echo ""

# Function to check service
check_service() {
    local service_name=$1
    local endpoint=$2

    echo -n "Checking $service_name... "

    if curl -s -f "$endpoint" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Running${NC}"
        return 0
    else
        echo -e "${RED}✗ Not responding${NC}"
        return 1
    fi
}

# Function to check systemd service
check_systemd_service() {
    local service_name=$1

    echo -n "Checking systemd service $service_name... "

    if systemctl is-active --quiet "$service_name"; then
        echo -e "${GREEN}✓ Active${NC}"
        return 0
    else
        echo -e "${RED}✗ Inactive${NC}"
        systemctl status "$service_name" --no-pager || true
        return 1
    fi
}

# Function to check Docker container
check_container() {
    local container_name=$1

    echo -n "Checking Docker container $container_name... "

    if docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
        echo -e "${GREEN}✓ Running${NC}"
        return 0
    else
        echo -e "${RED}✗ Not running${NC}"
        echo "Container status:"
        docker ps -a --filter "name=$container_name" --format "table {{.Names}}\t{{.Status}}" || true
        return 1
    fi
}

echo "1. Node Exporter"
echo "=================="
check_systemd_service "prometheus-node-exporter"
check_service "Node Exporter metrics" "http://localhost:9100/metrics"
echo ""

echo "2. Blackbox Exporter"
echo "===================="
check_container "blackbox-exporter"
check_service "Blackbox Exporter metrics" "http://localhost:9115/metrics"
echo ""

echo "3. Prometheus"
echo "============="
check_container "prometheus"
check_service "Prometheus" "http://localhost:9090/-/ready"
echo ""

echo "4. Prometheus Targets"
echo "====================="
echo "Checking Prometheus scrape targets..."

if curl -s "http://localhost:9090/api/v1/targets" > /tmp/prometheus-targets.json 2>&1; then
    echo -e "${GREEN}✓ Prometheus API accessible${NC}"

    # Check node-exporter target
    if grep -q '"job":"node-exporter"' /tmp/prometheus-targets.json; then
        node_health=$(jq -r '.data.activeTargets[] | select(.labels.job=="node-exporter") | .health' /tmp/prometheus-targets.json 2>/dev/null || echo "unknown")
        if [ "$node_health" == "up" ]; then
            echo -e "  Node Exporter target: ${GREEN}✓ UP${NC}"
        else
            echo -e "  Node Exporter target: ${RED}✗ DOWN${NC}"
        fi
    else
        echo -e "  Node Exporter target: ${RED}✗ Not found in Prometheus${NC}"
    fi

    # Check blackbox target
    if grep -q '"job":"blackbox"' /tmp/prometheus-targets.json; then
        blackbox_health=$(jq -r '.data.activeTargets[] | select(.labels.job=="blackbox") | .health' /tmp/prometheus-targets.json 2>/dev/null || echo "unknown")
        if [ "$blackbox_health" == "up" ]; then
            echo -e "  Blackbox Exporter target: ${GREEN}✓ UP${NC}"
        else
            echo -e "  Blackbox Exporter target: ${RED}✗ DOWN${NC}"
        fi
    else
        echo -e "  Blackbox Exporter target: ${YELLOW}⚠ Not found in Prometheus${NC}"
        echo "    (This might be normal if no probe targets are configured)"
    fi

    rm -f /tmp/prometheus-targets.json
else
    echo -e "${RED}✗ Could not access Prometheus API${NC}"
fi

echo ""
echo "======================================"
echo "Verification Complete"
echo "======================================"
echo ""
echo "Access URLs:"
echo "  Node Exporter: http://$(hostname -I | awk '{print $1}'):9100/metrics"
echo "  Blackbox Exporter: http://$(hostname -I | awk '{print $1}'):9115/metrics"
echo "  Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo "  Prometheus Targets: http://$(hostname -I | awk '{print $1}'):9090/targets"
echo ""
