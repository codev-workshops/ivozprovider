#!/bin/bash
#
# Docker entrypoint for the media relay.
#
# Applies the same sed rewrites as debian/ivozprovider-profile-proxy.postinst
# setup_media_relays() over the rtpengine.conf shipped by the package.

set -e

# Container address, used both as the media interface and as the ng control
# socket address (kam_rtpengine.url points here).
OWN_IP=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)

MEDIA_RELAY_ADDRESS="${MEDIA_RELAY_ADDRESS:-$OWN_IP}"
MEDIA_RELAY_CONTROL="${MEDIA_RELAY_CONTROL:-$OWN_IP}"
# Media port range. Same values as the debconf defaults in
# debian/ivozprovider-profile-proxy.templates (ivozprovider/media_relay_minport
# and ivozprovider/media_relay_maxport), which are also the defaults baked into
# the rtpengine.conf shipped by ivozprovider-rtpengine. Narrowed by default here
# because docker has to publish every port in the range one by one.
MEDIA_RELAY_MINPORT="${MEDIA_RELAY_MINPORT:-13000}"
MEDIA_RELAY_MAXPORT="${MEDIA_RELAY_MAXPORT:-13200}"

CONF=/etc/rtpengine/rtpengine.conf

sed -i -r "s#(interface *= *).*#\1$MEDIA_RELAY_ADDRESS#"      $CONF
sed -i -r "s#(listen-ng *= *).*#\1$MEDIA_RELAY_CONTROL:2223#" $CONF
sed -i -r "s#(port-min *= *).*#\1$MEDIA_RELAY_MINPORT#"       $CONF
sed -i -r "s#(port-max *= *).*#\1$MEDIA_RELAY_MAXPORT#"       $CONF

# The kernel forwarding table needs the xt_RTPENGINE module loaded on the host;
# containers run the userspace-only relay instead.
sed -i -r "s#(table *= *).*#\1-1#" $CONF
sed -i -r "s#(listen-cli *= *).*#\1$MEDIA_RELAY_CONTROL:9900#" $CONF

mkdir -p /opt/irontec/ivozprovider/storage/ivozprovider_model_recordings.spool/

cat $CONF

exec /usr/sbin/rtpengine --config-file=$CONF --foreground --log-stderr
