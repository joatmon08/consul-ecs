# Docker Image for Running Consul on ECS

This container image contains a number of automated steps
to run on Amazon ECS.

It can run as a Consul client or proxy.

## Required Environment Variables

    - CONSUL_HTTP_TOKEN.
    - CONSUL_CA_PEM to base64 encoded contents of server ca.pem file. (client mode)
    - CONSUL_GOSSIP_ENCRYPT to gossip encryption key. (client mode)
    - SERVICE_NAME to service name. (proxy mode)
    - SERVICE_PORT to service port. (proxy mode)

## Optional Environment Variables

    - CONSUL_CACERT will default to /consul/tls.crt.
    - CONSUL_HTTP_ADDR will default to EC2 Host IP.
    - CONSUL_DATACENTER will default to dc1.
    - SERVICE_ID will default to ${SERVICE_NAME}.
    - CONSUL_SERVICE_UPSTREAMS will default to [].
    - SIDECAR_PORT will default to 21000.
    - SERVICE_HEALTH_CHECK_PATH will default to /.
    - SERVICE_HEALTH_CHECK_INTERVAL will default to 1s.
    - SERVICE_HEALTH_CHECK_TIMEOUT will default to 1s.
