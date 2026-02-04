# Composer dependencies
FROM composer AS composer-build
WORKDIR /var/www/html
COPY ../composer.json ../composer.lock /var/www/html/
RUN mkdir -p /var/www/database/{factories,seeds} \
&& composer install --no-dev --prefer-dist --no-scripts --no-autoloader --no-progress --ignore-platform-reqs

#NPM dependencies
FROM node:22 AS npm-build
WORKDIR /var/www/html

COPY ../package.json ../package-lock.json ../vite.config.js /var/www/html/
COPY ../resources /var/www/html/resources/
COPY ../public /var/www/html/public/

RUN npm ci
RUN npm run build


# Actual production image

FROM php:8.5-fpm
WORKDIR /var/www/html
RUN apt-get update && apt-get install --quiet --yes --no-install-recommends \
libzip-dev \
unzip \
libpq-dev \
&& docker-php-ext-configure pcntl --enable-pcntl \
&& docker-php-ext-install zip pdo pdo_pgsql pcntl \
&& pecl install -o -f redis-6.3.0 \
&& docker-php-ext-enable redis

RUN mv $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY .docker/php/opcache.ini $PHP_INI_DIR/conf.d/

COPY --from=composer /usr/bin/composer /usr/bin/composer

COPY --chown=www-data --from=composer-build /var/www/html/vendor/ /var/www/html/vendor/
COPY --chown=www-data --from=npm-build /var/www/html/public/ /var/www/html/public/
COPY --chown=www-data . /var/www/html

RUN /usr/bin/composer dump -o \
&& /usr/bin/composer check-platform-reqs \
#&& rm -f /usr/bin/composer

ENTRYPOINT ["init-pod.sh"]
