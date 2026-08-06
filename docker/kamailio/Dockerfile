FROM debian:bookworm

################################################################################
# Irontec package repository (same one used by the Debian install)
################################################################################
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install --assume-yes --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
    && apt-get clean

COPY debian/sources.list /etc/apt/sources.list.d/irontec.list
RUN curl -sS http://packages.irontec.com/public.key \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/irontec.gpg

################################################################################
# Kamailio + modules required by ivozprovider-profile-proxy (debian/control)
################################################################################
RUN apt-get update && \
    apt-get install --assume-yes \
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
    && apt-get clean

################################################################################
# Runtime dependencies of ivozprovider-profile-proxy
################################################################################
RUN apt-get update && \
    apt-get install --assume-yes --no-install-recommends \
        libdbd-mysql-perl \
        default-mysql-client \
        redis-tools \
        netcat-openbsd \
        ssl-cert \
        iproute2 \
        procps \
    && apt-get clean

################################################################################
# IvozProvider configuration (as ivozprovider-kamailio-{users,trunks}.install
# and ivozprovider-profile-proxy.install lay it out)
################################################################################
COPY kamailio/users/config/  /etc/kamailio/proxyusers/
COPY kamailio/trunks/config/ /etc/kamailio/proxytrunks/
COPY profiles/proxy/etc/kamailio/autoconf /etc/kamailio/autoconf
COPY profiles/proxy/usr/sbin/kamlog /usr/sbin/kamlog
COPY profiles/proxy/etc/mysql/conf.d/kamailio.cnf /etc/mysql/conf.d/kamailio.cnf
COPY debian/systemd/kamusers.default  /etc/default/kamusers
COPY debian/systemd/kamtrunks.default /etc/default/kamtrunks

# /etc/mysql/conf.d/kamailio.cnf already points at data.ivozprovider.local with
# the 'changeme' password used across the compose stack, mirroring what
# ivozprovider-profile-proxy.postinst setup_mysql_access() would write.
RUN chmod +x /etc/kamailio/autoconf /usr/sbin/kamlog

# Snakeoil certificates referenced by kamailio/*/config/tls.cfg
RUN make-ssl-cert generate-default-snakeoil --force-overwrite

COPY docker/kamailio/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["users"]
