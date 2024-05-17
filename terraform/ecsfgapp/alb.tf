// TODO: remove ALB from this module. What if I want more than one app per ALB? ALB should be a separate module with app info for the creation of target groups.
resource "aws_alb" "this" {
  name            = "${var.app_name}-lb"
  subnets         = var.public_subnet_ids
  security_groups = [aws_security_group.lb.id]
}

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

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_alb.this.arn
  port              = var.external_port
  // TODO: make configurable
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.this.id
    type             = "forward"
  }
}

