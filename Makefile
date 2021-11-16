RUNTIME ?= podman
CONTAINER_REGISTRY := quay.io
IMAGE_NAME := openshift-auth/openldap
IMAGE_PATH := $(CONTAINER_REGISTRY)/$(IMAGE_NAME)

ifeq ($(TARGET),rhel7)
	IMAGE_TAG := rhel7
	IMAGE_FILE := images/Dockerfile.rhel7
else
	IMAGE_TAG := fedora34
	IMAGE_FILE := images/Dockerfile
endif

IMAGE := $(IMAGE_PATH):$(IMAGE_TAG)

.PHONY: build
build:
	$(RUNTIME) build \
		-t "$(IMAGE)" \
		-f "$(IMAGE_FILE)" \
		.

.PHONY: test
test: build
	IMAGE="$(IMAGE)" \
	RUNTIME="$(RUNTIME)" \
		hack/test.sh

.PHONY: push
push: build
	RUNTIME="$(RUNTIME)" push \
		$(IMAGE)

.PHONY: image_name
image_name:
	@echo "$(IMAGE)"
