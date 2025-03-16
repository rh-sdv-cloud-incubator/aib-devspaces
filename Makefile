CC = gcc
SRCDIR = src
BUILDDIR = build
ARTIFACTS_DIR = /workspace/artifacts
REGISTRY = quay.io
ORG = lrotenbe
IMG = sample-apps
TAG = latest

all: $(BUILDDIR)/hello $(BUILDDIR)/radio generate-manifest

$(BUILDDIR)/hello: $(SRCDIR)/hello.c
	mkdir -p $(BUILDDIR)
	$(CC) -o $(BUILDDIR)/hello $(SRCDIR)/hello.c

$(BUILDDIR)/radio:
	mkdir -p $(BUILDDIR)
	podman build $(SRCDIR) -t $(REGISTRY)/$(ORG)/$(IMG):$(TAG)

publish-conatiner:
	podman push $(REGISTRY)/$(ORG)/$(IMG):$(TAG)

generate-manifest:
	@chmod +x ./generate-manifest.sh
	@./generate-manifest.sh

clean:
	rm -rf $(BUILDDIR)
	rm -f $(ARTIFACTS_DIR)/hello
	rm -f hello.aib.yml

clean-container:
	podman image rm $(REGISTRY)/$(ORG)/$(IMG):$(TAG)

.PHONY: all clean generate-manifest publish-container clean-container
