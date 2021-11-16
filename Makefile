RUNTIME ?= podman
CONTAINER_REGISTRY := dockerhub.com
IMAGE_NAME := openshift/openldap
IMAGE_PATH := $(CONTAINER_REGISTRY)/$(IMAGE_NAME)

ifeq ($(TARGET),rhel7)
	PLATFORMS ?= linux/amd64,linux/ppc64le,linux/s390x
	IMAGE_TAG := rhel7
	IMAGE_FILE := images/Dockerfile.rhel7
else
	PLATFORMS ?= linux/amd64,linux/arm64,linux/ppc64le,linux/s390x
	IMAGE_TAG := fedora34
	IMAGE_FILE := images/Dockerfile
endif

IMAGE := $(IMAGE_PATH):$(IMAGE_TAG)

.PHONY: build
build:
	$(RUNTIME) build \
		--platform $(PLATFORMS) \
		--manifest "$(IMAGE)" \
		-f "$(IMAGE_FILE)" \
		.

.PHONY: test
test: build
	IMAGE="$(IMAGE)" \
	RUNTIME="$(RUNTIME)" \
		hack/test.sh

.PHONY: push
push:
	$(RUNTIME) manifest push $(IMAGE) $(IMAGE)

.PHONY: image_name
image_name:
	@echo "$(IMAGE)"
