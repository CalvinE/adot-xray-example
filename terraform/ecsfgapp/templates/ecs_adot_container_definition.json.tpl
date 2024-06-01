[
  {
    "name": "${app_name}",
    "image": "${app_image}",
    "essential": true,
    "environment": ${environment_variables},
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${log_group_name}",
          "awslogs-region": "${aws_region}",
          "awslogs-stream-prefix": "ecs"
        }
    },
    "portMappings": [
      {
        "containerPort": ${app_port},
        "hostPort": ${app_port}
      }
    ]
  },
  {
    "name": "${app_adot_name}",
    "image": "public.ecr.aws/aws-observability/aws-otel-collector:v0.39.0",
    "essential": true,
    "command": [
        "--config=/etc/ecs/ecs-cloudwatch-xray.yaml"
    ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${adot_log_group_name}",
          "awslogs-region": "${aws_region}",
          "awslogs-stream-prefix": "ecs"
        }
    }
  }
]
