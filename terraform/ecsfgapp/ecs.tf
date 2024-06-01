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
    resources = [var.ssm_adot_custom_config_arn]
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

resource "aws_iam_role_policy_attachment" "task-allow-access-adot-config-ssm" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.allow-access-adot-config-ssm.arn
}


resource "aws_ecs_task_definition" "this" {
  family                   = "${var.app_name}-app-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_fargate_cpu
  memory                   = var.ecs_fargate_memory
  container_definitions = templatefile("${path.module}/templates/ecs_adot_custom_config_container_definition.json.tmpl", {
    "log_group_name"            = aws_cloudwatch_log_group.app_task.name
    "adot_log_group_name"       = aws_cloudwatch_log_group.app_aws_otel_task.name
    "app_adot_name"             = "${var.app_name}-aws-otel-collector"
    "app_name"                  = var.app_name
    "app_image"                 = "${var.ecr_repo_url}:latest"
    "aws_region"                = var.aws_region
    "app_port"                  = var.container_port
    "environment_variables"     = jsonencode(var.app_env_variables)
    "ssm_adot_config_param_arn" = var.ssm_adot_custom_config_arn
  })
}

resource "aws_ecs_service" "this" {
  name            = "${var.app_name}-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_task.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.this.id
    container_name   = var.app_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener_rule.this]
}
