#!/bin/bash
set -euo pipefail

# Container equivalent of debian/ivozprovider-profile-proxy.postinst
# (setup_mysql_access) plus the ExecStartPre=/etc/kamailio/autoconf %i step from
# debian/systemd/kamailio@.service.
PROXY="${1:?usage: entrypoint.sh <users|trunks>}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-changeme}"
MYSQL_HOST="${MYSQL_HOST:-data.ivozprovider.local}"
SH_MEM="${SH_MEM:-256}"
PRIV_MEM="${PRIV_MEM:-256}"

install -d -m 0755 /etc/mysql/conf.d
install -m 0644 /usr/share/ivozprovider-legacy/kamailio.cnf /etc/mysql/conf.d/kamailio.cnf
sed -i -r "s#(password *= *).*#\1${MYSQL_PASSWORD}#" /etc/mysql/conf.d/kamailio.cnf
sed -i -r "s#(host *= *).*#\1${MYSQL_HOST}#" /etc/mysql/conf.d/kamailio.cnf

mkdir -p /opt/irontec/ivozprovider/storage

/usr/local/bin/wait-for-tcp "${MYSQL_HOST}" 3306

install -m 0644 "/usr/share/ivozprovider-legacy/ports-${PROXY}.cfg.dev" \
    "/etc/kamailio/proxy${PROXY}/ports.cfg.dev"

# autoconf reads ProxyUsers/ProxyTrunks and writes listeners.cfg + ports.cfg,
# which proxy${PROXY}/kamailio.cfg include_file's. It only runs at service
# start, exactly as ExecStartPre does on a real node.
/etc/kamailio/autoconf "${PROXY}"

exec /usr/sbin/kamailio -DD -E \
    -f "/etc/kamailio/proxy${PROXY}/kamailio.cfg" \
    -m "${SH_MEM}" -M "${PRIV_MEM}"
