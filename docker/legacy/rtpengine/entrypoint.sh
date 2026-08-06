#!/bin/bash
set -euo pipefail

# Mirrors setup_media_relays() from debian/ivozprovider-profile-proxy.postinst,
# which seds these four values into /etc/rtpengine/rtpengine.conf from debconf.
MEDIA_RELAY_ADDRESS="${MEDIA_RELAY_ADDRESS:-$(hostname -i | awk '{print $1}')}"
MEDIA_RELAY_CONTROL="${MEDIA_RELAY_CONTROL:-$(hostname -i | awk '{print $1}')}"
MEDIA_RELAY_MINPORT="${MEDIA_RELAY_MINPORT:-13000}"
MEDIA_RELAY_MAXPORT="${MEDIA_RELAY_MAXPORT:-13500}"

CONF=/etc/rtpengine/rtpengine.conf

# recording-dir lives on the shared storage volume (NFS on a real deployment).
mkdir -p "$(sed -nr 's#^ *recording-dir *= *##p' "$CONF")"

sed -i -r "s#(interface *= *).*#\1${MEDIA_RELAY_ADDRESS}#" "$CONF"
sed -i -r "s#(listen-ng *= *).*#\1${MEDIA_RELAY_CONTROL}:2223#" "$CONF"
sed -i -r "s#(port-min *= *).*#\1${MEDIA_RELAY_MINPORT}#" "$CONF"
sed -i -r "s#(port-max *= *).*#\1${MEDIA_RELAY_MAXPORT}#" "$CONF"

# table=-1 disables the kernel forwarding module (not available in a container);
# no-fallback would then abort startup instead of using the userspace forwarder.
sed -i -r "s#^ *table *= *.*#table = -1#" "$CONF"
sed -i -r "s#^ *no-fallback *= *.*#no-fallback = false#" "$CONF"

exec /usr/bin/rtpengine --config-file="$CONF" --foreground --log-stderr "$@"
