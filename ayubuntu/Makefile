REPO    := ayakurayuki
IMAGE   := ayubuntu
VERSION ?= ""
TAG     := $(REPO)/$(IMAGE):$(VERSION)

.DEFAULT_GOAL := help
help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo
	@echo 'To build images, choose one of the VERSION:'
	@echo '  - 26.04'
	@echo
	@echo 'Example:'
	@echo '  - VERSION=26.04 make build'
	@echo '  - VERSION=26.04 make build-aarch64'

define check_vars
	@ if [ "$(VERSION)" = "" ]; then echo " <- Env variable VERSION not set"; exit 1; fi
endef

.PHONY: help build build-aarch64

build: ## Build image in amd64
	@$(call check_vars)
	@echo " - version: $(VERSION)"
	@docker buildx build --platform linux/amd64 --progress=plain --file ./docker/ubuntu-$(VERSION).dockerfile -t $(TAG)-amd64 ./docker

build-aarch64: ## Build image in aarch64
	@$(call check_vars)
	@echo " - version: $(VERSION)"
	@docker buildx build --platform linux/arm64 --progress=plain --file ./docker/ubuntu-$(VERSION)-aarch64.dockerfile -t $(TAG)-aarch64 ./docker
