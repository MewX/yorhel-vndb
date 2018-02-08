FROM ubuntu:rolling
MAINTAINER Yoran Heling <contact@vndb.org>

RUN apt-get update

RUN apt-get install -y locales && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

RUN apt-get install -y --no-install-recommends \
    build-essential \
    cpanminus \
    git \
    graphviz \
    imagemagick \
    libalgorithm-diff-xs-perl \
    libanyevent-irc-perl \
    libanyevent-perl \
    libcrypt-urandom-perl \
    libdbd-pg-perl \
    libfcgi-perl \
    libhttp-server-simple-perl \
    libimage-magick-perl \
    libjson-xs-perl \
    libperlio-gzip-perl \
    libpq-dev \
    libtext-multimarkdown-perl \
    libtie-ixhash-perl \
    libxml-parser-perl \
    postgresql

# These modules aren't packaged
RUN cpanm -vn \
    Crypt::ScryptKDF \
    AnyEvent::Pg

# Get TUWF from Git; I tend to experiment with VNDB before releasing new versions to CPAN.
RUN cd /root && git clone git://g.blicky.net/tuwf.git && cd tuwf && perl Build.PL && ./Build install

RUN touch /var/vndb-docker-image
CMD /var/www/util/docker-init.sh
