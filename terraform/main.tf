terraform {
  required_version = "~> 1.8"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Source = "adot-xray-example"
    }
  }
}

locals {
  apps_domain = "apps.${var.top_hosted_domain}"
  external_ports = {
    port     = 443
    protocol = "HTTPS"
  }
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

resource "aws_alb" "this" {
  name            = "adot-demo-lb"
  subnets         = values(module.azs)[*].public_subnet_id
  security_groups = [aws_security_group.lb.id]
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_alb.this.arn
  port              = local.external_ports.port
  protocol          = local.external_ports.protocol
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.adot_apps.arn

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
  ingress {
    description      = "Allow ingress on ${local.external_ports.port} (${local.external_ports.protocol})"
    from_port        = local.external_ports.port
    to_port          = local.external_ports.port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
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

resource "aws_service_discovery_http_namespace" "this" {
  name        = "adot-poc.internal"
  description = "The service connect namespace for the adot POC"
}

# resource "aws_service_discovery_private_dns_namespace" "this" {
#   name        = "adot-poc.local"
#   description = "service discovery for adot POC apps"
#   vpc         = module.vpc.vpc_id
# }

# Route 53 Resources
data "aws_route53_zone" "tld" {
  name = var.top_hosted_domain
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
  source                              = "./ecsfgapp"
  vpc_id                              = module.vpc.vpc_id
  private_subnet_ids                  = values(module.azs)[*].private_subnet_id
  app_name                            = local.mathservice_app_name
  service_discovery_http_namespace_id = aws_service_discovery_http_namespace.this.id
  service_discovery_http_zone_name    = aws_service_discovery_http_namespace.this.name
  port_mappings = [{
    addToALB = true,
    details = {
      containerPort = 8080,
      name          = "http",
      appProtocol   = "http",
      protocol      = "tcp",
    }
  }]
  healthcheck_path              = "/health"
  ecs_cluster_id                = aws_ecs_cluster.main.id
  ecs_cluster_name              = aws_ecs_cluster.main.name
  ecs_min_count                 = 1
  ecs_max_count                 = 4
  ecs_desired_count             = 1
  ecs_fargate_cpu               = 256
  ecs_fargate_memory            = 512
  aws_region                    = var.region
  listener_arn                  = aws_lb_listener.this.arn
  listener_rule_host_values     = [local.mathservice_domain]
  loadbalancer_securitygroup_id = aws_security_group.lb.id
  app_env_variables             = [{ name = "VERIFY_SERVICE_URL", value = "https://${local.verifyservice_domain}" }]
  alb_domain_name               = aws_alb.this.dns_name
  alb_zone_id                   = aws_alb.this.zone_id
  route53_zone_id               = aws_route53_zone.apps.id
}

module "verifyservice_app" {
  source                              = "./ecsfgapp"
  vpc_id                              = module.vpc.vpc_id
  private_subnet_ids                  = values(module.azs)[*].private_subnet_id
  app_name                            = local.verifyservice_app_name
  service_discovery_http_namespace_id = aws_service_discovery_http_namespace.this.id
  service_discovery_http_zone_name    = aws_service_discovery_http_namespace.this.name
  port_mappings = [{
    addToALB = true,
    details = {
      containerPort = 8000,
      name          = "http",
      appProtocol   = "http",
      protocol      = "tcp",
    }
  }]
  healthcheck_path              = "/health"
  ecs_cluster_id                = aws_ecs_cluster.main.id
  ecs_cluster_name              = aws_ecs_cluster.main.name
  ecs_min_count                 = 1
  ecs_max_count                 = 4
  ecs_desired_count             = 1
  ecs_fargate_cpu               = 256
  ecs_fargate_memory            = 512
  aws_region                    = var.region
  listener_arn                  = aws_lb_listener.this.arn
  listener_rule_host_values     = [local.verifyservice_domain]
  loadbalancer_securitygroup_id = aws_security_group.lb.id
  alb_domain_name               = aws_alb.this.dns_name
  alb_zone_id                   = aws_alb.this.zone_id
  route53_zone_id               = aws_route53_zone.apps.id
  # ssm_adot_custom_config_arn    = aws_ssm_parameter.adot-config.arn
}

