FROM quay.io/centos/centos:stream9-development

# Enable required repositories
RUN dnf install -y 'dnf-command(config-manager)' && \
    dnf copr -y enable alexl/cs9-sample-images centos-stream-9 && \
    dnf install -y --nogpgcheck epel-release epel-next-release

RUN dnf install -y --releasever 9 --nogpgcheck \
    vsomeip3 \
    vsomeip3-routingmanager \
    dlt-daemon \
    boost-system \
    boost-thread \
    boost-log \
    boost-chrono \
    boost-date-time \
    boost-atomic \
    boost-filesystem \
    boost-regex && \
    dnf clean all

RUN mkdir -p /usr/local/bin

COPY radio-client radio-service engine-service entrypoint.sh /usr/local/bin/

RUN chmod 755 /usr/local/bin/radio-client \
    /usr/local/bin/radio-service \
    /usr/local/bin/engine-service \
    /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
