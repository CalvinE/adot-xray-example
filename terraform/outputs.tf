output "mathservice_ecr_url" {
  value = aws_ecr_repository.mathservice_ecr.repository_url
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "mathservice_alb_dns_name" {
  value = module.mathservice_app.alb_dns_name
}

