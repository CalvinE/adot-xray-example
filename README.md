# AWS ADOT ECS Example

This is a example project for setting up a ECS Cluster with services running with `AWS ADOT` sidecars.
The apps are configured with opentelemetry and the ADOT sidecar is configured to send traces to `AWS X-Ray`
and metrics to `AWS CloudWatch Metrics`. All infrastructure is built with terraform, so setting up the demo should be very easy!

Applications are instrumented with standard OpenTelemetry SDKs for Go and PHP/Laravel. The AWS ADOT sidecar handles collecting the telemetry and exporting it to our desired backend (X-Ray for Traces and CloudWatch Metrics for Metrics). Logs are collected by the standard ECS `awslogs` config which will end logs to CloudWatch Logs.

```text
In the future I want to move logging over to OpenTelemetry also, but I have not gotten to that yet. As far as I am aware Logging is not stable across all SDKs, so your milage may vary.

```

This POC is intended to demo the following:

- Configuring an AWS ADOT collector with a custom config
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
  - A `/add` endpoint which takes two integers `op1` (operand 1) and `op2` (operand 2) as query parameters as part of a `GET` request and returns the sum of the two input variables as a plain/text response.
    - Ex: `/add?op1=1&op2=9`
    - This endpoint takes two numbers and returns the sum as `plain/text`. It also calls the `Verifyservice` `/api/verify` endpoint to ensure the result is accurate.
  - A `/health` endpoint that has a `GET` handler
- A `Verifyservice` written in PHP (Laravel) with the following endpoints:
  - A `/api/verify` endpoint which takes 3 integers `op1` (operand 1), `op2` (operand 2) and `es` (expected sum) as query parameters as part of a `GET` request and returns a JSON object with a property indicating if the `Mathservice` calculated the sum correctly.
    - Ex: `/api/verify?op1=1&op2=2&es=4`
    - This endpoint checks the math of the `Mathservice` to ensure it is correct... It will be, but I needed another simple service to show off distributed tracing...
    - This service has an intentional bug in which if the sum of the operands is 8 it will throw an Exception, for demonstration purposes.

## Setup Instructions

All of these commands are run from the terraform folder

### Run Terraform Apply

```bash
cd ./terraform
terraform apply
```

### Login In To ECR Registry

This uses the `mathservice` url but cut is chopping off the `mathservice`
part so its just the private ECR address.

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

## Docker Login

```bash
docker build -f Dockerfile -t mathservice .
```

```bash
aws ecr get-login-password --region us-east-2 | docker login -u AWS --password-stdin 290491194943.dkr.ecr.us-east-2.amazonaws.com
# or with terraform output
aws ecr get-login-password --region us-east-2 | docker login -u AWS --password-stdin "$(terraform output mathservice_ecr_url | cut -f1 -d'/' | cut -f2 -d'"')"
# or simpler with terraform output -raw
aws ecr get-login-password --region us-east-2 | docker login -u AWS --password-stdin "$(terraform output -raw mathservice_ecr_url | cut -f1 -d'/')"
```

## Get Base ECR URL

```bash
terraform output mathservice_ecr_url | cut -f1 -d'/' | cut -f2 -d'"'
# or with double quotes
terraform output mathservice_ecr_url | cut -f1 -d"/" | cut -f2 -d"\""
# or as an echo
echo "$(terraform output mathservice_ecr_url | cut -f1 -d'/' | cut -f2 -d'"')"
```

## Tag and Push Docker Image to ECR

```bash
docker tag mathservice:latest "$(terraform output -raw mathservice_ecr_url)"

docker push "$(terraform output -raw mathservice_ecr_url)"
```

```bash
# build verify service docker image
docker build -f ./Dockerfile.dev -t verifyservice-dev .
# run docker dev image for verify service
docker run -it -p 8000:8000 --mount type=bind,source=.,target=/app verifyservice-dev bash
```

```bash

```

```bash
# docker composer creaye symfony app
docker run -it --mount type=bind,source=.,target=/mnt/verifiyservice composer bash
```

```bash
#get bash prompt with volume mount in php:8.1-fpm container
docker run -it --mount type=bind,source=.,target=/mnt/verifiyservice php:8.1-fpm bash
# install composer in php:8.1-fpm container
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
# install git
apt update
apt install git-all
# create symfony app with composer
php /var/www/html/composer.phar create-project symfony/skeleton:"6.4.*" .
```

```bash
# install symfony cli
curl -sS https://get.symfony.com/cli/installer | bash
export PATH="$HOME/.symfony5/bin:$PATH"
symfony new ./app --version="6.4.*"

```

```bash
# add maker bundle so we can make a controller
composer require symfony/maker-bundle --dev
# symfony add controller
symfony console make:controller VerifyController
```

```bash
# install php dependencies for otel
apt update \
    && apt install -y zlib1g-dev g++ git libicu-dev zip libzip-dev zip \
    && docker-php-ext-install intl opcache pdo pdo_mysql \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    && docker-php-ext-configure zip \
    && docker-php-ext-install zip
symfony console make:controller ConferenceController
pecl install grpc 
    && docker-php-ext-enable grpc
```
