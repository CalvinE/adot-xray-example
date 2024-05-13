terraform {
  required_version = "~> 1.8"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Create a VPC
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
}

# Create Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

