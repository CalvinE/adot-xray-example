output "mathservice_ecr_url" {
  value = module.mathservice_app.ecr_url
}

output "verifyservice_ecr_url" {
  value = module.verifyservice_app.ecr_url
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

