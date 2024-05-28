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
  value = local.mathservice_domain
}

output "verifyservice_alb_dns_name" {
  value = local.verifyservice_domain
}

