FROM mariadb:10.8

COPY ./docker/mariadb/initial.sql /docker-entrypoint-initdb.d
COPY ./docker/mariadb/users.sql /docker-entrypoint-initdb.d
