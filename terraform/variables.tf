variable "top_hosted_domain" {
  description = "The top level domain that the app domain will be added to as a sub domain. This example assume that this domain is already in AWS Route 53 and can be used to create a data resource for the domain zone."
  type        = string
}

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-2"
}

