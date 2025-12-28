# Input Variables

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "DevOps Team"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "monitoring_instance_type" {
  description = "EC2 instance type for monitoring server"
  type        = string
  default     = "t3.large"
}

variable "monitoring_volume_size" {
  description = "EBS volume size for monitoring data (GB)"
  type        = number
  default     = 100
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production!
}

variable "allowed_monitoring_cidrs" {
  description = "CIDR blocks allowed to access monitoring interfaces"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production!
}

variable "enable_monitoring_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email for CloudWatch alerts"
  type        = string
  default     = ""
}

variable "retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 30
}
