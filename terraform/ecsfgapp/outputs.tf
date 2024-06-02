output "dns_names" {
  description = "The dns name for the ALB"
  value       = var.listener_rule_host_values
}

output "ecr_url" {
  description = "The url of the ECR for this app"
  value       = aws_ecr_repository.this.repository_url
}

// TODO: populate this...
