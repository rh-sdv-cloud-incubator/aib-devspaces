CC = gcc
SRCDIR = src
BUILDDIR = build
REGISTRY = quay.io
ORG = lrotenbe
IMG = sample-apps
TAG = latest
BUILD_IMG = local/auto-build-env:latest

PROJECT_DIR := $(shell pwd)
CONTAINER_PROJECT_DIR := /project

all: $(BUILDDIR)/hello $(BUILDDIR)/radio-client $(BUILDDIR)/radio-service

$(BUILDDIR)/hello: $(SRCDIR)/hello.c
	mkdir -p $(BUILDDIR)
	$(CC) -o $(BUILDDIR)/hello $(SRCDIR)/hello.c

build-env:
	podman build -t $(BUILD_IMG) -f src/Dockerfile .

$(BUILDDIR)/radio-client $(BUILDDIR)/radio-service: build-env
	mkdir -p $(BUILDDIR)
	podman run --rm \
		-v $(PROJECT_DIR):$(CONTAINER_PROJECT_DIR):Z \
		-w $(CONTAINER_PROJECT_DIR) \
		$(BUILD_IMG) \
		"cd $(SRCDIR) && \
		mkdir -p ../$(BUILDDIR) && \
		cmake -B ../$(BUILDDIR) && \
		cmake --build ../$(BUILDDIR)"

container-image:
	podman build -f $(SRCDIR)/Dockerfile -t $(REGISTRY)/$(ORG)/$(IMG):$(TAG) $(SRCDIR)

publish-container: container-image
	podman push $(REGISTRY)/$(ORG)/$(IMG):$(TAG)

clean:
	rm -rf $(BUILDDIR)
	rm -f hello.aib.yml

clean-container:
	podman image rm -f $(REGISTRY)/$(ORG)/$(IMG):$(TAG) || true
	podman image rm -f $(BUILD_IMG) || true

.PHONY: all clean publish-container clean-container container-image build-env
