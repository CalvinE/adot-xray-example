resource "aws_security_group" "ecs_task" {
  name_prefix = "${var.app_name} allow lb to ecs"
  vpc_id      = var.vpc_id
  // TODO: make this dynamic incase there are multiple ports
  ingress {
    protocol        = "tcp"
    from_port       = var.container_port
    to_port         = var.container_port
    security_groups = [var.loadbalancer_securitygroup_id]
    # cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
