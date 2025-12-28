# Terraform Outputs

output "monitoring_server_public_ip" {
  description = "Public IP address of the monitoring server"
  value       = aws_eip.monitoring.public_ip
}

output "monitoring_server_private_ip" {
  description = "Private IP address of the monitoring server"
  value       = aws_instance.monitoring.private_ip
}

output "monitoring_server_id" {
  description = "Instance ID of the monitoring server"
  value       = aws_instance.monitoring.id
}

output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = "http://${aws_eip.monitoring.public_ip}:9090"
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "http://${aws_eip.monitoring.public_ip}:3000"
}

output "alertmanager_url" {
  description = "URL to access AlertManager"
  value       = "http://${aws_eip.monitoring.public_ip}:9093"
}

output "ssh_command" {
  description = "SSH command to connect to monitoring server"
  value       = "ssh -i monitoring-key.pem ubuntu@${aws_eip.monitoring.public_ip}"
}

output "ssh_private_key_ssm_parameter" {
  description = "SSM parameter name containing SSH private key"
  value       = aws_ssm_parameter.monitoring_private_key.name
  sensitive   = true
}

output "backup_bucket_name" {
  description = "S3 bucket name for backups"
  value       = aws_s3_bucket.monitoring_backups.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.monitoring.id
}

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = aws_subnet.public[*].id
}

output "security_group_id" {
  description = "Security group ID for monitoring server"
  value       = aws_security_group.monitoring.id
}

output "ansible_inventory" {
  description = "Ansible inventory file content"
  value = templatefile("${path.module}/templates/inventory.tpl", {
    monitoring_ip = aws_eip.monitoring.public_ip
    environment   = var.environment
  })
}
