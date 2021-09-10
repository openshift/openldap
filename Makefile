OPENLDAP_VERSION := $(shell git describe --tags --always --dirty)
DOCKER_REGISTRY := dockerhub.com
DOCKER_IMAGE_NAME := openshift/openldap
DOCKER_IMAGE := $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME)
TIMESTAMP_RFC3339 := $(shell date +%Y-%m-%dT%T%z)

ifeq ($(TARGET),rhel7)
	OS := rhel7
	DOCKER_TAG_PUSH ?= "$(OPENLDAP_VERSION)-rhel"
else
	OS := fedora:34
	DOCKER_TAG_PUSH ?= "$(OPENLDAP_VERSION)-fedora"
endif


.PHONY: build
build:
	docker build \
		--build-arg VERSION="$(VERSION)" \
		--build-arg OS="$(OS)" \
		-t "$(DOCKER_IMAGE):$(DOCKER_TAG_PUSH)" \
		-f images/Dockerfile \
		.

.PHONY: test
test: build
	IMAGE_NAME="$(DOCKER_IMAGE):$(DOCKER_TAG_PUSH)" \
		hack/test.sh

.PHONY: imagename
imagename:
	@echo "$(DOCKER_IMAGE):$(DOCKER_TAG_PUSH)"
