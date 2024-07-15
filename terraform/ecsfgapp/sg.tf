resource "aws_security_group" "ecs_task" {
  name_prefix = "${var.app_name} allow lb to ecs"
  vpc_id      = var.vpc_id
  # dynamic "ingress" {
  #   for_each = { for m in var.port_mappings : m.details.name => m.details }
  #   content {
  #     protocol  = try(ingress.value.protocol, "-1")
  #     from_port = ingress.value.containerPort
  #     to_port   = ingress.value.containerPort
  #     self      = true
  #   }
  # }

  dynamic "ingress" {
    for_each = { for m in var.port_mappings : m.details.name => m.details if m.addToALB }
    content {
      protocol        = try(ingress.value.protocol, "-1")
      from_port       = ingress.value.containerPort
      to_port         = ingress.value.containerPort
      security_groups = [var.loadbalancer_securitygroup_id]
      # cidr_blocks      = ["0.0.0.0/0"]
      # ipv6_cidr_blocks = ["::/0"]
    }
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
