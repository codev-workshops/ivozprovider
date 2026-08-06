FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && curl -fsSL http://packages.irontec.com/public.key http://packages.irontec.com/public-256.key \
        | gpg --dearmor -o /usr/share/keyrings/irontec.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/irontec.gpg] http://packages.irontec.com/debian tempest main extra" \
        > /etc/apt/sources.list.d/irontec.list \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ivozprovider-kamailio \
        ivozprovider-kamailio-json-modules \
        ivozprovider-kamailio-mysql-modules \
        ivozprovider-kamailio-tls-modules \
        ivozprovider-kamailio-xml-modules \
        ivozprovider-kamailio-websocket-modules \
        ivozprovider-kamailio-extra-modules \
        ivozprovider-kamailio-utils-modules \
        ivozprovider-kamailio-redis-modules \
        ivozprovider-kamailio-geoip2-modules \
        ivozprovider-kamailio-users \
        ivozprovider-kamailio-trunks \
        libdbd-mysql-perl \
        default-mysql-client \
        netcat-openbsd \
        ssl-cert \
        netbase \
    && rm -rf /var/lib/apt/lists/*

# autoconf and kamailio.cnf ship in ivozprovider-profile-proxy, which cannot be
# installed here: its dependency ivozprovider-profile-common makes
# /etc/resolv.conf immutable with chattr +i, which fails on overlayfs.
COPY profiles/proxy/etc/kamailio/autoconf /etc/kamailio/autoconf
COPY profiles/proxy/etc/mysql/conf.d/kamailio.cnf /usr/share/ivozprovider-legacy/kamailio.cnf
COPY docker/legacy/bin/wait-for-tcp /usr/local/bin/wait-for-tcp
COPY docker/legacy/kamailio/ports-users.cfg.dev docker/legacy/kamailio/ports-trunks.cfg.dev /usr/share/ivozprovider-legacy/
COPY docker/legacy/kamailio/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /etc/kamailio/autoconf /usr/local/bin/entrypoint.sh /usr/local/bin/wait-for-tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
