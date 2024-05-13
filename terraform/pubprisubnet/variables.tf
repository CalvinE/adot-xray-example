variable "vpc_id" {
  description = "The id of the vpc"
  type        = string
  nullable    = false
}

variable "public_cidr" {
  description = "The public cidr block for this AZ"
  type        = string
  nullable    = false
}

variable "private_cidr" {
  description = "The private cidr block for this AZ"
  type        = string
  nullable    = false
}

variable "availability_zone" {
  description = "The availability zone for the subnets to be deployed in"
  type        = string
  nullable    = false
}

variable "internet_gateway_id" {
  description = "The id of the internet gateway for the vpc."
  type        = string
}

