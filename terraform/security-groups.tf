# Security Groups

# Monitoring Server Security Group
resource "aws_security_group" "monitoring" {
  name        = "monitoring-server-sg-${var.environment}"
  description = "Security group for Prometheus and Grafana monitoring server"
  vpc_id      = aws_vpc.monitoring.id

  tags = {
    Name = "monitoring-server-sg-${var.environment}"
  }
}

# SSH Access
resource "aws_security_group_rule" "monitoring_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidrs
  security_group_id = aws_security_group.monitoring.id
  description       = "SSH access"
}

# Prometheus Access
resource "aws_security_group_rule" "monitoring_prometheus" {
  type              = "ingress"
  from_port         = 9090
  to_port           = 9090
  protocol          = "tcp"
  cidr_blocks       = var.allowed_monitoring_cidrs
  security_group_id = aws_security_group.monitoring.id
  description       = "Prometheus web interface"
}

# Grafana Access
resource "aws_security_group_rule" "monitoring_grafana" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = var.allowed_monitoring_cidrs
  security_group_id = aws_security_group.monitoring.id
  description       = "Grafana web interface"
}

# AlertManager Access
resource "aws_security_group_rule" "monitoring_alertmanager" {
  type              = "ingress"
  from_port         = 9093
  to_port           = 9093
  protocol          = "tcp"
  cidr_blocks       = var.allowed_monitoring_cidrs
  security_group_id = aws_security_group.monitoring.id
  description       = "AlertManager web interface"
}

# Node Exporter Access (for targets to scrape)
resource "aws_security_group_rule" "monitoring_node_exporter" {
  type              = "ingress"
  from_port         = 9100
  to_port           = 9100
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.monitoring.id
  description       = "Node Exporter metrics"
}

# Blackbox Exporter Access
resource "aws_security_group_rule" "monitoring_blackbox" {
  type              = "ingress"
  from_port         = 9115
  to_port           = 9115
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.monitoring.id
  description       = "Blackbox Exporter"
}

# Egress - Allow all outbound
resource "aws_security_group_rule" "monitoring_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.monitoring.id
  description       = "Allow all outbound traffic"
}
