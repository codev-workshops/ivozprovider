#!/bin/bash
#
# Docker entrypoint for the IvozProvider application server.
#
# Replicates the pieces of debian/ivozprovider-profile-as.postinst and
# debian/ivozprovider.postinst setup_pbx() that are done at install time on a
# real node, plus a socat stand-in for the socket-activated fastagi@ service
# (debian/systemd/fastagi.socket + fastagi@.service).

set -e

FASTAGI_SERVER="${FASTAGI_SERVER:-127.0.0.1:4573}"
DIAL_DEF_OPTS="${DIAL_DEF_OPTS:-}"
# debian/ivozprovider.postinst setup_pbx() forces 127.0.0.1 because kamailio
# runs on the same host. Here the proxies are separate containers, so pjsip and
# AMI have to listen on the container address instead.
PJSIP_BIND="${PJSIP_BIND:-0.0.0.0:6060}"
AMI_BIND="${AMI_BIND:-0.0.0.0}"

# ivozprovider-profile-as.postinst setup_fastagi_server()
sed -i -r "s/(FASTAGI_SERVER *= *).*/\1${FASTAGI_SERVER}/" /etc/asterisk/extensions.conf
# ivozprovider-profile-as.postinst setup_default_dial_opts()
sed -i -r "s/(DIAL_DEF_OPTS *= *).*/\1${DIAL_DEF_OPTS}/"    /etc/asterisk/extensions.conf

# debian/ivozprovider.postinst setup_pbx()
sed -i "s#bind=0.0.0.0:6060#bind=${PJSIP_BIND}#g"      /etc/asterisk/pjsip.conf
sed -i "s#bindaddr = 0.0.0.0#bindaddr = ${AMI_BIND}#g" /etc/asterisk/manager.conf

mkdir -p /opt/irontec/ivozprovider/storage
chmod 777 /opt/irontec/ivozprovider/storage

echo "[asterisk] waiting for data.ivozprovider.local..."
export MYSQL_PWD=changeme
until mysql --host=data.ivozprovider.local --user=asterisk ivozprovider \
    --execute="SELECT 1 FROM ast_ps_endpoints LIMIT 1" >/dev/null 2>&1; do
    sleep 2
done

echo "[asterisk] starting fastagi listener on ${FASTAGI_SERVER}"
socat TCP-LISTEN:"${FASTAGI_SERVER##*:}",bind="${FASTAGI_SERVER%%:*}",reuseaddr,fork \
    EXEC:/opt/irontec/ivozprovider/asterisk/agi/phpagi/phpagi-fastagi.php &

echo "[asterisk] starting asterisk"
exec /usr/sbin/asterisk -f -vvv -U root -G root
