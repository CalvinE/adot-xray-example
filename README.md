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
