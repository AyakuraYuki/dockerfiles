REPO    := ayakurayuki
IMAGE   := ayubuntu
VERSION ?= ""
TAG     := $(REPO)/$(IMAGE):$(VERSION)

define check_vars
	@ if [ "$(VERSION)" = "" ]; then echo " <- Env variable VERSION not set"; exit 1; fi
endef

.PHONY: help build build-aarch64

.DEFAULT_GOAL := help
help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build image in amd64
	@$(call check_vars)
	@echo " - version: $(VERSION)"
	@docker buildx build --platform linux/amd64 --file ubuntu-26.04.dockerfile -t $(TAG)-amd64 .

build-aarch64: ## Build image in aarch64 (arm64 in docker build platform)
	@$(call check_vars)
	@echo " - version: $(VERSION)"
	@docker buildx build --platform linux/arm64 --file ubuntu-26.04-aarch64.dockerfile -t $(TAG)-aarch64 .
