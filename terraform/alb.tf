# locals {
#   mathservice_external_port    = 80
#   mathservice_container_port   = 8080
#   mathservice_healthcheck_path = "/health"
# }
#
# resource "aws_alb" "mathservice" {
#   name            = "mathservice-lb"
#   subnets         = values(module.azs)[*].public_subnet_id
#   security_groups = [aws_security_group.lb.id]
# }
#
# resource "aws_alb_target_group" "mathservice" {
#   name        = "mathservice-tg"
#   port        = local.mathservice_container_port
#   protocol    = "HTTP"
#   target_type = "ip"
#   vpc_id      = module.vpc.vpc_id
#
#   deregistration_delay = 30
#
#   health_check {
#     healthy_threshold   = "3"
#     interval            = "30"
#     protocol            = "HTTP"
#     matcher             = "200"
#     timeout             = "3"
#     path                = local.mathservice_healthcheck_path
#     unhealthy_threshold = "2"
#   }
# }
#
# resource "aws_lb_listener" "mathservice" {
#   load_balancer_arn = aws_alb.mathservice.arn
#   port              = local.mathservice_external_port
#   protocol          = "HTTP"
#
#   default_action {
#     target_group_arn = aws_alb_target_group.mathservice.id
#     type             = "forward"
#   }
# }
#
