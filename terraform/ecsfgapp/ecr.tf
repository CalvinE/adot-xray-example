resource "aws_ecr_repository" "this" {
  name         = var.app_name
  force_delete = true
}

