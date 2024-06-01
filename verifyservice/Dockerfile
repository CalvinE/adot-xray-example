FROM php:8.3-fpm

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN apt update \
    && apt install -y zlib1g-dev g++ git libicu-dev zip libzip-dev zip gcc make autoconf

RUN docker-php-ext-install intl opcache pdo pdo_mysql

RUN pecl install apcu \
    && docker-php-ext-enable apcu \
    && docker-php-ext-configure zip \
    && docker-php-ext-install zip

RUN pecl install opentelemetry \
    && docker-php-ext-enable opentelemetry

RUN pecl install grpc \
    && docker-php-ext-enable grpc

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# RUN echo -e "extension=grpc.so\n\n[opentelemetry]\nextension=opentelemetry.so\n\n" >> "$PHP_INI_DIR/php.ini"

COPY . .

RUN composer install

EXPOSE 8000

ENTRYPOINT php artisan serve --host 0.0.0.0 --port 8000
