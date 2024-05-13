output "mathservice_ecr_url" {
  value = aws_ecr_repository.mathservice_ecr.repository_url
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_dns_name" {
  value = aws_alb.mathservice.dns_name
}

