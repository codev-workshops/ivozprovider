FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && curl -fsSL http://packages.irontec.com/public.key http://packages.irontec.com/public-256.key \
        | gpg --dearmor -o /usr/share/keyrings/irontec.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/irontec.gpg] http://packages.irontec.com/debian tempest main extra" \
        > /etc/apt/sources.list.d/irontec.list \
    && curl -fsSL https://packages.sury.org/php/apt.gpg -o /usr/share/keyrings/sury-php.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php bookworm main" \
        > /etc/apt/sources.list.d/sury-php.list \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ivozprovider-asterisk \
        ivozprovider-asterisk-config \
        ivozprovider-asterisk-sounds \
        ivozprovider-asterisk-agi \
        odbc-mariadb \
        unixodbc \
        default-mysql-client \
        netcat-openbsd \
        socat \
    && rm -rf /var/lib/apt/lists/*

# The profile package configures ODBC from these two files; they are not part of
# any of the component packages installed above.
COPY profiles/as/etc/odbc.ini.ivozprovider profiles/as/etc/odbcinst.ini.ivozprovider /usr/share/ivozprovider-legacy/
COPY docker/legacy/bin/wait-for-tcp /usr/local/bin/wait-for-tcp
COPY docker/legacy/asterisk/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/wait-for-tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
