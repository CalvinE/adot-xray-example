locals {
  mathservice_fg_cpu        = 256
  mathservice_fg_mem        = 512
  mathservice_desired_count = 1
}

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
  name               = "ecs-task-execution"
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

resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs-task"
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

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.app_name}-app-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_fargate_cpu
  memory                   = var.ecs_fargate_memory
  container_definitions = templatefile("./ecsfgapp/templates/ecs_adot_container_definition.json.tpl", {
    "log_group_name"      = aws_cloudwatch_log_group.app_task.name
    "adot_log_group_name" = aws_cloudwatch_log_group.app_aws_otel_task.name
    "app_adot_name"       = "${var.app_name}-aws-otel-collector"
    "app_name"            = var.app_name
    "app_image"           = "${var.ecr_repo_url}:latest"
    "aws_region"          = var.aws_region
    "app_port"            = var.container_port
    # "fargate_memory"      = local.mathservice_fg_mem
    # "fargate_cpu"         = local.mathservice_fg_cpu
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
    subnets          = var.private_subnet_ids //(module.azs)[*].private_subnet_id
    assign_public_ip = true                   // TODO: Can this be false?
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.this.id
    container_name   = var.app_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.this]
}
