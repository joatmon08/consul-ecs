.PHONY: build build_and_push
DOCKER_REPOSITORY=joatmon08/consul-ecs
CONSUL_VERSION=1.8.4
ENVOY_VERSION=1.14.4

build:
	docker build --build-arg CONSUL_VERSION=${CONSUL_VERSION} --build-arg ENVOY_VERSION=${ENVOY_VERSION} -t "${DOCKER_REPOSITORY}:v${CONSUL_VERSION}-v${ENVOY_VERSION}" .

build_and_push: build
	docker push "${DOCKER_REPOSITORY}:v${CONSUL_VERSION}-v${ENVOY_VERSION}"
