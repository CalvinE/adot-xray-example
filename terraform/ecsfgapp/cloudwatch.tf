# CloudWatch Reources
resource "aws_cloudwatch_log_group" "app_task" {
  name = "/ecs/${var.app_name}-app"
  // TODO: make configurable
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "app_task" {
  name           = "${var.app_name}-log-stream"
  log_group_name = aws_cloudwatch_log_group.app_task.name
}

resource "aws_cloudwatch_log_group" "app_aws_otel_task" {
  name = "/ecs/${var.app_name}-aws-otel-collector"
  // TODO: make configurable
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "app_aws_otel_task" {
  name           = "${var.app_name}-aws-otel-collector-log-stream"
  log_group_name = aws_cloudwatch_log_group.app_task.name
}

