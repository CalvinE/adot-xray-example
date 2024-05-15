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


