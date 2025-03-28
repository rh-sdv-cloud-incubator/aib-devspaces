# Build stage
FROM quay.io/centos/centos:stream9-development AS builder

RUN dnf install -y 'dnf-command(config-manager)' && \
    dnf install -y --nogpgcheck epel-release epel-next-release && \
    dnf install -y --releasever 9 --nogpgcheck \
    vsomeip3-devel \
    boost-devel \
    cmake \
    gcc \
    gcc-c++ && \
    dnf clean all

COPY . /src/
WORKDIR /src

RUN cmake . && make

FROM quay.io/centos/centos:stream9-development

RUN dnf install -y 'dnf-command(config-manager)' && \
    dnf install -y --nogpgcheck epel-release epel-next-release && \
    dnf install -y --releasever 9 --nogpgcheck \
    vsomeip3 \
    dlt-daemon \
    vsomeip3-routingmanager && \
    dnf clean all

COPY --from=builder /src/radio-client /usr/local/bin/
COPY --from=builder /src/radio-service /usr/local/bin/
COPY --from=builder /src/engine-service /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/

RUN chmod 755 /usr/local/bin/radio-client \
    /usr/local/bin/radio-service \
    /usr/local/bin/engine-service \
    /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
