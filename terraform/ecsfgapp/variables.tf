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

variable "port_mappings" {
  description = "The port mappings for the app container. See: https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_PortMapping.html#API_PortMapping_Contents"
  type = list(object({
    addToALB = bool,
    details = object({
      name          = string,
      protocol      = string,
      appProtocol   = string,
      containerPort = number,
      # hostPort      = number,
    })
  }))
  validation {
    condition = alltrue([
      for o in var.port_mappings : length(o.details.name) > 0
    ])
    error_message = "name must have a value"
  }
  validation {
    condition = alltrue([
      for o in var.port_mappings : contains(["tcp", "udp", null], o.details.protocol)
    ])
    error_message = "protocol must be 'tcp', 'udp' or null"
  }
  validation {
    condition = alltrue([
      for o in var.port_mappings : contains(["http", "http2", "grpc", null], o.details.appProtocol)
    ])
    error_message = "appProtocol must be 'http', 'http2', 'grpc', or null"
  }
}

variable "service_discovery_http_namespace_id" {
  description = "The ID of the service discovery HTTP namespace"
  type        = string
}

variable "service_discovery_http_zone_name" {
  description = "The name of the service discovery namespace"
  type        = string
}

variable "container_network_mode" {
  description = "The network mode for the container"
  type        = string
  default     = "awsvpc"
}

variable "healthcheck_path" {
  description = "The endpoint for the healthcheck from the ALB"
  type        = string
}

variable "ecs_cluster_id" {
  description = "The id of the ECS cluster to add the service to."
  type        = string
}

variable "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
}

variable "ecs_min_count" {
  description = "The min number of instances of the app"
  type        = number
}

variable "ecs_max_count" {
  description = "The max number of instances of the app"
  type        = number
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
  type        = list(object({ name = string, value = string }))
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


