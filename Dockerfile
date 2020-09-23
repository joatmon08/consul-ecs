ARG ENVOY_VERSION

FROM envoyproxy/envoy-alpine:v${ENVOY_VERSION}

ARG CONSUL_VERSION
#ENV CONSUL_VERSION=${CONSUL_VERSION}
RUN apk add -u bash curl jq && \
    wget https://releases.hashicorp.com/consul/"${CONSUL_VERSION}"/consul_"${CONSUL_VERSION}"_linux_amd64.zip \
	-O /tmp/consul.zip && \
    unzip /tmp/consul.zip -d /tmp && \
    mv /tmp/consul /usr/local/bin/consul && \
    rm -f /tmp/consul.zip && \
    mkdir -p /consul/config && \
    mkdir -p /consul/data

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
