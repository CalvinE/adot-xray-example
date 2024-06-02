variable "vpc_id" {
  description = "The id of the VPC the app will be hosted in"
  type        = string
}

variable "private_subnet_ids" {
  description = "The ids of the private subnets where the ECS instances will run"
  type        = set(string)
}

variable "listener_rule_host_values" {
  description = "A set of host names that will direct to this ecs service from the ALB"
  type        = set(string)
}

variable "listener_arn" {
  description = "The arn of the listener on the ALB"
  type        = string
}

variable "loadbalancer_securitygroup_id" {
  description = "The security group id of the alb for the app"
  type        = string
}

variable "app_name" {
  description = "The name of the app being deployed"
  type        = string
}

variable "container_port" {
  description = "The port on the ecs container"
  type        = number
}

variable "healthcheck_path" {
  description = "The endpoint for the healthcheck from the ALB"
  type        = string
}

variable "ecs_cluster_id" {
  description = "The id of the ECS cluster to add the service to."
  type        = string
}

variable "ecs_desired_count" {
  description = "The desired number of instances of the app"
  type        = number
}

variable "ecs_fargate_cpu" {
  description = "The desired amount of CPU in vCPU for your fargate container isntances"
  type        = number
}

variable "ecs_fargate_memory" {
  description = "The desired amount of memory in MiB for your fargate container isntances"
  type        = number
}

variable "aws_region" {
  description = "The aws region the service will be deployed in"
  type        = string
}

variable "app_env_variables" {
  description = "The environment varialbes to set for the container"
  default     = []
  type        = list(object({ name = string, value = string })) //set(object({ name = string, value = string }))
}

variable "ssm_adot_custom_config_arn" {
  description = "This is the arn to the SSM parameter that contains the whole text of your custom adot config"
  type        = string
}

variable "route53_zone_id" {
  description = "The zone id of the domain that the sub domain for this app will be added to"
  type        = string
}

variable "alb_domain_name" {
  description = "The domain name of the ALB for this app"
  type        = string
}

variable "alb_zone_id" {
  description = "The zone id of the ALB fdor this app"
  type        = string
}


