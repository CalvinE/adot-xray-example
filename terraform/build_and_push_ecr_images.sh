#! /bin/bash

SERVICES=("mathservice" "verifyservice")

# TARGET_SERVICES="TARGET_SERVICES"

SCRIPT_PREFIX="***"

if [[ ${TARGET_SERVICES:-""} == "" ]]; then
  echo "${SCRIPT_PREFIX} TARGET_SERVICES not set. defaulting to all services"
  TARGET_SERVICES="${SERVICES[@]}"
fi

### Login In To ECR Registry

aws ecr get-login-password --region us-east-2 | docker login -u AWS --password-stdin "$(terraform output -raw mathservice_ecr_url | cut -f1 -d'/')"

echo "${SCRIPT_PREFIX} target_services: \"${TARGET_SERVICES}\""

for service in ${TARGET_SERVICES}; do
  echo "${SCRIPT_PREFIX} found $service"
  ### Build app docker images
  echo "${SCRIPT_PREFIX} building ${service} docker image"
  docker build -f ../${service}/Dockerfile -t ${service} ../${service}
  if [ "$?" != 0 ]; then
    echo "${SCRIPT_PREFIX} failed to build ${service} docker image"
    exit 1
  fi
  ### Tag docker images
  ecr_url_output_name="${service}_ecr_url"
  ecr_url=$(terraform output -raw $ecr_url_output_name)
  tag="latest"
  image_tag="${ecr_url}:${tag}"
  echo "${SCRIPT_PREFIX} tagging ${service} with ${image_tag}"
  docker tag "${image_tag}" "${ecr_url}"
  if [ "$?" != 0 ]; then
    echo "${SCRIPT_PREFIX} failed to tag ${service} docker image"
    exit 1
  fi
  ### Push Docker images to ECR
  echo "${SCRIPT_PREFIX} pushing ${service} image tagged with ${image_tag} to ${ecr_url}"
  docker push "${image_tag}"
  if [ "$?" != 0 ]; then
    echo "${SCRIPT_PREFIX} failed to push ${service} docker image to ECR"
    exit 1
  fi
  echo "${SCRIPT_PREFIX} service deployed: ${service}"
done

exit 0

# ### Build app docker images
#
# docker build -f ../mathservice/Dockerfile -t mathservice ../mathservice
# docker build -f ../verifyservice/Dockerfile -t verifyservice ../verifyservice
#
# ### Tag docker images
#
# docker tag mathservice:latest "$(terraform output -raw mathservice_ecr_url)"
# docker tag verifyservice:latest "$(terraform output -raw verifyservice_ecr_url)"
#
# ### Push Docker images to ECR
#
# docker push "$(terraform output -raw mathservice_ecr_url)"
# docker push "$(terraform output -raw verifyservice_ecr_url)"
