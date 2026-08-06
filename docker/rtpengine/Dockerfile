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
# Media relay. /etc/rtpengine/rtpengine.conf is NOT in this repository, it is
# shipped by the ivozprovider-rtpengine package and patched at runtime by the
# entrypoint the same way ivozprovider-profile-proxy.postinst does.
################################################################################
RUN apt-get update && \
    apt-get install --assume-yes ivozprovider-rtpengine \
    && apt-get clean

RUN apt-get update && \
    apt-get install --assume-yes --no-install-recommends \
        iproute2 \
        procps \
    && apt-get clean

COPY docker/rtpengine/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
