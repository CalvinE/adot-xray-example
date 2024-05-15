FROM php:8.3-fpm

RUN apt update \
    && apt install -y zlib1g-dev g++ git libicu-dev zip libzip-dev zip gcc make autoconf \
    && docker-php-ext-install intl opcache pdo pdo_mysql \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    && docker-php-ext-configure zip \
    && docker-php-ext-install zip \
    && pecl install opentelemetry

RUN pecl install grpc \
    && docker-php-ext-enable grpc

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN echo -e "extension=grpc.so\n\n[opentelemetry]\nextension=opentelemetry.so\n\n" >> "$PHP_INI_DIR/php.ini"

COPY ./*.php .

COPY ./composer.* .

RUN composer install

EXPOSE 8000

ENTRYPOINT php -S 0.0.0.0:8000

