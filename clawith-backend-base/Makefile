REPO  := ayakurayuki/clawith-backend-base
TAG   := python-3.12-slim
IMAGE := $(REPO):$(TAG)

.PHONY: build
build:
	@docker buildx build --platform linux/amd64 -t $(IMAGE) .

.PHONY: check
check:
	@echo "image: $(IMAGE)"
