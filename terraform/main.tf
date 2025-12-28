# Production-Ready Monitoring Infrastructure with Terraform
# Provisions EC2 instance for Prometheus + Grafana

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "monitoring-terraform-state"
    key            = "prometheus-grafana/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "monitoring-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Monitoring Infrastructure"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = "DevOps"
    }
  }
}
