
## Inject the app version into operator.Version
#LDFLAGS ?= -ldflags=-X=sigs.k8s.io/karpenter/pkg/operator.Version=$(shell git describe --tags --always | cut -d"v" -f2)

#GOFLAGS ?= $(LDFLAGS)
#WITH_GOFLAGS = GOFLAGS="$(GOFLAGS)"

#KO_DOCKER_REPO ?= ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${AWS_ECR_NAME}

KOCACHE ?= /tmp/.ko
IMAGE_URL="980921728818.dkr.ecr.us-east-1.amazonaws.com/app/filebeat-oss-http"
IMAGE_TAG="v7.17.29"
BUILD_PATH="./"
# Common Directories
MOD_DIRS = $(shell find . -path "./website" -prune -o -name go.mod -type f -print | xargs dirname)

# TEST_SUITE enables you to select a specific test suite directory to run "make e2etests" against
TEST_SUITE ?= "..."

help: ## Display help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

presubmit: verify test ## Run all steps in the developer loop

ci-test: test coverage ## Runs tests and submits coverage

ci-non-test: verify licenses vulncheck ## Runs checks other than tests


test: ## Run tests
	go test ./pkg/... \
		-cover -coverprofile=coverage.out -outputdir=. -coverpkg=./... \
		--ginkgo.focus="${FOCUS}" \
		--ginkgo.randomize-all \
		--ginkgo.vv

benchmark:
	go test -tags=test_performance -run=NoTests -bench=. ./...

coverage:
	go tool cover -html coverage.out -o coverage.html

verify: tidy download ## Verify code. Includes dependencies, linting, formatting, etc
	$(foreach dir,$(MOD_DIRS),cd $(dir) && golangci-lint run $(newline))


vulncheck: ## Verify code vulnerabilities
	@govulncheck ./pkg/...

licenses: download ## Verifies dependency licenses
	# TODO: remove nodeadm check once license is updated
	! go-licenses csv ./... | grep -v -e 'MIT' -e 'Apache-2.0' -e 'BSD-3-Clause' -e 'BSD-2-Clause' -e 'ISC' -e 'MPL-2.0' -e 'github.com/awslabs/amazon-eks-ami/nodeadm'
#aws ecr get-login-password | docker login --username AWS --password-stdin 980921728818.dkr.ecr.us-east-1.amazonaws.com
image: ## Build the Karpenter controller images using ko build
	KOCACHE=$(KOCACHE) KO_DOCKER_REPO="$(IMAGE_URL)" ko build --bare --tags=$(IMAGE_TAG) $(BUILD_PATH)
#	$(eval CONTROLLER_IMG=$(shell KOCACHE=$(KOCACHE) KO_DOCKER_REPO="$(IMAGE_URL)" ko build --bare --tags=$(IMAGE_TAG) $(BUILD_PATH)))
#	$(eval IMG_REPOSITORY=$(shell echo $(CONTROLLER_IMG) | cut -d "@" -f 1 | cut -d ":" -f 1))
#	$(eval IMG_TAG=$(shell echo $(CONTROLLER_IMG) | cut -d "@" -f 1 | cut -d ":" -f 2 -s))
#	$(eval IMG_DIGEST=$(shell echo $(CONTROLLER_IMG) | cut -d "@" -f 2))


tidy: ## Recursively "go mod tidy" on all directories where go.mod exists
	$(foreach dir,$(MOD_DIRS),cd $(dir) && go mod tidy $(newline))

download: ## Recursively "go mod download" on all directories where go.mod exists
	$(foreach dir,$(MOD_DIRS),cd $(dir) && go mod download $(newline))



.PHONY: help ci-test  image tidy

define newline


endef
