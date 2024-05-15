resource "aws_security_group" "lb" {
  name_prefix = "${var.app_name} allow app traffic"
  vpc_id      = var.vpc_id
  // TODO: make this dynamic incase there are multiple ports
  ingress {
    from_port        = var.external_port
    to_port          = var.external_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "ecs_task" {
  name_prefix = "${var.app_name} allow lb to ecs"
  vpc_id      = var.vpc_id
  // TODO: make this dynamic incase there are multiple ports
  ingress {
    protocol        = "tcp"
    from_port       = var.container_port
    to_port         = var.container_port
    security_groups = [aws_security_group.lb.id]
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
