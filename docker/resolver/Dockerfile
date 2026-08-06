FROM debian:bookworm

# Stand-in for the BIND ivozprovider.local zone (profiles/data/etc/bind) that a
# real deployment serves from the data node. Only needed by the SIP clients,
# which are told which nameserver to use.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install --assume-yes --no-install-recommends dnsmasq dnsutils \
    && apt-get clean

COPY docker/resolver/dnsmasq.conf /etc/dnsmasq.conf

EXPOSE 53/udp 53/tcp

CMD ["/usr/sbin/dnsmasq", "--keep-in-foreground", "--log-queries", "--log-facility=-"]
