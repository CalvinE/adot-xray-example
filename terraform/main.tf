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
  vpc_cidr = "10.0.0.0/16"
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

resource "aws_security_group" "lb" {
  name   = "allow app traffic"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port        = local.mathservice_external_port
    to_port          = local.mathservice_external_port
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

resource "aws_security_group" "ecs_task" {
  name   = "allow lb to ecs"
  vpc_id = module.vpc.vpc_id
  ingress {
    protocol        = "tcp"
    from_port       = local.mathservice_container_port
    to_port         = local.mathservice_container_port
    security_groups = [aws_security_group.lb.id]
    # cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Create Elastic Container Registry
resource "aws_ecr_repository" "mathservice_ecr" {
  name         = "mathservice"
  force_delete = true
}

# CloudWatch Reources
resource "aws_cloudwatch_log_group" "mathservice_task" {
  name              = "/ecs/mathservice-app"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "mathservice_task" {
  name           = "mathservice-log-stream"
  log_group_name = aws_cloudwatch_log_group.mathservice_task.name
}

resource "aws_cloudwatch_log_group" "mathservice_aws_otel_task" {
  name              = "/ecs/mathservice-aws-otel-collector"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "mathservice_aws_otel_task" {
  name           = "mathservice-aws-otel-collector-log-stream"
  log_group_name = aws_cloudwatch_log_group.mathservice_task.name
}

