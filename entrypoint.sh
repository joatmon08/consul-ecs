#!/bin/bash

if [ ! -z "$CONSUL_CERTIFICATE" ]; then
  if [ ! -z "$CONSUL_CA_FILE_PATH" ]; then
    echo "Saving consul certificate..."
    echo $CONSUL_CERTIFICATE | base64 -d > ${CONSUL_CA_FILE_PATH}
  fi
fi

if [ ! -z "$CONSUL_CLIENT_CONFIG" ]; then
  EC2_HOST_ADDRESS=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
  EC2_NODE_NAME=$(curl -s http://169.254.169.254/latest/meta-data/local-hostname  | cut -f1 -d.)
  echo "Using EC2 host address ${EC2_HOST_ADDRESS}..."
  echo "Using EC2 node name ${EC2_NODE_NAME}..."
  echo $CONSUL_CLIENT_CONFIG | base64 -d | jq '.auto_encrypt.ip_san = ['\"$EC2_HOST_ADDRESS\"'] | .advertise_addr = '\"$EC2_HOST_ADDRESS\"'' > /consul/config/client.json
fi

# If we do not need to register a service just run the command
if [ ! -z "$SERVICE_CONFIG" ]; then
  if [ -z "$CONSUL_CACERT" ]; then
    echo "Specify CONSUL_CACERT for certificate file..."
    exit 1
  fi
  
  export CONSUL_HTTP_SSL=true
  export CONSUL_HTTP_ADDR=https://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):8501
  export CONSUL_GRPC_ADDR=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):8502

  echo ${CONSUL_SERVICE_CONFIG} | base64 -d > ${SERVICE_CONFIG}
  # Wait until Consul can be contacted
  until curl -s -k ${CONSUL_HTTP_ADDR}/v1/status/leader | grep 8300; do
    echo "Waiting for Consul to start at ${CONSUL_HTTP_ADDR}..."
    sleep 1
  done

  echo "Retrieve server certificate..."
  curl -s -k ${CONSUL_HTTP_ADDR}/v1/connect/ca/roots | \
  jq -r '.ActiveRootID as $activeRoot | .Roots | map(select(.ID == $activeRoot)) | .[0].RootCert' | \
  sed '/^[[:space:]]*$/d' > ${CONSUL_CACERT}

  # register the service with consul
  echo "Registering service with consul $SERVICE_CONFIG"
  consul services register ${SERVICE_CONFIG}
  
  exit_status=$?
  if [ $exit_status -ne 0 ]; then
    echo "### Error writing service config: $file ###"
    cat $file
    echo ""
    exit 1
  fi
  
  # make sure the service deregisters when exit
  trap "consul services deregister ${SERVICE_CONFIG}" SIGINT SIGTERM EXIT
fi

# Run the command if specified
if [ "$#" -ne 0 ]; then
  echo "Running command: $@"
  exec "$@" &

  # Block using tail so the trap will fire
  tail -f /dev/null &
  PID=$!
  wait $PID
fi
