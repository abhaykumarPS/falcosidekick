# Ensure Make is run with bash shell as some syntax below is bash-specific
SHELL=/bin/bash -o pipefail

.DEFAULT_GOAL:=help

GOPATH  := $(shell go env GOPATH)
GOARCH  := $(shell go env GOARCH)
GOOS    := $(shell go env GOOS)
GOPROXY := $(shell go env GOPROXY)
ifeq ($(GOPROXY),)
GOPROXY := https://proxy.golang.org
endif
export GOPROXY
GO ?= go
DOCKER ?= docker
TEST_FLAGS ?= -v -race

# Directories.
ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
TOOLS_DIR := hack/tools
TOOLS_BIN_DIR := $(abspath $(TOOLS_DIR)/bin)
GO_INSTALL = ./hack/go_install.sh

# Binaries.
GOLANGCI_LINT_VER := v1.38.0
GOLANGCI_LINT_BIN := golangci-lint
GOLANGCI_LINT := $(TOOLS_BIN_DIR)/$(GOLANGCI_LINT_BIN)-$(GOLANGCI_LINT_VER)

## --------------------------------------
## Build
## --------------------------------------

.PHONY: falcosidekick
falcosidekick:
	$(GO) build -gcflags all=-trimpath=/src -asmflags all=-trimpath=/src -a -installsuffix cgo -o $@ .

.PHONY: build-image
build-image:
	$(DOCKER) buildx build --platform linux/arm64,linux/amd64 . -t falcosecurity/falcosidekick:latest --push .
	mkdir -vp ~/.docker/cli-plugins/
        curl --silent -L --output ~/.docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/v0.6.3/buildx-v0.6.3.linux-amd64
        chmod a+x ~/.docker/cli-plugins/docker-buildx
        docker login -u odidev -p 0af07c59-cc6d-407b-bba0-ac8f226b5c5e
        docker run -it --rm --privileged tonistiigi/binfmt --install all
    
## --------------------------------------
## Test
## --------------------------------------

.PHONY: test
test:
	$(GO) vet ./...
	$(GO) test ${TEST_FLAGS} ./...

.PHONY: test-coverage
test-coverage:
	$(GO) test ./outputs -count=1 -cover -v ./...

## --------------------------------------
## Linting
## --------------------------------------

.PHONY: lint
lint: $(GOLANGCI_LINT) ## Lint codebase
	$(GOLANGCI_LINT) run -v

lint-full: $(GOLANGCI_LINT) ## Run slower linters to detect possible issues
	$(GOLANGCI_LINT) run -v --fast=false

## --------------------------------------
## Tooling Binaries
## --------------------------------------

$(GOLANGCI_LINT): ## Build golangci-lint from tools folder.
	GOBIN=$(TOOLS_BIN_DIR) $(GO_INSTALL) github.com/golangci/golangci-lint/cmd/golangci-lint $(GOLANGCI_LINT_BIN) $(GOLANGCI_LINT_VER)

## --------------------------------------
## Cleanup / Verification
## --------------------------------------

.PHONY: clean
clean:
	rm -rf hack/tools/bin
