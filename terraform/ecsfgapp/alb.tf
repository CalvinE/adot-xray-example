resource "aws_alb_target_group" "this" {
  name = "${var.app_name}-tg"
  port = var.container_port
  // TODO: make configurable?
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = 30

  health_check {
    healthy_threshold = "3"
    interval          = "30"
    // TODO: make variables for non HTTP Healthchecks
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.healthcheck_path
    unhealthy_threshold = "2"
  }
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = var.listener_arn
  condition {
    host_header {
      values = var.listener_rule_host_values
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.this.arn
  }
}

