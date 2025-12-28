# S3 Bucket for Backups

resource "aws_s3_bucket" "monitoring_backups" {
  bucket = "monitoring-backups-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "monitoring-backups-${var.environment}"
    Purpose     = "Prometheus and Grafana data backups"
    Environment = var.environment
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "monitoring_backups" {
  bucket = aws_s3_bucket.monitoring_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "monitoring_backups" {
  bucket = aws_s3_bucket.monitoring_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "monitoring_backups" {
  bucket = aws_s3_bucket.monitoring_backups.id

  rule {
    id     = "delete-old-backups"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "monitoring_backups" {
  bucket = aws_s3_bucket.monitoring_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Data source for account ID
data "aws_caller_identity" "current" {}
