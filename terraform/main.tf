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
  region = "us-east-2"
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
  vpc_cidr               = "10.0.0.0/16"
  mathservice_app_name   = "mathservice"
  verifyservice_app_name = "verifyservice"
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

# ECS Resources
resource "aws_ecs_cluster" "main" {
  name = "adot-cluster"
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
  source             = "./ecsfgapp"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = values(module.azs)[*].public_subnet_id
  private_subnet_ids = values(module.azs)[*].private_subnet_id
  app_name           = local.mathservice_app_name
  external_port      = 80
  container_port     = 8080
  healthcheck_path   = "/health"
  ecs_cluster_id     = aws_ecs_cluster.main.id
  ecs_desired_count  = 1
  ecs_fargate_cpu    = 256
  ecs_fargate_memory = 512
  aws_region         = local.region
  ecr_repo_url       = aws_ecr_repository.mathservice_ecr.repository_url
}

module "verifyservice_app" {
  source             = "./ecsfgapp"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = values(module.azs)[*].public_subnet_id
  private_subnet_ids = values(module.azs)[*].private_subnet_id
  app_name           = local.verifyservice_app_name
  external_port      = 80
  container_port     = 8000
  healthcheck_path   = "/health"
  ecs_cluster_id     = aws_ecs_cluster.main.id
  ecs_desired_count  = 1
  ecs_fargate_cpu    = 256
  ecs_fargate_memory = 512
  aws_region         = local.region
  ecr_repo_url       = aws_ecr_repository.verifyservice_ecr.repository_url
}

# resource "aws_security_group" "lb" {
#   name   = "allow app traffic"
#   vpc_id = module.vpc.vpc_id
#   ingress {
#     from_port        = local.mathservice_external_port
#     to_port          = local.mathservice_external_port
#     protocol         = "tcp"
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = ["::/0"]
#   }
#
#   egress {
#     from_port        = 0
#     to_port          = 0
#     protocol         = "-1"
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = ["::/0"]
#   }
# }
#
# resource "aws_security_group" "ecs_task" {
#   name   = "allow lb to ecs"
#   vpc_id = module.vpc.vpc_id
#   ingress {
#     protocol        = "tcp"
#     from_port       = local.mathservice_container_port
#     to_port         = local.mathservice_container_port
#     security_groups = [aws_security_group.lb.id]
#     # cidr_blocks      = ["0.0.0.0/0"]
#     # ipv6_cidr_blocks = ["::/0"]
#   }
#
#   egress {
#     protocol         = "-1"
#     from_port        = 0
#     to_port          = 0
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = ["::/0"]
#   }
# }

# CloudWatch Reources
# resource "aws_cloudwatch_log_group" "mathservice_task" {
#   name              = "/ecs/mathservice-app"
#   retention_in_days = 30
# }

# resource "aws_cloudwatch_log_stream" "mathservice_task" {
#   name           = "mathservice-log-stream"
#   log_group_name = aws_cloudwatch_log_group.mathservice_task.name
# }
#
# resource "aws_cloudwatch_log_group" "mathservice_aws_otel_task" {
#   name              = "/ecs/mathservice-aws-otel-collector"
#   retention_in_days = 30
# }
#
# resource "aws_cloudwatch_log_stream" "mathservice_aws_otel_task" {
#   name           = "mathservice-aws-otel-collector-log-stream"
#   log_group_name = aws_cloudwatch_log_group.mathservice_task.name
# }

