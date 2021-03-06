LICENSE_DIR=./licenses/
BUILD_DIR=./build/
DOCKER_DIR=./docker/
SHELL := /bin/bash

test: test-coverage test-race test-js
check: check-go check-swagger check-js

require-version:
	if [ -n ${VERSION} ] && [[ $$VERSION == "v"* ]]; then echo "The version may not start with v" && exit 1; fi
	if [ -z ${VERSION} ]; then echo "Need to set VERSION" && exit 1; fi;

test-race:
	go test -v -race ./...

test-coverage:
	go test -v -coverprofile=coverage.txt -covermode=atomic ./...

format:
	goimports -w $(shell find . -type f -name '*.go' -not -path "./vendor/*")

test-js:
	go build -ldflags="-s -w" -o removeme/gotify app.go
	(cd ui && CI=true GOTIFY_EXE=../removeme/gotify npm test)
	rm -rf removeme

check-go:
	go vet ./...
	gocyclo -over 10 $(shell find . -iname '*.go' -type f | grep -v /vendor/)
	golint -set_exit_status $(shell go list ./... | grep -v mock)
	goimports -l $(shell find . -type f -name '*.go' -not -path "./vendor/*")

check-js:
	(cd ui && npm run lint)
	(cd ui && npm run testformat)

download-tools:
	go get -u golang.org/x/lint/golint
	go get -u github.com/fzipp/gocyclo
	go get -u github.com/gobuffalo/packr/...
	go get -u github.com/go-swagger/go-swagger/cmd/swagger
	go get -u golang.org/x/tools/cmd/goimports

update-swagger:
	go mod vendor
	GO111MODULE=off swagger generate spec --scan-models -o docs/spec.json

check-swagger: update-swagger
## add the docs to git, this changes line endings in git, otherwise this does not work on windows
	git add docs
	if [ -n "$(shell git status --porcelain | grep docs)" ]; then \
        echo Swagger Spec is not up-to-date; \
        exit 1; \
    fi

extract-licenses:
	mkdir ${LICENSE_DIR} || true
	for LICENSE in $(shell find vendor/* -name LICENSE); do \
		DIR=`echo $$LICENSE | tr "/" _ | sed -e 's/vendor_//; s/_LICENSE//'` ; \
        cp $$LICENSE ${LICENSE_DIR}$$DIR ; \
    done

package-zip: extract-licenses
	for BUILD in $(shell find ${BUILD_DIR}*); do \
       zip -j $$BUILD.zip $$BUILD ./LICENSE; \
       zip -ur $$BUILD.zip ${LICENSE_DIR}; \
    done

build-docker: require-version
	cp ${BUILD_DIR}gotify-linux-amd64 ./docker/gotify-app
	(cd ${DOCKER_DIR} && docker build -t gotify/server:latest -t gotify/server:${VERSION} .)
	rm ${DOCKER_DIR}gotify-app
	cp ${BUILD_DIR}gotify-linux-arm-7 ./docker/gotify-app
	(cd ${DOCKER_DIR} && docker build -f Dockerfile.arm7 -t gotify/server-arm7:latest -t gotify/server-arm7:${VERSION} .)
	rm ${DOCKER_DIR}gotify-app

build-js:
	(cd ui && npm run build)

.PHONY: test-race test-coverage test check-go check-js verify-swagger check download-tools update-swagger package-zip build-docker build-js