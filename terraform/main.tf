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
    bucket         = "ec2-shutdown-lambda-bucket"
    key            = "prometheus-grafana/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "dyning_table"
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
