# Dockerfile
FROM php:8.0-apache

RUN apt-get update && apt-get install -y \
    libzip-dev \
    libpng-dev \
    libonig-dev \
    curl \
    unzip \
    # cron \
    && docker-php-ext-install pdo_mysql mbstring zip gd

RUN a2enmod rewrite

EXPOSE 80

WORKDIR /var/www/html

RUN curl -LOk https://github.com/tastyigniter/setup/archive/master.zip && \
    unzip master.zip && \
    mv setup-master/* . && \
    rm -r setup-master master.zip
