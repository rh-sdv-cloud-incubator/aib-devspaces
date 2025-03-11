CC = gcc
SRCDIR = src
BUILDDIR = build
ARTIFACTS_DIR = /workspace/artifacts

all: $(BUILDDIR)/hello publish-artifacts generate-manifest

$(BUILDDIR)/hello: $(SRCDIR)/hello.c
	mkdir -p $(BUILDDIR)
	$(CC) -o $(BUILDDIR)/hello $(SRCDIR)/hello.c

publish-artifacts: $(BUILDDIR)/hello
	mkdir -p $(ARTIFACTS_DIR)
	cp $(BUILDDIR)/hello $(ARTIFACTS_DIR)/

generate-manifest:
	@chmod +x ./generate-manifest.sh
	@./generate-manifest.sh

clean:
	rm -rf $(BUILDDIR)
	rm -f $(ARTIFACTS_DIR)/hello
	rm -f hello.aib.yml

.PHONY: all clean publish-artifacts generate-manifest
