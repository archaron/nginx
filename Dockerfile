FROM alpine:latest

MAINTAINER Alexander Tischenko "tsm@fiberside.ru"

ENV NGINX_VERSION 1.23.3
ENV STICKY_VERSION 1.2.6



#    RUN apt -yq install geoipupdate libmaxminddb0 libmaxminddb-dev mmdb-bin
RUN GPG_KEYS=13C82A63B603576156E30A4EA0EA981B66B0D967 \
	&& CONFIG="\
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=/usr/lib/nginx/modules \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
		--user=nginx \
		--group=nginx \
		--with-http_ssl_module \
		--with-http_v2_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-threads \
		--with-stream \
		--with-stream_realip_module \
		--with-compat \
        --add-module=/usr/src/ngx_http_geoip2_module \
	" \
    #         --add-module=/usr/src/nginx-sticky-module \
	&& addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache --virtual .build-deps \
		gcc \
		libc-dev \
		make \
        pcre \
		pcre-dev \
		zlib-dev \
		curl \
		gnupg \
        libressl \
        libressl-dev \
        unzip \
#        geoipupdate \
#        libmaxminddb0  \
        libmaxminddb-dev  \
#        mmdb-bin \
    && curl -sfSL https://github.com/leev/ngx_http_geoip2_module/archive/refs/heads/master.zip -o ngx_http_geoip2_module.zip \
    && curl -sfSL https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng/get/$STICKY_VERSION.zip -o sticky.zip \
	&& curl -sfSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
	&& curl -sfSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver keyserver.ubuntu.com --recv-keys "$GPG_KEYS" \
	&& gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
	&& rm -rf "$GNUPGHOME" nginx.tar.gz.asc \
	&& mkdir -p /usr/src \
    && unzip -j sticky.zip -d /usr/src/nginx-sticky-module \
	# @TODO: check if sources change location "/usr/include/openssl"
    && sed -i '/#include <ngx_sha1.h>/a#include <openssl/md5.h>' /usr/src/nginx-sticky-module/ngx_http_sticky_misc.c \
    && sed -i '/#include <ngx_sha1.h>/a#include <openssl/sha.h>' /usr/src/nginx-sticky-module/ngx_http_sticky_misc.c \
    && cat /usr/src/nginx-sticky-module/ngx_http_sticky_misc.c | head -n 15 \
    && unzip -j ngx_http_geoip2_module.zip -d /usr/src/ngx_http_geoip2_module \
	&& tar -zxC /usr/src -f nginx.tar.gz \
	&& rm -rf nginx.tar.gz \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& ./configure $CONFIG --with-debug \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& mv objs/nginx objs/nginx-debug \
	&& ./configure $CONFIG \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
    && mkdir /etc/nginx/sites.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& (strip /usr/sbin/nginx* || exit 2) \
	&& (strip /usr/lib/nginx/modules/*.so || echo "no modules") \
    && (strip /usr/lib/nginx/addons/*.so  || echo "no addons") \
	&& rm -rf /usr/src/nginx-$NGINX_VERSION \
	&& apk add --no-cache --virtual .gettext gettext \
	&& mv /usr/bin/envsubst /tmp/ \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
    && echo "rundeps:\n $runDeps" \
	&& apk add --no-cache --virtual .nginx-rundeps $runDeps libressl \
	&& apk del .build-deps \
	&& apk del .gettext \
	&& mv /tmp/envsubst /usr/local/bin/ \
	&& (rm -rf /var/cache/apk 2> /dev/null || echo "OK") \
	&& (rm -rf /tmp/* 2> /dev/null || echo "OK") \
	&& (rm -rf /tmp/.* 2> /dev/null || echo "OK") \
	&& (rm -rf /root/* 2> /dev/null || echo "OK") \
	&& (rm -rf /root/.* 2> /dev/null || echo "OK") \
	&& mkdir -p /var/log/nginx \
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
    && nginx -V

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]