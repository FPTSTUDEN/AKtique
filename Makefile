SHELL := pwsh.exe

SKAFFOLD ?= skaffold
REGISTRY ?= ghcr.io/fptstuden
PROFILES ?= prod
BUILD_FILE ?= build.json

.PHONY: help build build-push deploy-cached run render dev dev-run dev-build

help:
	@Write-Output "Available targets:"
	@Write-Output "  make build         Build images with Skaffold cache enabled"
	@Write-Output "  make build-push    Build, push, and save image metadata to $(BUILD_FILE)"
	@Write-Output "  make deploy-cached Deploy using $(BUILD_FILE), without rebuilding images"
	@Write-Output "  make run           Build, push, and deploy in one command"
	@Write-Output "  make render        Render manifests using $(BUILD_FILE)"
	@Write-Output "  make dev           Start the local Skaffold development loop"
	@Write-Output "  make dev-run       Build locally, load images, and deploy once"
	@Write-Output "  make dev-build     Build locally without pushing to a registry"

build:
	$(SKAFFOLD) build --default-repo=$(REGISTRY) --cache-artifacts=true

build-push:
	$(SKAFFOLD) build --default-repo=$(REGISTRY) --push=true --cache-artifacts=true --file-output=$(BUILD_FILE)

deploy-cached:
	$(SKAFFOLD) deploy -p $(PROFILES) --default-repo=$(REGISTRY) --build-artifacts=$(BUILD_FILE)

run:
	$(SKAFFOLD) run -p $(PROFILES) --default-repo=$(REGISTRY) --push=true --cache-artifacts=true

render:
	$(SKAFFOLD) render -p $(PROFILES) --default-repo=$(REGISTRY) --build-artifacts=$(BUILD_FILE)

dev:
	$(SKAFFOLD) dev -p dev --cache-artifacts=true --port-forward=user

dev-run:
	$(SKAFFOLD) run -p dev --cache-artifacts=true --port-forward=user

dev-build:
	$(SKAFFOLD) build -p dev --cache-artifacts=true --push=false