resource "aws_ssm_parameter" "service-adot-config" {
  name = "adot-collector-config-${var.app_name}"
  tier = "Standard"
  value = templatefile("${path.module}/adot-config/custom-parameterized.yaml", {
    app_name = var.app_name
  })
  type = "String"
}

