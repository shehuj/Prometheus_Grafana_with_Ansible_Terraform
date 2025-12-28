# VPC and Networking Configuration

# VPC
resource "aws_vpc" "monitoring" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "monitoring-vpc-${var.environment}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "monitoring" {
  vpc_id = aws_vpc.monitoring.id

  tags = {
    Name = "monitoring-igw-${var.environment}"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.monitoring.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "monitoring-public-subnet-${count.index + 1}-${var.environment}"
    Tier = "Public"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.monitoring.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.monitoring.id
  }

  tags = {
    Name = "monitoring-public-rt-${var.environment}"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# VPC Flow Logs
resource "aws_flow_log" "monitoring" {
  count = var.environment == "production" ? 1 : 0

  iam_role_arn    = aws_iam_role.vpc_flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.monitoring.id

  tags = {
    Name = "monitoring-vpc-flow-logs-${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.environment == "production" ? 1 : 0

  name              = "/aws/vpc/monitoring-${var.environment}"
  retention_in_days = 7

  tags = {
    Name = "monitoring-vpc-flow-logs-${var.environment}"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.environment == "production" ? 1 : 0

  name = "monitoring-vpc-flow-logs-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "monitoring-vpc-flow-logs-role-${var.environment}"
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.environment == "production" ? 1 : 0

  name = "monitoring-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
