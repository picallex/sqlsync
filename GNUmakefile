.PHONY: docker-format docker-shards-install docker-shards-build docker-test

IMAGE="sqlsync:latest"
GIT_VERSION := $(shell git log -1 --pretty=format:%h)

docker-shards-production: docker-build
	docker run --rm -ti -e VERSION=$(GIT_VERSION) -v "$(PWD):/app" -w /app $(IMAGE)  shards build -Dpreview_mt --production --static

docker-build:
	docker build -t $(IMAGE) .

docker-format: docker-build
	docker run --rm -ti -v "$(PWD):/app" -w /app $(IMAGE) crystal tool format src

docker-shards-install: docker-build
	docker run --rm -ti -v "$(PWD):/app" -w /app $(IMAGE) shards install

docker-test: docker-build
	docker run --rm -ti -v "$(PWD):/app" -w /app $(IMAGE) crystal spec
