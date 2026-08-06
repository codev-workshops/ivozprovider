-- Legacy baseline only. Runs after schema/initial.sql in the entrypoint.
--
-- schema/initial.sql describes a single-host install: every service address in
-- it is 127.0.0.1. The compose stack splits those services into containers, so
-- the inventory rows have to name the containers instead. These are addresses
-- of *our own* containers, not carrier- or customer-trusted addresses.
--
-- ProxyUsers/ProxyTrunks are deliberately left untouched: profiles/proxy/etc/
-- kamailio/autoconf special-cases id=1 and listens on the literal name
-- `users`/`trunks`, which resolve to the containers via compose aliases.

-- Accounts created by debian/ivozprovider-profile-data.postinst. Kamailio's
-- db_mysql and Asterisk's res_odbc authenticate as these.
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'changeme';
ALTER USER 'root'@'%' IDENTIFIED VIA mysql_native_password USING PASSWORD('changeme');
GRANT ALL ON *.* TO 'root'@'%';

CREATE USER IF NOT EXISTS 'kamailio'@'%' IDENTIFIED BY 'changeme';
ALTER USER 'kamailio'@'%' IDENTIFIED VIA mysql_native_password USING PASSWORD('changeme');
GRANT ALL ON *.* TO 'kamailio'@'%';

CREATE USER IF NOT EXISTS 'asterisk'@'%' IDENTIFIED BY 'changeme';
ALTER USER 'asterisk'@'%' IDENTIFIED VIA mysql_native_password USING PASSWORD('changeme');
GRANT ALL ON *.* TO 'asterisk'@'%';

FLUSH PRIVILEGES;

USE ivozprovider;

-- Kamailio dispatches calls to the application server at this address.
UPDATE ApplicationServers SET ip = '10.189.4.42' WHERE name = 'as001';

-- rtpengine's ng control socket (listen-ng in /etc/rtpengine/rtpengine.conf).
UPDATE kam_rtpengine SET url = 'udp:10.189.4.43:2223' WHERE url LIKE 'udp:127.0.0.1:%';
