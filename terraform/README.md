## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.8 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.49.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_azs"></a> [azs](#module\_azs) | ./pubprisubnet | n/a |
| <a name="module_mathservice_app"></a> [mathservice\_app](#module\_mathservice\_app) | ./ecsfgapp | n/a |
| <a name="module_verifyservice_app"></a> [verifyservice\_app](#module\_verifyservice\_app) | ./ecsfgapp | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ./vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.adot_apps](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.adot_apps](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_alb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb) | resource |
| [aws_ecs_cluster.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_lb_listener.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_route53_record.acm_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.apps_ns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.apps](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_security_group.lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.adot-config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_route53_zone.tld](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_region"></a> [region](#input\_region) | The AWS region to deploy to | `string` | `"us-east-2"` | no |
| <a name="input_top_hosted_domain"></a> [top\_hosted\_domain](#input\_top\_hosted\_domain) | The top level domain that the app domain will be added to as a sub domain. This example assume that this domain is already in AWS Route 53 and can be used to create a data resource for the domain zone. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_mathservice_alb_dns_name"></a> [mathservice\_alb\_dns\_name](#output\_mathservice\_alb\_dns\_name) | n/a |
| <a name="output_mathservice_ecr_url"></a> [mathservice\_ecr\_url](#output\_mathservice\_ecr\_url) | n/a |
| <a name="output_verifyservice_alb_dns_name"></a> [verifyservice\_alb\_dns\_name](#output\_verifyservice\_alb\_dns\_name) | n/a |
| <a name="output_verifyservice_ecr_url"></a> [verifyservice\_ecr\_url](#output\_verifyservice\_ecr\_url) | n/a |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | n/a |
