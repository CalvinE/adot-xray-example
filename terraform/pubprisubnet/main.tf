terraform {
  required_version = "~> 1.8"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


resource "aws_subnet" "public" {
  vpc_id            = var.vpc_id
  cidr_block        = var.public_cidr
  availability_zone = var.availability_zone
}

resource "aws_subnet" "private" {
  vpc_id            = var.vpc_id
  cidr_block        = var.private_cidr
  availability_zone = var.availability_zone
}

resource "aws_route_table" "public_route_table" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.internet_gateway_id
  }
}

resource "aws_route_table_association" "public_route_association" {
  for_each       = aws_subnet.public
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = var.vpc_id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
}

resource "aws_route_table_association" "private_route_association" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_eip" "private_nat_ip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "this" {
  subnet_id         = aws_subnet.public.id
  connectivity_type = "public"
  allocation_id     = aws_eip.private_nat_ip.allocation_id
}

