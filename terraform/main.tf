terraform {
  required_version = "~> 1.8"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  region        = "us-east-2"
  external_port = 443
  tld           = "cechols.com"
}

# Configure the AWS Provider
provider "aws" {
  region = local.region
  default_tags {
    tags = {
      Source = "adot-xray-example"
    }
  }
}

locals {
  apps_domain            = "apps.${local.tld}"
  vpc_cidr               = "10.0.0.0/16"
  mathservice_app_name   = "mathservice"
  mathservice_domain     = "${local.mathservice_app_name}.${local.apps_domain}"
  verifyservice_app_name = "verifyservice"
  verifyservice_domain   = "${local.verifyservice_app_name}.${local.apps_domain}"
  azs = [
    {
      public_cidr  = "10.0.1.0/24"
      private_cidr = "10.0.2.0/24"
      az           = "us-east-2a"
    },
    {
      public_cidr  = "10.0.3.0/24"
      private_cidr = "10.0.4.0/24"
      az           = "us-east-2b"
    }

  ]
}
# Create Elastic Container Registry
resource "aws_ecr_repository" "mathservice_ecr" {
  name         = local.mathservice_app_name
  force_delete = true
}

resource "aws_ecr_repository" "verifyservice_ecr" {
  name         = local.verifyservice_app_name
  force_delete = true
}

resource "aws_alb" "this" {
  name            = "adot-demo-lb"
  subnets         = values(module.azs)[*].public_subnet_id
  security_groups = [aws_security_group.lb.id]
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_alb.this.arn
  port              = local.external_port
  // TODO: make configurable
  protocol        = "HTTPS"
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = aws_acm_certificate.adot_apps.arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = ""
      status_code  = "404"
    }
  }
}

# Security Group Resources
resource "aws_security_group" "lb" {
  name_prefix = "adot example allow app traffic"
  vpc_id      = module.vpc.vpc_id
  // TODO: make this dynamic incase there are multiple ports
  ingress {
    from_port        = local.external_port
    to_port          = local.external_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# ECS Resources
resource "aws_ecs_cluster" "main" {
  name = "adot-cluster"
}

# Route 53 Resources
data "aws_route53_zone" "tld" {
  name = local.tld
}

resource "aws_route53_zone" "apps" {
  name = local.apps_domain
}

resource "aws_route53_record" "apps_ns" {
  zone_id = data.aws_route53_zone.tld.zone_id
  name    = local.apps_domain
  type    = "NS"
  ttl     = 30
  records = aws_route53_zone.apps.name_servers
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.adot_apps.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = aws_route53_zone.apps.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

resource "aws_route53_record" "mathservice" {
  zone_id = aws_route53_zone.apps.zone_id
  name    = local.mathservice_domain
  type    = "A"

  alias {
    name                   = aws_alb.this.dns_name
    zone_id                = aws_alb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "verifyservice" {
  zone_id = aws_route53_zone.apps.zone_id
  name    = local.verifyservice_domain
  type    = "A"

  alias {
    name                   = aws_alb.this.dns_name
    zone_id                = aws_alb.this.zone_id
    evaluate_target_health = true
  }
}

# ACM Resources
resource "aws_acm_certificate" "adot_apps" {
  domain_name       = local.apps_domain
  validation_method = "DNS"
  subject_alternative_names = [
    local.mathservice_domain,
    local.verifyservice_domain
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "adot_apps" {
  certificate_arn         = aws_acm_certificate.adot_apps.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

module "vpc" {
  source   = "./vpc"
  vpc_cidr = local.vpc_cidr
}

module "azs" {
  for_each            = { for x in local.azs : x.az => x }
  source              = "./pubprisubnet"
  vpc_id              = module.vpc.vpc_id
  internet_gateway_id = module.vpc.internet_gateway_id

  public_cidr       = each.value.public_cidr
  private_cidr      = each.value.private_cidr
  availability_zone = each.value.az
}

module "mathservice_app" {
  source                        = "./ecsfgapp"
  vpc_id                        = module.vpc.vpc_id
  public_subnet_ids             = values(module.azs)[*].public_subnet_id
  private_subnet_ids            = values(module.azs)[*].private_subnet_id
  app_name                      = local.mathservice_app_name
  external_port                 = 80
  container_port                = 8080
  healthcheck_path              = "/health"
  ecs_cluster_id                = aws_ecs_cluster.main.id
  ecs_desired_count             = 1
  ecs_fargate_cpu               = 256
  ecs_fargate_memory            = 512
  aws_region                    = local.region
  ecr_repo_url                  = aws_ecr_repository.mathservice_ecr.repository_url
  listener_arn                  = aws_lb_listener.this.arn
  listener_rule_host_values     = [local.mathservice_domain]
  loadbalancer_securitygroup_id = aws_security_group.lb.id
}

module "verifyservice_app" {
  source                        = "./ecsfgapp"
  vpc_id                        = module.vpc.vpc_id
  public_subnet_ids             = values(module.azs)[*].public_subnet_id
  private_subnet_ids            = values(module.azs)[*].private_subnet_id
  app_name                      = local.verifyservice_app_name
  external_port                 = 80
  container_port                = 8000
  healthcheck_path              = "/health"
  ecs_cluster_id                = aws_ecs_cluster.main.id
  ecs_desired_count             = 1
  ecs_fargate_cpu               = 256
  ecs_fargate_memory            = 512
  aws_region                    = local.region
  ecr_repo_url                  = aws_ecr_repository.verifyservice_ecr.repository_url
  listener_arn                  = aws_lb_listener.this.arn
  listener_rule_host_values     = [local.verifyservice_domain]
  loadbalancer_securitygroup_id = aws_security_group.lb.id
}

