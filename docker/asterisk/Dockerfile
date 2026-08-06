FROM debian:bookworm

################################################################################
# Irontec package repository (same one used by the Debian install)
################################################################################
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install --assume-yes --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
    && apt-get clean

COPY debian/sources.list /etc/apt/sources.list.d/irontec.list
RUN curl -sS http://packages.irontec.com/public.key \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/irontec.gpg

################################################################################
# Asterisk + AGIs, as ivozprovider-profile-as depends on (debian/control)
################################################################################
RUN apt-get update && \
    apt-get install --assume-yes \
        ivozprovider-asterisk \
        ivozprovider-asterisk-agi \
        ivozprovider-asterisk-config \
        ivozprovider-asterisk-sounds \
        odbc-mariadb \
    && apt-get clean

RUN apt-get update && \
    apt-get install --assume-yes --no-install-recommends \
        default-mysql-client \
        socat \
        unixodbc \
        iproute2 \
        procps \
    && apt-get clean

################################################################################
# IvozProvider configuration
# (debian/ivozprovider-asterisk-config.install + ivozprovider-profile-as.*)
################################################################################
COPY asterisk/config/ /etc/asterisk/
COPY asterisk/config/pjsip.conf.in /etc/asterisk/pjsip.conf

# ivozprovider-profile-as.install ships profiles/as/* and links
# /etc/odbc.ini.ivozprovider -> /etc/odbc.ini (ivozprovider-profile-as.links)
COPY profiles/as/etc/odbc.ini.ivozprovider     /etc/odbc.ini.ivozprovider
COPY profiles/as/etc/odbcinst.ini.ivozprovider /etc/odbcinst.ini.ivozprovider
RUN ln -sf /etc/odbc.ini.ivozprovider /etc/odbc.ini

# ivozprovider-profile-as.postinst setup_php()
RUN sed -i 's/variables_order = "GPCS"/variables_order = "EGPCS"/g' /etc/php/8.2/cli/php.ini && \
    sed -i 's/;*date.timezone =.*/date.timezone = UTC/g'            /etc/php/8.2/cli/php.ini

# ivozprovider-profile-as.postinst setup_mysql_access(): same 'changeme'
# password the rest of the compose stack uses
RUN sed -i -r "s/(Password *= *).*/\1changeme/" /etc/odbc.ini.ivozprovider && \
    sed -i -r "s/(Server *= *).*/\1data.ivozprovider.local/" /etc/odbc.ini.ivozprovider

# ivozprovider-profile-as.postinst setup_odbcinst()
RUN odbcinst -i -d -f /etc/odbcinst.ini.ivozprovider

COPY docker/asterisk/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
