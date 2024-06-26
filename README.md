# AWS ADOT ECS Example

This is a example project for setting up a ECS Cluster with services running
with `AWS ADOT` sidecars.
The apps are configured with opentelemetry and the ADOT sidecar is configured to
send traces to `AWS X-Ray` and metrics to `AWS CloudWatch Metrics`.
All infrastructure is built with terraform, so setting up the demo should be
very easy!

Applications are instrumented with standard OpenTelemetry SDKs for Go and
PHP/Laravel.
The AWS ADOT sidecar handles collecting the telemetry and exporting it to our
desired backend (X-Ray for Traces and CloudWatch Metrics for Metrics).
Logs are collected by the standard ECS `awslogs` config which will end logs to
CloudWatch Logs.

> In the future I want to move logging over to OpenTelemetry also, but I have not gotten to that yet. As far as I am aware Logging is not stable across all SDKs, so your milage may vary.

This POC is intended to demo the following:

- Configuring an
  [AWS ADOT collector](https://aws-otel.github.io/docs/introduction) with a
  custom config
  - Using the
    [SSM Parameter approach for setting a custom config](https://aws-otel.github.io/docs/setup/ecs/config-through-ssm)
    for the ADOT collector
- Using OpenTelemetry to send Traces to AWS X-Ray
  - Using Resource Detectors to enrich traces with EC2 / ECS / EKS metadata
- Using OpenTelemetry to send Metrics to CloudWatch Metrics
- Using Log Correlation to view logs related to a trace in the X-Ray Dashboard
- Examples of instrumenting applictions with the OpenTelemetry SDK
  - Go
  - PHP/Laravel

## Overview

This project consists of the following:

- A `Mathservice` written in GO with the following endpoints:
  - A `/add` endpoint which takes two integers `op1` (operand 1) and `op2`
    (operand 2) as query parameters as part of a `GET` request and returns
    the sum of the two input variables as a plain/text response.
    - Ex:
      `/add?op1=1&op2=9`
    - This endpoint takes two numbers and returns the sum as `plain/text`.
      It also calls the `Verifyservice` `/api/verify` endpoint to ensure the
      result is accurate.
  - A `/health` endpoint that has a `GET` handler
- A `Verifyservice` written in PHP (Laravel) with the following endpoints:
  - A `/api/verify` endpoint which takes 3 integers `op1` (operand 1), `op2`
    (operand 2) and `es` (expected sum) as query parameters as part of a
    `GET` request and returns a JSON object with a property indicating if
    the `Mathservice` calculated the sum correctly.
    - Ex:
      `/api/verify?op1=1&op2=2&es=4`
    - This endpoint checks the math of the `Mathservice` to ensure it is
      correct... It will be, but I needed another simple service to show
      off distributed tracing...
    - This service has an intentional bug in which if the sum of the operands is
      8 it will throw an Exception, for demonstration purposes.

### Demo Screenshots

#### Trace Map

This gives a nice view of all activities in your traced services.
You can visualize flows and see error rates on specifc services at a glance!

![Trace Map](./screenshots/Trace_Map.png "Trace Map")

#### Trace List

Here we can see a list of traces listed over a given period of time

![Trace List](./screenshots/Trace_List.png "Trace List")

#### Examining an Error with Tracing and Log Correlation

##### Looking at the trace map

![Error Trace Details](./screenshots/01_Error_Trace_Details.png "Error Trace Details")

##### Looking at the trace segment timeline

![Error Trace Details](./screenshots/02_Error_Segment_Timeline.png "Error Trace Details")

##### Looking at trace segment resource details

![Error Trace Details](./screenshots/03_Error_Segment_Timeline_Detail.png "Error Trace Details")

##### Looking at trace segment metadata

![Error Trace Details](./screenshots/04_Error_Segment_Timeline_Detail_Metadata.png "Error Trace Details")

##### Looking at trace segment exception details

![Error Trace Details](./screenshots/05_Error_Segment_Timeline_Detail_Exception.png "Error Trace Details")

##### Looking at logs across services correlated with the trace ID for this request

A note worth reiterating here is that This pane contains all logs across all
services that contain the trace id of the trace being inspected.
This makes finding logs related to a specific request all in one place very
easy.
Its not the only way to accomplish this, but it is effective!

![Error Trace Details](./screenshots/06_Error_Trace_Correlated_Logs.png "Error Trace Details")

## Setup Instructions

All of these commands are run from the terraform folder

### Run Terraform Apply

```bash
cd ./terraform
terraform apply
```

### Login In To ECR Registry

This uses the `mathservice` url but cut is chopping off the `mathservice` part
so its just the private ECR address.

```bash
aws ecr get-login-password --region us-east-2 | docker login -u AWS --password-stdin "$(terraform output -raw mathservice_ecr_url | cut -f1 -d'/')"
```

### Build app docker images

```bash
docker build -f ../mathservice/Dockerfile -t mathservice ../mathservice
docker build -f ../verifyservice/Dockerfile -t verifyservice ../verifyservice
```

### Tag docker images

```bash
docker tag mathservice:latest "$(terraform output -raw mathservice_ecr_url)"
docker tag verifyservice:latest "$(terraform output -raw verifyservice_ecr_url)"
```

### Push Docker images to ECR

```bash
docker push "$(terraform output -raw mathservice_ecr_url)"
docker push "$(terraform output -raw verifyservice_ecr_url)"
```

Once this is complete just hit the appropriate ALB endpoint (you can find this
in the terraform output after deploying).
Use the examples above to play around.

> TODO: add a swagger doc for each service.
