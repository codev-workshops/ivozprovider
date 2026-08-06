-- Database accounts used by the SIP/media components.
--
-- Same grants debian/ivozprovider-profile-data.postinst setup_mysql_access()
-- creates on a real data node, with the 'changeme' password used across the
-- compose stack.

CREATE USER IF NOT EXISTS 'kamailio'@'%' IDENTIFIED BY 'changeme';
ALTER USER 'kamailio'@'%' IDENTIFIED BY 'changeme';
GRANT ALL ON *.* TO 'kamailio'@'%';

CREATE USER IF NOT EXISTS 'asterisk'@'%' IDENTIFIED BY 'changeme';
ALTER USER 'asterisk'@'%' IDENTIFIED BY 'changeme';
GRANT ALL ON *.* TO 'asterisk'@'%';

FLUSH PRIVILEGES;
