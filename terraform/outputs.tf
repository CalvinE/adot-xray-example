output "mathservice_ecr_url" {
  value = aws_ecr_repository.mathservice_ecr.repository_url
}

output "verifyservice_ecr_url" {
  value = aws_ecr_repository.verifyservice_ecr.repository_url
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "mathservice_alb_dns_name" {
  value = module.mathservice_app.alb_dns_name
}

output "verifyservice_alb_dns_name" {
  value = module.verifyservice_app.alb_dns_name
}

