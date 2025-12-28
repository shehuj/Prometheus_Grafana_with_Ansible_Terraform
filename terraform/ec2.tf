# EC2 Instance for Monitoring Server

# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Generate SSH Key Pair
resource "tls_private_key" "monitoring" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "monitoring" {
  key_name   = "monitoring-key-${var.environment}"
  public_key = tls_private_key.monitoring.public_key_openssh

  tags = {
    Name = "monitoring-key-${var.environment}"
  }
}

# Store private key in SSM Parameter Store (encrypted)
resource "aws_ssm_parameter" "monitoring_private_key" {
  name        = "/monitoring/${var.environment}/ssh-private-key"
  description = "SSH private key for monitoring server"
  type        = "SecureString"
  value       = tls_private_key.monitoring.private_key_pem

  tags = {
    Name = "monitoring-ssh-key-${var.environment}"
  }
}

# IAM Role for EC2 Instance
resource "aws_iam_role" "monitoring" {
  name = "monitoring-server-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "monitoring-server-role-${var.environment}"
  }
}

# IAM Policy for CloudWatch and SSM
resource "aws_iam_role_policy" "monitoring" {
  name = "monitoring-server-policy"
  role = aws_iam_role.monitoring.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.monitoring_backups.arn,
          "${aws_s3_bucket.monitoring_backups.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "monitoring" {
  name = "monitoring-server-profile-${var.environment}"
  role = aws_iam_role.monitoring.name

  tags = {
    Name = "monitoring-server-profile-${var.environment}"
  }
}

# EC2 Instance
resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.monitoring_instance_type
  key_name               = aws_key_pair.monitoring.key_name
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  subnet_id              = aws_subnet.public[0].id
  iam_instance_profile   = aws_iam_instance_profile.monitoring.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.monitoring_volume_size
    delete_on_termination = false
    encrypted             = true

    tags = {
      Name = "monitoring-root-volume-${var.environment}"
    }
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    environment     = var.environment
    retention_days  = var.retention_days
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  monitoring = true  # Enable detailed monitoring

  tags = {
    Name = "monitoring-server-${var.environment}"
    Type = "Monitoring"
  }

  lifecycle {
    ignore_changes = [
      ami,  # Don't replace instance on AMI updates
      user_data  # Don't replace instance on user data changes
    ]
  }
}

# Elastic IP
resource "aws_eip" "monitoring" {
  instance = aws_instance.monitoring.id
  domain   = "vpc"

  tags = {
    Name = "monitoring-eip-${var.environment}"
  }

  depends_on = [aws_internet_gateway.monitoring]
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "monitoring_cpu" {
  count = var.enable_monitoring_alarms ? 1 : 0

  alarm_name          = "monitoring-server-high-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Monitoring server CPU utilization is too high"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    InstanceId = aws_instance.monitoring.id
  }

  tags = {
    Name = "monitoring-cpu-alarm-${var.environment}"
  }
}

resource "aws_cloudwatch_metric_alarm" "monitoring_disk" {
  count = var.enable_monitoring_alarms ? 1 : 0

  alarm_name          = "monitoring-server-low-disk-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DiskSpaceUtilization"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "Monitoring server disk space is low"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    InstanceId = aws_instance.monitoring.id
  }

  tags = {
    Name = "monitoring-disk-alarm-${var.environment}"
  }
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  count = var.alert_email != "" ? 1 : 0

  name = "monitoring-alerts-${var.environment}"

  tags = {
    Name = "monitoring-alerts-${var.environment}"
  }
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}
