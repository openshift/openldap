OPENLDAP_VERSION := $(shell git describe --tags --always --dirty)

RUNTIME ?= podman
CONTAINER_REGISTRY := dockerhub.com
IMAGE_NAME := openshift/openldap
IMAGE_PATH := $(CONTAINER_REGISTRY)/$(IMAGE_NAME)

ifeq ($(TARGET),rhel7)
	IMAGE_TAG := $(OPENLDAP_VERSION)-rhel
else
	IMAGE_TAG := $(OPENLDAP_VERSION)-fedora
endif

IMAGE := $(IMAGE_PATH):$(IMAGE_TAG)

.PHONY: build
build:
	$(RUNTIME) build \
		--build-arg VERSION="$(OPENLDAP_VERSION)" \
		-t "$(IMAGE)" \
		-f images/Dockerfile \
		.

.PHONY: test
test: build
	IMAGE="$(IMAGE)" \
	RUNTIME="$(RUNTIME)" \
		hack/test.sh

.PHONY: imagename
imagename:
	@echo "$(IMAGE)"
