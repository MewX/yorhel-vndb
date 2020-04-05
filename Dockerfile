FROM alpine:3.11
MAINTAINER Yoran Heling <contact@vndb.org>

ENV VNDB_DOCKER_VERSION=3
CMD /var/www/util/docker-init.sh

RUN apk add --no-cache \
        build-base \
        curl \
        git \
        graphviz \
        imagemagick \
        imagemagick-perlmagick \
        perl-anyevent \
        perl-app-cpanminus \
        perl-dbd-pg \
        perl-dev \
        perl-json-xs \
        perl-module-build \
        perl-xml-parser \
        postgresql \
        postgresql-dev \
        zlib-dev \
    && cpanm -nq \
        Algorithm::Diff::XS \
        AnyEvent::HTTP \
        AnyEvent::IRC \
        AnyEvent::Pg \
        Crypt::ScryptKDF \
        Crypt::URandom \
        HTTP::Server::Simple \
        PerlIO::gzip \
        SQL::Interp \
        Text::MultiMarkdown \
        git://g.blicky.net/tuwf.git \
    && curl -sL https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz | zcat >/usr/bin/elm \
    && chmod 755 /usr/bin/elm
