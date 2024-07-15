# ECS Resources
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name_prefix        = "ecs-task-execution-${var.app_name}-"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment-cloudwatch" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment-ecs" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "allow-access-adot-config-ssm" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters"
    ]
    resources = [aws_ssm_parameter.service-adot-config.arn]
  }
}

resource "aws_iam_policy" "allow-access-adot-config-ssm" {
  name_prefix = "allow-access_adot-config-ssm"
  description = "Allows access to ssm paramter that holds the adot collector config"
  policy      = data.aws_iam_policy_document.allow-access-adot-config-ssm.json
}

resource "aws_iam_role_policy_attachment" "task-execution-allow-access-adot-config-ssm" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.allow-access-adot-config-ssm.arn
}

resource "aws_iam_role" "ecs_task_role" {
  name_prefix        = "ecs-task-${var.app_name}-"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attachment-cloudwatch" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attachment-xray" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

locals {
  // PSD = Private Service Discovery
  service_env_vars = concat(var.app_env_variables, [{ name = "PSD_DOMAIN", value = var.service_discovery_http_zone_name }])
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.app_name}-app-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  network_mode             = var.container_network_mode
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_fargate_cpu
  memory                   = var.ecs_fargate_memory
  container_definitions = templatefile("${path.module}/templates/ecs_adot_custom_config_container_definition.json.tmpl", {
    "log_group_name"            = aws_cloudwatch_log_group.app_task.name
    "adot_log_group_name"       = aws_cloudwatch_log_group.app_aws_otel_task.name
    "app_adot_name"             = "${var.app_name}-aws-otel-collector"
    "app_name"                  = var.app_name
    "app_image"                 = "${aws_ecr_repository.this.repository_url}:latest"
    "aws_region"                = var.aws_region
    "environment_variables"     = jsonencode(local.service_env_vars)
    "port_mappings"             = jsonencode([for m in var.port_mappings : m.details])
    "ssm_adot_config_param_arn" = aws_ssm_parameter.service-adot-config.arn
  })
}

// TODO: why are there multiple 
resource "aws_service_discovery_service" "https" {
  for_each     = { for m in var.port_mappings : m.details.name => m.details }
  name         = "${each.key}.${var.app_name}"
  namespace_id = var.service_discovery_http_namespace_id


  health_check_config {
    resource_path = var.healthcheck_path
    type          = "HTTP"
  }
}

locals {
  service_name = "${var.app_name}-service"
}

resource "aws_ecs_service" "this" {
  name            = local.service_name
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"
  // Aparently you can only haveone of these blocks... 
  // That means that if you need to support multiple services 
  // from a single ECS service you are out of luck? 
  // You could just use standard ports across all containers? 
  // If you are using bridge mode networking that would not work... 
  // You would neeed to coordinate unique port numbers across all of your services.
  // With that approace you would need to know all services ports that a given service 
  // needs to communicate with?
  # service_registries {
  #   registry_arn   = aws_service_discovery_service.https.arn
  #   container_name = var.app_name
  #   container_port = var.container_port
  # }
  service_connect_configuration {
    enabled   = true
    namespace = var.service_discovery_http_zone_name
    # log_configuration {
    #   log_driver = "awslogs"
    #   options = {
    #     "awslogs-region" : "us-east-2"
    #     "awslogs-group" = "/aws/ecs/serviceconnect/${var.app_name}"
    #   }
    # }
    dynamic "service" {
      for_each = var.port_mappings
      content {
        # count = length(var.port_mappings)
        port_name      = service.value.details.name
        discovery_name = "${service.value.details.name}-${var.app_name}"
        client_alias {
          dns_name = try(service.value.serviceConnect.dns_name, null)
          port     = try(service.value.serviceConnect.port, service.value.details.containerPort)
        }
      }
    }
  }

  network_configuration {
    security_groups = [
      aws_security_group.ecs_task.id,
      // This one allows all ecs service to communicate with each other. This is a POC. In a real deployment we might want to only allow specific communications between services?
      var.ecs_cluster_service_securitygroup_id
    ]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = { for m in var.port_mappings : m.details.name => m.details if m.addToALB }
    content {
      target_group_arn = aws_alb_target_group.this[load_balancer.key].id
      container_name   = var.app_name
      container_port   = load_balancer.value.containerPort
    }
  }

  // I saw guidance that this is a good idea so if you do a deploy while an autoscaling change is in effect y you will not undo it.
  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_lb_listener_rule.this]
}

resource "aws_appautoscaling_target" "this" {
  max_capacity       = var.ecs_max_count
  min_capacity       = var.ecs_min_count
  resource_id        = "service/${var.ecs_cluster_name}/${local.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.this]
}

resource "aws_appautoscaling_policy" "cpu_scaling" {
  name               = "cpu_scaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  resource_id        = aws_appautoscaling_target.this.resource_id
  policy_type        = "TargetTrackingScaling"
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      // https://docs.aws.amazon.com/autoscaling/application/APIReference/API_PredefinedMetricSpecification.html
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    // TODO: make configurable
    target_value       = 75
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

resource "aws_appautoscaling_policy" "memory_scaling" {
  name               = "memory_scaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  resource_id        = aws_appautoscaling_target.this.resource_id
  policy_type        = "TargetTrackingScaling"
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    // TODO: make configurable
    target_value       = 75
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

