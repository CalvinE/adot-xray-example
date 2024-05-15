# locals {
#   mathservice_app_name      = "mathservice_app"
#   mathservice_fg_cpu        = 256
#   mathservice_fg_mem        = 512
#   mathservice_desired_count = 1
# }
#
# # ECS Resources
# resource "aws_ecs_cluster" "main" {
#   name = "adot-cluster"
# }
#
# data "aws_iam_policy_document" "ecs_assume_role" {
#   statement {
#     actions = ["sts:AssumeRole"]
#
#     principals {
#       type        = "Service"
#       identifiers = ["ecs-tasks.amazonaws.com"]
#     }
#   }
# }
#
# resource "aws_iam_role" "ecs_task_execution_role" {
#   name               = "ecs-task-execution"
#   assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
# }
#
# resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment-cloudwatch" {
#   role       = aws_iam_role.ecs_task_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
# }
#
# resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment-ecs" {
#   role       = aws_iam_role.ecs_task_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }
#
# resource "aws_iam_role" "ecs_task_role" {
#   name               = "ecs-task"
#   assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
# }
#
# resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attachment-cloudwatch" {
#   role       = aws_iam_role.ecs_task_role.name
#   policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
# }
#
# resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attachment-xray" {
#   role       = aws_iam_role.ecs_task_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
# }
#
# resource "aws_ecs_task_definition" "mathservice" {
#   family                   = "mathservice-app-task"
#   execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
#   task_role_arn            = aws_iam_role.ecs_task_role.arn
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   cpu                      = local.mathservice_fg_cpu
#   memory                   = local.mathservice_fg_mem
#   container_definitions = templatefile("./templates/ecs_adot_container_definition.json.tpl", {
#     "log_group_name"      = aws_cloudwatch_log_group.mathservice_task.name
#     "adot_log_group_name" = aws_cloudwatch_log_group.mathservice_aws_otel_task.name
#     "app_adot_name"       = "${local.mathservice_app_name}-aws-otel-collector"
#     "app_name"            = local.mathservice_app_name
#     "app_image"           = "${aws_ecr_repository.mathservice_ecr.repository_url}:latest"
#     "aws_region"          = local.region
#     "app_port"            = local.mathservice_container_port
#     # "fargate_memory"      = local.mathservice_fg_mem
#     # "fargate_cpu"         = local.mathservice_fg_cpu
#   })
# }
#
# resource "aws_ecs_service" "mathservice" {
#   name            = "mathservice-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.mathservice.arn
#   desired_count   = local.mathservice_desired_count
#   launch_type     = "FARGATE"
#
#   network_configuration {
#     security_groups  = [aws_security_group.ecs_task.id]
#     subnets          = values(module.azs)[*].private_subnet_id
#     assign_public_ip = true // TODO: Can this be false?
#   }
#
#   load_balancer {
#     target_group_arn = aws_alb_target_group.mathservice.id
#     container_name   = local.mathservice_app_name
#     container_port   = local.mathservice_container_port
#   }
#
#   depends_on = [aws_lb_listener.mathservice]
# }
