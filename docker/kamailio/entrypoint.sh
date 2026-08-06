#!/bin/bash
#
# Docker entrypoint for the users/trunks SIP proxies.
#
# Mirrors debian/systemd/kamailio@.service: read /etc/default/kam<role> for the
# memory settings, run /etc/kamailio/autoconf <role> to render ports.cfg and
# listeners.cfg out of the ProxyUsers/ProxyTrunks rows, then exec kamailio.
# The daemon runs in foreground (-D) because there is no systemd in the image.

set -e

ROLE="${1:-users}"

if [ "$ROLE" != "users" ] && [ "$ROLE" != "trunks" ]; then
    echo "Usage: entrypoint.sh users|trunks" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "/etc/default/kam${ROLE}"

# Same credentials kamailio itself uses through DBURL "mysql://[kamailio]/..."
CNF=/etc/mysql/conf.d/kamailio.cnf
DB_HOST=$(sed -nr 's/^host *= *(.*)$/\1/p' $CNF)
DB_USER=$(sed -nr 's/^user *= *(.*)$/\1/p' $CNF)
DB_PASS=$(sed -nr 's/^password *= *(.*)$/\1/p' $CNF)
export MYSQL_PWD="$DB_PASS"

function query() {
    mysql --host="$DB_HOST" --user="$DB_USER" --batch --skip-column-names \
        ivozprovider --execute="$1" 2>/dev/null
}

TABLE="ProxyUsers"
[ "$ROLE" = "trunks" ] && TABLE="ProxyTrunks"

echo "[kamailio-${ROLE}] waiting for ${TABLE} rows on ${DB_HOST}..."
until [ "$(query "SELECT COUNT(*) FROM ${TABLE} WHERE ip IS NOT NULL AND ip != ''")" \
        -gt 0 ] 2>/dev/null; do
    sleep 2
done

echo "[kamailio-${ROLE}] generating ports.cfg/listeners.cfg"
/etc/kamailio/autoconf "$ROLE"

# autoconf makes the first proxy listen on the bare '<role>' name
# (printListener: $ip = $PROXY if $id == 1), which on a real node resolves
# through the ivozprovider.local search domain. dmq matches its server_address
# (sip:<role>.ivozprovider.local:5060, from printPorts) against the *name* of a
# listen socket rather than against the resolved address, and kamailio resolves
# socket names through DNS, not /etc/hosts. Both therefore have to be the fully
# qualified name served by the resolver service.
sed -i -r "s#(listen=[a-z]+:)${ROLE}:#\1${ROLE}.ivozprovider.local:#" \
    "/etc/kamailio/proxy${ROLE}/listeners.cfg"
cat "/etc/kamailio/proxy${ROLE}/listeners.cfg"

# The config logs to syslog, which nothing collects in a container.
sed -i 's/^log_stderror=no/log_stderror=yes/' "/etc/kamailio/proxy${ROLE}/kamailio.cfg"

# -DD: keep the main process in the foreground but fork the workers as usual.
# Plain -D (what a debugging session would use) runs everything in a single
# process, which disables TCP and therefore SIPS/WS/WSS/RPC.
exec /usr/sbin/kamailio \
    -f "/etc/kamailio/proxy${ROLE}/kamailio.cfg" \
    -m "${SH_MEM}" \
    -M "${PRIV_MEM}" \
    -DD -E
