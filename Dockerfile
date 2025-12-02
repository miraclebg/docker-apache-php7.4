ARG PHP_BUILD_MAJOR=7
ARG PHP_VERSION=$PHP_BUILD_MAJOR.4-apache
ARG APP_ID=1000
ARG LIBPERL_VERSION=5.32
ARG LIBSODIUM_VERSION=23

# for PHP >=7<8
ARG XDEBUG_VERSION=3.1.5

FROM php:${PHP_VERSION} AS base

LABEL maintainer="Martin Kovachev <miracle@nimasystems.com>"

RUN apt-get update \
  && apt-get upgrade -y \
  && pecl channel-update pecl.php.net

RUN apt-get update -y \
  && apt-get upgrade -y \
  && pecl channel-update pecl.php.net \
  && apt-get install -y acl locales \
  && echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen \
  && echo 'es_ES.UTF-8 UTF-8' >> /etc/locale.gen \
  && echo 'bg_BG.UTF-8 UTF-8' >> /etc/locale.gen \
  && echo 'de_DE.UTF-8 UTF-8' >> /etc/locale.gen \
  && echo 'fr_FR.UTF-8 UTF-8' >> /etc/locale.gen \
  && echo 'it_IT.UTF-8 UTF-8' >> /etc/locale.gen \
  && echo 'ru_RU.UTF-8 UTF-8' >> /etc/locale.gen \
  && /usr/sbin/locale-gen

FROM base AS build-base

ARG LIBPERL_VERSION

LABEL maintainer="Martin Kovachev <miracle@nimasystems.com>"

# configure and install deps
RUN apt-get install -y --no-install-recommends \
    gcc \
    make \
    autoconf \
    pkg-config \
    libc-dev \
    libbz2-dev \
    libfreetype6-dev \
    libicu-dev \
    libjpeg-dev \
    libjpeg62-turbo-dev \
    libmagickwand-dev \
    libmcrypt-dev \
    libonig-dev \
    libpng-dev \
    libsodium-dev \
    libcurl4 \
    libcurl4-openssl-dev \
    libssh2-1-dev \
    libwebp-dev \
    libxml2-dev \
    libxslt1-dev \
    libzip-dev \
    libmemcached-dev \
    libpcre3-dev \
    libssl-dev \
    libyaml-dev \
    libc-client-dev \
    libkrb5-dev \
    zlib1g-dev \
    libgd-dev \
    zip \
    unzip \
    libfcgi-bin \
    libperl$LIBPERL_VERSION \
    libperl-dev

WORKDIR /build

FROM build-base AS build-php7

LABEL maintainer="Martin Kovachev <miracle@nimasystems.com>"

WORKDIR /var/www/html

RUN pecl install \
    imagick \
    redis \
    yaml \
    apcu \
    libsodium

RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
  && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
  && docker-php-ext-install \
    bcmath \
    bz2 \
    calendar \
    exif \
    gd \
    imap \
    gettext \
    intl \
    mbstring \
    mysqli \
    opcache \
    pcntl \
    pdo_mysql \
    soap \
    sockets \
    sodium \
    sysvmsg \
    sysvsem \
    sysvshm \
    shmop \
    xsl \
    zip \
  && docker-php-ext-enable \
    imagick \
    redis \
    yaml \
    apcu

FROM build-php${PHP_BUILD_MAJOR} AS build-php

FROM base AS runtime

LABEL maintainer="Martin Kovachev <miracle@nimasystems.com>"

ARG APP_ID
ARG PHP_BUILD_MAJOR
ARG LIBSODIUM_VERSION

RUN apt-get update && apt-get install -y \
    libfreetype6 \
    imagemagick \
    libxslt1.1 \
    libzip4 \
    libgd3 \
    libc-client2007e \
    libyaml-0-2 \
    libsodium${LIBSODIUM_VERSION} \
    libmemcached11 \
    libmemcached-tools \
    optipng \
    gifsicle \
    gettext \
    webp \
    jpegoptim \
    zip \
    unzip \
    git \
    ca-certificates \
    # TODO: remove when testing done
    ncdu vim mc lynx \
    && curl -sS https://getcomposer.org/installer | \
        php -- --install-dir=/usr/local/bin --filename=composer

COPY --from=build-php /usr/local/etc /usr/local/etc
COPY --from=build-php /usr/local/include /usr/local/include
COPY --from=build-php /usr/local/lib /usr/local/lib

WORKDIR /var/www/html

RUN groupadd -g "$APP_ID" app \
    && useradd -g "$APP_ID" -u "$APP_ID" -d /var/www -s /bin/bash app \
    && mkdir -p /var/www/html \
    && rm -rf /usr/local/var && cd /usr/local && ln -s /var \
    && chown -R app:app /var/www

USER app:app
EXPOSE 80

FROM runtime AS runtime-prod

USER root

RUN apt remove -y --allow-remove-essential autoconf make m4 cpp e2fsprogs binutils cpp-6 \
    libatomic1 libcc1-0 libitm1 libmpc3 libsigsegv2 \
    dbus fonts-droid-fallback fonts-noto-mono libapparmor1 libavahi-client3 libavahi-common-data \
    libavahi-common3 libcups2 libcupsfilters1 libcupsimage2 libdbus-1-3 libgs9-common \
    libijs-0.35 libjbig2dec0 libpaper-utils libpaper1 \
    poppler-data libgl1-mesa-dri \
    gcc g++ cpp python \
    git-man less libcurl3-gnutls libpopt0 libxmuu1 patch xauth \
    libpython2.7-minimal libpython2.7-stdlib \
    libsqlite3-0 python2.7 python2.7-minimal readline-common \
    bzip2 openssh-client perl libdpkg-perl liberror-perl perl pkg-config \
    re2c rsync || true \
    && apt autoremove -y \
    && rm -rf /tmp/pear /var/cache/apt /var/lib/apt/lists/* /root/.composer \
      /usr/lib/aarch64-linux-gnu/libLLVM-7.so.1 /usr/lib/aarch64-linux-gnu/perl /usr/share/perl \
      /usr/local/bin/docker-php-ext-enable /usr/local/bin/docker-php-ext-install \
      /usr/local/bin/docker-php-source /usr/share/doc /usr/share/icons /usr/share/vim \
      /usr/share/zoneinfo /usr/src/* /usr/include /usr/local/include /usr/local/php/man \
      /usr/local/php/php

USER app:app

WORKDIR /var/www/html
