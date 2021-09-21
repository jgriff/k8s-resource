# ######################################################################################################################
# Globals
# ######################################################################################################################
SHELL = /bin/bash

COLOR_RED=\033[0;31m
COLOR_GREEN=\033[0;32m
COLOR_ORANGE=\033[0;33m
COLOR_BLUE=\033[0;34m
COLOR_PURPLE=\033[0;35m
COLOR_TEAL=\033[0;36m
COLOR_WHITE=\033[0;37m
COLOR_RESET=\033[0m

KUBECTL_1.18=1.18.19
KUBECTL_1.19=1.19.15
KUBECTL_1.20=1.20.11
KUBECTL_1.21=1.21.5
KUBECTL_1.22=1.22.2

KUBECTL_VERSION=${KUBECTL_1.20}

IMAGE=jgriff/k8s-resource
VERSION=dev

# ######################################################################################################################
# Primary goals
#
# build - Build all image variants.
# test - Run all tests against all image variants.
# release - Release all image variants.
#
# ######################################################################################################################

.DEFAULT_GOAL := build

# ---------------------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------------------
.PHONY: build build_1.18 build_1.19 build_1.20 build_1.21 build_1.22 build_latest
build: build_1.18 build_1.19 build_1.20 build_1.21 build_1.22 build_latest
build_1.18: KUBECTL_VERSION=${KUBECTL_1.18}
build_1.19: KUBECTL_VERSION=${KUBECTL_1.19}
build_1.20: KUBECTL_VERSION=${KUBECTL_1.20}
build_1.21: KUBECTL_VERSION=${KUBECTL_1.21}
build_1.22: KUBECTL_VERSION=${KUBECTL_1.22}
build_1.18 build_1.19 build_1.20 build_1.21 build_1.22: TAG=${VERSION}-kubectl-${KUBECTL_VERSION}
build_1.18 build_1.19 build_1.20 build_1.21 build_1.22:
	@echo -e "\n[${COLOR_BLUE}build${COLOR_RESET}/${COLOR_TEAL}${TAG}${COLOR_RESET}] ${COLOR_ORANGE}Building image${COLOR_RESET}..."
	@docker build --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} -t ${IMAGE}:${TAG} -t ${IMAGE}:$(shell echo ${TAG} | rev | cut -d '.' -f2- | rev ) .
build_latest:
	@echo -e "\n[${COLOR_BLUE}build${COLOR_RESET}/${COLOR_TEAL}latest${COLOR_RESET}] ${COLOR_ORANGE}Building image${COLOR_RESET}..."
	@docker build -t ${IMAGE} .


# ---------------------------------------------------------------------------------------
# test
# ---------------------------------------------------------------------------------------
.PHONY: test test_1.18 test_1.19 test_1.20 test_1.21 test_1.22 test_latest
test: test_1.18 test_1.19 test_1.20 test_1.21 test_1.22 test_latest
test_1.18: TAG=${VERSION}-kubectl-${KUBECTL_1.18}
test_1.19: TAG=${VERSION}-kubectl-${KUBECTL_1.19}
test_1.20: TAG=${VERSION}-kubectl-${KUBECTL_1.20}
test_1.21: TAG=${VERSION}-kubectl-${KUBECTL_1.21}
test_1.22: TAG=${VERSION}-kubectl-${KUBECTL_1.22}
test_latest: TAG=latest
test_1.18 test_1.19 test_1.20 test_1.21 test_1.22 test_latest:
	@echo -e "\n[${COLOR_BLUE}test${COLOR_RESET}/${COLOR_TEAL}${TAG}${COLOR_RESET}] ${COLOR_ORANGE}Testing image${COLOR_RESET}..."
	@./test/run.sh -i ${IMAGE}:${TAG} -v

# ---------------------------------------------------------------------------------------
# release
# ---------------------------------------------------------------------------------------
.PHONY: release release_1.18 release_1.19 release_1.20 release_1.21 release_1.22 release_latest
release: release_1.18 release_1.19 release_1.20 release_1.21 release_1.22 release_latest
release_1.18: TAG=${VERSION}-kubectl-${KUBECTL_1.18}
release_1.19: TAG=${VERSION}-kubectl-${KUBECTL_1.19}
release_1.20: TAG=${VERSION}-kubectl-${KUBECTL_1.20}
release_1.21: TAG=${VERSION}-kubectl-${KUBECTL_1.21}
release_1.22: TAG=${VERSION}-kubectl-${KUBECTL_1.22}
release_latest: TAG=latest
release_1.18 release_1.19 release_1.20 release_1.21 release_1.22 release_latest:
	@echo -e "\n[${COLOR_BLUE}release${COLOR_RESET}/${COLOR_TEAL}${TAG}${COLOR_RESET}] ${COLOR_ORANGE}Pushing image${COLOR_RESET}..."
	@docker push ${IMAGE}:${TAG}
	@docker push ${IMAGE}:$(shell echo ${TAG} | rev | cut -d '.' -f2- | rev )