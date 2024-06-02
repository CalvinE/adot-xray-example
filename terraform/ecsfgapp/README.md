## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.8 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_alb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_target_group) | resource |
| [aws_cloudwatch_log_group.app_aws_otel_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.app_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_stream.app_aws_otel_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_stream) | resource |
| [aws_cloudwatch_log_stream.app_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_stream) | resource |
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.allow-access-adot-config-ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ecs-task-execution-role-policy-attachment-cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs-task-execution-role-policy-attachment-ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs-task-role-policy-attachment-cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs-task-role-policy-attachment-xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task-execution-allow-access-adot-config-ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb_listener_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_route53_record.mathservice](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_security_group.ecs_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_iam_policy_document.allow-access-adot-config-ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_domain_name"></a> [alb\_domain\_name](#input\_alb\_domain\_name) | The domain name of the ALB for this app | `string` | n/a | yes |
| <a name="input_alb_zone_id"></a> [alb\_zone\_id](#input\_alb\_zone\_id) | The zone id of the ALB fdor this app | `string` | n/a | yes |
| <a name="input_app_env_variables"></a> [app\_env\_variables](#input\_app\_env\_variables) | The environment varialbes to set for the container | `list(object({ name = string, value = string }))` | `[]` | no |
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | The name of the app being deployed | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The aws region the service will be deployed in | `string` | n/a | yes |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | The port on the ecs container | `number` | n/a | yes |
| <a name="input_ecs_cluster_id"></a> [ecs\_cluster\_id](#input\_ecs\_cluster\_id) | The id of the ECS cluster to add the service to. | `string` | n/a | yes |
| <a name="input_ecs_desired_count"></a> [ecs\_desired\_count](#input\_ecs\_desired\_count) | The desired number of instances of the app | `number` | n/a | yes |
| <a name="input_ecs_fargate_cpu"></a> [ecs\_fargate\_cpu](#input\_ecs\_fargate\_cpu) | The desired amount of CPU in vCPU for your fargate container isntances | `number` | n/a | yes |
| <a name="input_ecs_fargate_memory"></a> [ecs\_fargate\_memory](#input\_ecs\_fargate\_memory) | The desired amount of memory in MiB for your fargate container isntances | `number` | n/a | yes |
| <a name="input_healthcheck_path"></a> [healthcheck\_path](#input\_healthcheck\_path) | The endpoint for the healthcheck from the ALB | `string` | n/a | yes |
| <a name="input_listener_arn"></a> [listener\_arn](#input\_listener\_arn) | The arn of the listener on the ALB | `string` | n/a | yes |
| <a name="input_listener_rule_host_values"></a> [listener\_rule\_host\_values](#input\_listener\_rule\_host\_values) | A set of host names that will direct to this ecs service from the ALB | `set(string)` | n/a | yes |
| <a name="input_loadbalancer_securitygroup_id"></a> [loadbalancer\_securitygroup\_id](#input\_loadbalancer\_securitygroup\_id) | The security group id of the alb for the app | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | The ids of the private subnets where the ECS instances will run | `set(string)` | n/a | yes |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | The zone id of the domain that the sub domain for this app will be added to | `string` | n/a | yes |
| <a name="input_ssm_adot_custom_config_arn"></a> [ssm\_adot\_custom\_config\_arn](#input\_ssm\_adot\_custom\_config\_arn) | This is the arn to the SSM parameter that contains the whole text of your custom adot config | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The id of the VPC the app will be hosted in | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dns_names"></a> [dns\_names](#output\_dns\_names) | The dns name for the ALB |
| <a name="output_ecr_url"></a> [ecr\_url](#output\_ecr\_url) | The url of the ECR for this app |
