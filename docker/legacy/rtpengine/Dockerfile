FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && curl -fsSL http://packages.irontec.com/public.key http://packages.irontec.com/public-256.key \
        | gpg --dearmor -o /usr/share/keyrings/irontec.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/irontec.gpg] http://packages.irontec.com/debian tempest main extra" \
        > /etc/apt/sources.list.d/irontec.list \
    && rm -rf /var/lib/apt/lists/*

# rtpengine Pre-Depends on dkms + linux-headers to build its in-kernel forwarding
# module. A container has no kernel to build against and the baseline runs the
# userspace forwarder only, so the kernel module is deliberately not built:
# dkms is satisfied by a stub that makes the dkms hooks no-ops.
COPY docker/legacy/rtpengine/dkms-stub /usr/src/dkms-stub
COPY docker/legacy/rtpengine/dkms-common.postinst /usr/lib/dkms/common.postinst
RUN chmod 0755 /usr/lib/dkms/common.postinst \
    && apt-get update \
    && apt-get install -y --no-install-recommends equivs \
    && (cd /usr/src/dkms-stub && equivs-build dkms.control && equivs-build linux-headers.control) \
    && apt-get install -y --no-install-recommends /usr/src/dkms-stub/*.deb \
    && apt-get install -y --no-install-recommends ivozprovider-rtpengine \
    && apt-get purge -y equivs && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# rtpengine-ctl (used by the healthcheck) is a perl script and the package does
# not depend on its modules.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libconfig-tiny-perl libsocket6-perl \
    && rm -rf /var/lib/apt/lists/*

COPY docker/legacy/rtpengine/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
