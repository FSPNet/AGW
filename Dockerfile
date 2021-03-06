# Shadowsocks Server with KCPTUN support Dockerfile

FROM alpine:latest

ARG KCP_VER=20190109
ARG KCP_URL=https://github.com/xtaci/kcptun/releases/download/v{$KCP_VER}/kcptun-linux-amd64-${KCP_VER}.tar.gz
ARG SS_VER=3.2.3
ARG SS_DOWNLOAD=https://github.com/shadowsocks/shadowsocks-libev/releases/download/v${SS_VER}/shadowsocks-libev-${SS_VER}.tar.gz
ARG OBFS_DOWNLOAD=https://github.com/shadowsocks/simple-obfs.git

RUN set -ex && apk upgrade \
    && apk add bash tzdata rng-tools supervisor \
    && apk add --no-cache --virtual .build-deps \
        gcc \ 
        make \
        openssl \
        libpcre32 \
        g++ \
        curl \
        autoconf \
        build-base \
        libtool \
        linux-headers \
        libressl-dev \
        zlib-dev \
        asciidoc \
        udns-dev \
        xmlto \
        pcre-dev \
        automake \
        mbedtls-dev \
        libsodium-dev \
        c-ares-dev \
        libev-dev \
        tar \
        git \
    && curl -fsSL ${SS_DOWNLOAD} | tar xz \
    && (cd shadowsocks-libev-${SS_VER} \
    && ./configure --prefix=/usr --disable-documentation \
    && make install) \
    && git clone ${OBFS_DOWNLOAD} \
    && (cd simple-obfs \
    && git submodule update --init --recursive \
    && ./autogen.sh && ./configure --prefix=/usr --disable-documentation\
    && make && make install) \
    && cd .. \
    && runDeps="$( \
        scanelf --needed --nobanner /usr/bin/ss-* /usr/local/bin/obfs-* \
        | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
        | xargs -r apk info --installed \
        | sort -u \
        )" \
    && apk add --virtual .run-deps $runDeps \
    && curl -fSL ${KCP_URL} | tar xz -C /usr/local/bin \
    && apk del .build-deps \
    && rm -rf shadowsocks-libev-${SS_VER}.tar.gz \
        shadowsocks-libev-${SS_VER} \
        simple-obfs \
        /var/cache/apk/*

COPY supervisord.conf /etc/supervisord.conf
COPY config.json /etc/kcptun.json

ENV KCP_PORT=443 PASSWORD=123456 KCP_REMOTE_PORT=1024 SS_PORT=8388 SS_METHOD=chacha20-ietf-poly1305 SS_TIMEOUT=60 DNS_ADDR=8.8.8.8,8.8.4.4 PLUGIN=obfs-server 
ENV PLUGIN_OPTS obfs=tls;fast-open;failover=0.0.0.0:8443

EXPOSE ${KCP_PORT}/tcp ${KCP_PORT}/udp

ENTRYPOINT ["/usr/bin/supervisord"]