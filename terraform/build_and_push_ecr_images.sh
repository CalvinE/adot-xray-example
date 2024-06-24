#! /bin/sh

### Login In To ECR Registry

aws ecr get-login-password --region us-east-2 | docker login -u AWS --password-stdin "$(terraform output -raw mathservice_ecr_url | cut -f1 -d'/')"

### Build app docker images

docker build -f ../mathservice/Dockerfile -t mathservice ../mathservice
docker build -f ../verifyservice/Dockerfile -t verifyservice ../verifyservice

### Tag docker images

docker tag mathservice:latest "$(terraform output -raw mathservice_ecr_url)"
docker tag verifyservice:latest "$(terraform output -raw verifyservice_ecr_url)"

### Push Docker images to ECR

docker push "$(terraform output -raw mathservice_ecr_url)"
docker push "$(terraform output -raw verifyservice_ecr_url)"
