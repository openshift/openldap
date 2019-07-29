SKIP_SQUASH?=0
VERSIONS="2.4.41 2.4.46"

ifeq ($(TARGET),rhel7)
	OS := rhel7
else ifeq ($(TARGET),fed29)
	OS := fed29
else
	OS := centos7
endif

ifeq ($(VERSION), 2.4.41)
	VERSION := 2.4.41
else ifeq ($(VERSION), 2.4.46)
	VERSION := 2.4.46
else
	VERSION :=
endif

.PHONY: build
build:
	SKIP_SQUASH=$(SKIP_SQUASH) VERSIONS=$(VERSIONS) hack/build.sh $(OS) $(VERSION)
.PHONY: test
test:
	SKIP_SQUASH=$(SKIP_SQUASH) VERSIONS=$(VERSIONS) TAG_ON_SUCCESS=$(TAG_ON_SUCCESS) TEST_MODE=true hack/build.sh $(OS) $(VERSION)
