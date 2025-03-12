FROM centos:stream9-development

RUN dnf install -y 'dnf-command(config-manager)'
RUN dnf install -y --nogpgcheck epel-release epel-next-release
RUN dnf update -y

RUN dnf install -y --nogpgcheck vsomeip3-devel boost-devel cmake gcc gcc-c++ dlt-daemon vsomeip3-routingmanager && dnf clean all
COPY ./ .
RUN cmake . && make
RUN chmod 777 radio-client radio-service entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
