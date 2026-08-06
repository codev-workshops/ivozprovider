#!/bin/bash
set -euo pipefail

# Container equivalent of debian/ivozprovider-profile-as.postinst. Values that
# the package takes from debconf are taken from the environment here.
MYSQL_PASSWORD="${MYSQL_PASSWORD:-changeme}"
MYSQL_HOST="${MYSQL_HOST:-data.ivozprovider.local}"
FASTAGI_SERVER="${FASTAGI_SERVER:-127.0.0.1:4573}"
DIAL_DEF_OPTS="${DIAL_DEF_OPTS:-}"

# setup_php()
sed -i 's/variables_order = "GPCS"/variables_order = "EGPCS"/g' /etc/php/8.2/cli/php.ini
sed -i 's/;*date.timezone =.*/date.timezone = UTC/g' /etc/php/8.2/cli/php.ini

# setup_mysql_access(): res_odbc reaches the DB through /etc/odbc.ini, which the
# package links to /etc/odbc.ini.ivozprovider.
install -m 0644 /usr/share/ivozprovider-legacy/odbc.ini.ivozprovider /etc/odbc.ini.ivozprovider
install -m 0644 /usr/share/ivozprovider-legacy/odbcinst.ini.ivozprovider /etc/odbcinst.ini.ivozprovider
sed -i -r "s/(Password *= *).*/\1${MYSQL_PASSWORD}/" /etc/odbc.ini.ivozprovider
sed -i -r "s/(Server *= *).*/\1${MYSQL_HOST}/" /etc/odbc.ini.ivozprovider
ln -sf /etc/odbc.ini.ivozprovider /etc/odbc.ini

# setup_odbcinst()
odbcinst -q -d -n MYSQL >/dev/null 2>&1 || odbcinst -i -d -f /etc/odbcinst.ini.ivozprovider

# setup_fastagi_server() / setup_default_dial_opts()
sed -i -r "s#(FASTAGI_SERVER *= *).*#\1${FASTAGI_SERVER}#" /etc/asterisk/extensions.conf
sed -i -r "s#(DIAL_DEF_OPTS *= *).*#\1${DIAL_DEF_OPTS}#" /etc/asterisk/extensions.conf

# setup_mysql() from debian/ivozprovider.postinst rewrites the DSN in the
# vendored bundle .env; the FastAGI app reads its DB connection from there.
BUNDLE_ENV=/opt/irontec/ivozprovider/library/vendor/irontec/ivoz-provider-bundle/.env
if [ -f "$BUNDLE_ENV" ]; then
    sed -i -r "s#(DATABASE_URL=mysql://[^:]+:)[^@]*(@)[^:/]+#\1${MYSQL_PASSWORD}\2${MYSQL_HOST}#" "$BUNDLE_ENV"
fi

# The storage tree is shared with the backend and asterisk containers, which run
# as different uids (NFS with no_root_squash on a real deployment). This mirrors
# `mkdir -m 777 -p .../storage` in tests/docker/bin/prepare-fixtures.
install -d -m 0777 /opt/irontec/ivozprovider/storage

/usr/local/bin/wait-for-tcp "${MYSQL_HOST}" 3306

# fastagi.socket + fastagi@.service are systemd socket activation: one
# phpagi-fastagi.php process per accepted connection on 127.0.0.1:4573.
# socat reproduces that exactly without systemd in the container.
socat TCP-LISTEN:"${FASTAGI_SERVER##*:}",bind="${FASTAGI_SERVER%%:*}",reuseaddr,fork \
    EXEC:/opt/irontec/ivozprovider/asterisk/agi/phpagi/phpagi-fastagi.php &

exec /usr/sbin/asterisk -f -vvv -U root -G root
