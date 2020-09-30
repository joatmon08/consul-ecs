# Docker Image for Running Consul on ECS

This container image contains a number of automated steps
to run on Amazon ECS.

To run clients, set environment variables `CONSUL_CERTIFICATE` and
`CONSUL_CLIENT_CONFIG`.

To run proxies, set environment variables `SERVICE_CONFIG`, `CONSUL_SERVER_ADDR`,
and `CONSUL_CACERT`.