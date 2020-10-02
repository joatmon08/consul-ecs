#!/bin/bash

check_required_environment_variables()
{
  if [ -z "$CONSUL_HTTP_TOKEN" ]; then
    echo "set CONSUL_HTTP_TOKEN."
    exit 1
  fi

  if [ -z "$CONSUL_CACERT" ]; then
    echo "CONSUL_CACERT will default to /consul/tls.crt."
    export CONSUL_CACERT=/consul/tls.crt
  fi

  if [ -z "$CONSUL_HTTP_ADDR" ]; then
    echo "CONSUL_HTTP_ADDR will default to EC2 Host IP."
    export CONSUL_HTTP_SSL=true
    export CONSUL_HTTP_ADDR=https://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):8501
    export CONSUL_GRPC_ADDR=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):8502
  fi
}

get_server_certificate()
{
  echo "Retrieving server certificate and writing it to ${CONSUL_CACERT}."
  curl -s -k -H "X-Consul-Token:${CONSUL_HTTP_TOKEN}" ${CONSUL_HTTP_ADDR}/v1/connect/ca/roots | \
  jq -r '.ActiveRootID as $activeRoot | .Roots | map(select(.ID == $activeRoot)) | .[0].RootCert' | \
  sed '/^[[:space:]]*$/d' > ${CONSUL_CACERT}
}

set_client_configuration()
{
  if [ -z "$CONSUL_CA_PEM" ]; then
    echo "set CONSUL_CA_PEM to base64 encoded contents of server ca.pem file."
    exit 1
  fi

  echo $CONSUL_CA_PEM | base64 -d > /consul/ca.pem

  echo "Decoding ca.pem to /consul/ca.pem."
  echo $CONSUL_CA_PEM | base64 -d > /consul/ca.pem

  if [ -z "$CONSUL_DATACENTER" ]; then
    echo "CONSUL_DATACENTER will default to dc1."
    CONSUL_DATACENTER="dc1"
  fi
  if [ -z "$CONSUL_GOSSIP_ENCRYPT" ]; then
    echo "set CONSUL_GOSSIP_ENCRYPT to gossip encryption key."
    exit 1
  fi

  CLIENT_CONFIG_FILE="/consul/config/client.json"
  EC2_HOST_ADDRESS=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

  echo "Using EC2 host address ${EC2_HOST_ADDRESS}."

  jq '.acl.tokens.agent = "'${CONSUL_HTTP_TOKEN}'" | 
      .datacenter = "'${CONSUL_DATACENTER}'" | 
      .encrypt = "'${CONSUL_GOSSIP_ENCRYPT}'" | 
      .advertise_addr = "'${EC2_HOST_ADDRESS}'" | 
      .retry_join = ["'${CONSUL_HTTP_ADDR}'"] |
      .auto_encrypt.ip_san = ["'${EC2_HOST_ADDRESS}'"]' ./client_config.json > ${CLIENT_CONFIG_FILE}

  consul agent -config-dir=/consul/config
}

set_proxy_configuration()
{
  SERVICE_CONFIG_FILE="/consul/service.json"
  CONTAINER_IP=$(ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')

  if [ -z "$SERVICE_NAME" ]; then
    echo "set SERVICE_NAME to service name."
    exit 1
  fi

  if [ -z "$SERVICE_PORT" ]; then
    echo "set SERVICE_PORT to service port."
    exit 1
  fi

  if [ -z "$SERVICE_ID" ]; then
    echo "SERVICE_ID will default to ${SERVICE_NAME}."
    SERVICE_ID=${SERVICE_NAME}
  fi

  if [ -z "$CONSUL_SERVICE_UPSTREAMS" ]; then
    echo "CONSUL_SERVICE_UPSTREAMS will default to []."
    CONSUL_SERVICE_UPSTREAMS="[]"
  fi

  if [ -z "$SIDECAR_PORT" ]; then
    echo "SIDECAR_PORT will default to 21000."
    SIDECAR_PORT=21000
  fi

  if [ -z "$SERVICE_HEALTH_CHECK_PATH" ]; then
    echo "SERVICE_HEALTH_CHECK_PATH will default to /."
    SERVICE_HEALTH_CHECK_PATH=/
  fi

  if [ -z "$SERVICE_HEALTH_CHECK_INTERVAL" ]; then
    echo "SERVICE_HEALTH_CHECK_INTERVAL will default to 1s."
    SERVICE_HEALTH_CHECK_INTERVAL="1s"
  fi

  if [ -z "$SERVICE_HEALTH_CHECK_TIMEOUT" ]; then
    echo "SERVICE_HEALTH_CHECK_TIMEOUT will default to 1s."
    SERVICE_HEALTH_CHECK_TIMEOUT="1s"
  fi

  SERVICE_HEALTH_CHECK="http://${CONTAINER_IP}:${SERVICE_PORT}${SERVICE_HEALTH_CHECK_PATH}"
  SIDECAR_HEALTH_CHECK="${CONTAINER_IP}:${SIDECAR_PORT}"

  jq '.service.connect.sidecar_service.proxy.upstreams = '${CONSUL_SERVICE_UPSTREAMS}' | 
      .service.name = "'${SERVICE_NAME}'" | 
      .service.id = "'${SERVICE_ID}'" | 
      .service.token = "'${CONSUL_HTTP_TOKEN}'" | 
      .service.address = "'${CONTAINER_IP}'" | 
      .service.port = '${SERVICE_PORT}' | 
      .service.connect.sidecar_service.port = '${SIDECAR_PORT}' | 
      .service.check.http = "'${SERVICE_HEALTH_CHECK}'" | 
      .service.check.interval = "'${SERVICE_HEALTH_CHECK_INTERVAL}'" | 
      .service.check.timeout = "'${SERVICE_HEALTH_CHECK_TIMEOUT}'" | 
      .service.connect.sidecar_service.check.tcp = "'${SIDECAR_HEALTH_CHECK}'"' ./service_config.json > ${SERVICE_CONFIG_FILE}
  
  # Wait until Consul can be contacted
  until curl -s -k ${CONSUL_HTTP_ADDR}/v1/status/leader | grep 8300; do
    echo "Waiting for Consul to start at ${CONSUL_HTTP_ADDR}."
    sleep 1
  done

  echo "Registering service with consul ${SERVICE_CONFIG_FILE}."
  consul services register ${SERVICE_CONFIG_FILE}
  
  exit_status=$?
  if [ $exit_status -ne 0 ]; then
    echo "### Error writing service config: ${SERVICE_CONFIG_FILE} ###"
    cat $SERVICE_CONFIG_FILE
    echo ""
    exit 1
  fi

  consul connect envoy -sidecar-for=${SERVICE_ID} &
  
  # Block using tail so the trap will fire
  tail -f /dev/null &
  PID=$!
  wait $PID

  trap "consul services deregister ${SERVICE_CONFIG_FILE}" SIGINT SIGTERM EXIT
}

check_required_environment_variables

get_server_certificate

if [ ! -z "$CONSUL_CLIENT" ]; then
  echo "Starting Consul client."
  set_client_configuration
fi

if [ ! -z "$CONSUL_PROXY" ]; then
  echo "Starting Consul proxy."
  set_proxy_configuration
fi