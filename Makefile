CC = gcc
SRCDIR = src
BUILDDIR = build
REGISTRY = quay.io
ORG = lrotenbe
IMG = sample-apps
TAG = latest

PROJECT_DIR := $(shell pwd)

all: $(BUILDDIR)/hello $(BUILDDIR)/radio-client $(BUILDDIR)/radio-service

$(BUILDDIR)/hello: $(SRCDIR)/hello.c
	mkdir -p $(BUILDDIR)
	$(CC) -o $(BUILDDIR)/hello $(SRCDIR)/hello.c

$(BUILDDIR)/radio-client $(BUILDDIR)/radio-service:
	mkdir -p $(BUILDDIR)
	podman run --rm \
		-v $(PROJECT_DIR):$(PROJECT_DIR) \
		-w $(PROJECT_DIR) \
		centos:stream9-development \
		/bin/bash -c "dnf install -y 'dnf-command(config-manager)' && \
		dnf install -y --nogpgcheck epel-release epel-next-release && \
		dnf update -y && \
		dnf install -y --nogpgcheck vsomeip3-devel boost-devel cmake gcc gcc-c++ && \
		cd $(SRCDIR) && \
		cmake -B ../$(BUILDDIR) && \
		cmake --build ../$(BUILDDIR)"

container-image:
	podman build $(SRCDIR) -t $(REGISTRY)/$(ORG)/$(IMG):$(TAG)

publish-container: container-image
	podman push $(REGISTRY)/$(ORG)/$(IMG):$(TAG)

clean:
	rm -rf $(BUILDDIR)
	rm -f hello.aib.yml

clean-container:
	podman image rm -f $(REGISTRY)/$(ORG)/$(IMG):$(TAG) || true

.PHONY: all clean publish-container clean-container container-image
