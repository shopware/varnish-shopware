FROM varnish:7.7.3-alpine

# install build dependencies
USER root
RUN set -e; \
    apk upgrade --no-cache; \
    apk add --no-cache $VMOD_DEPS; \
    \
    # install one, possibly multiple vmods
    install-vmod https://github.com/varnish/varnish-modules/releases/download/0.24.0/varnish-modules-0.24.0.tar.gz; \
    \
    # clean up
    apk del --no-network $VMOD_DEPS
USER varnish
ENV SHOPWARE_BACKEND_HOST=localhost \
    SHOPWARE_BACKEND_PORT=8000 \
    SHOPWARE_ALLOWED_PURGER_IP='"127.0.0.1"'

COPY --chown=1000 rootfs /
