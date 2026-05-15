REPO    := ayakurayuki
IMAGE   := ayubuntu
VERSION ?= ""
TAG     := $(REPO)/$(IMAGE):$(VERSION)

.DEFAULT_GOAL := help
help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo
	@echo 'To build images, choose one of the VERSION:'
	@echo '  - 24.04'
	@echo '  - 26.04'
	@echo
	@echo 'Example:'
	@echo '  - VERSION=26.04 make build'
	@echo '  - VERSION=26.04 make build-aarch64'

define check_vars
	@ if [ "$(VERSION)" = "" ]; then \
		echo "Error: Env variable VERSION not set"; \
		echo ""; \
		exit 1; \
	fi
endef

define check_modern_versions
	@ if [ "$(VERSION)" != "24.04" ] && [ "$(VERSION)" != "26.04" ]; then \
		echo "Error: Unsupported version $(VERSION)."; \
		echo "  '$(1)' accepts: 26.04, 24.04"; \
		echo ""; \
		echo "  For $(VERSION), use:"; \
		echo "    make build-classic"; \
		echo "    make build-classic-aarch64"; \
		echo ""; \
		exit 1; \
	fi
endef

.PHONY: help build build-aarch64

build: ## Build image in amd64
	@$(call check_vars)
	@$(call check_modern_versions,make build)
	@echo " - version: $(VERSION)"
	@docker buildx build --platform linux/amd64 \
		--build-arg UBUNTU_VERSION=$(VERSION) \
		--build-arg TARGET_ARCH=amd64 \
		--file ./docker/ubuntu.dockerfile \
		-t $(TAG)-amd64 ./docker

build-aarch64: ## Build image in aarch64
	@$(call check_vars)
	@$(call check_modern_versions,make build-aarch64)
	@echo " - version: $(VERSION)"
	@docker buildx build --platform linux/arm64 \
		--build-arg UBUNTU_VERSION=$(VERSION) \
		--build-arg TARGET_ARCH=aarch64 \
		--file ./docker/ubuntu.dockerfile \
		-t $(TAG)-aarch64 ./docker

build-classic:
	@$(call check_vars)
	@echo " - version: $(VERSION)"
	@docker buildx build --platform linux/amd64 \
		--build-arg UBUNTU_VERSION=$(VERSION) \
		--build-arg TARGET_ARCH=amd64 \
		--build-arg DISABLE_DEB822=1 \
		--file ./docker/ubuntu.dockerfile \
		-t $(TAG)-classic-amd64 ./docker

build-classic-aarch64:
	@$(call check_vars)
	@echo " - version: $(VERSION)"
	@docker buildx build --platform linux/arm64 \
		--build-arg UBUNTU_VERSION=$(VERSION) \
		--build-arg TARGET_ARCH=aarch64 \
		--build-arg DISABLE_DEB822=1 \
		--file ./docker/ubuntu.dockerfile \
		-t $(TAG)-classic-aarch64 ./docker
