FROM mariadb:10.8

COPY ./docker/mariadb/initial.sql /docker-entrypoint-initdb.d/10-initial.sql
COPY ./docker/mariadb/initdb/ /docker-entrypoint-initdb.d/
