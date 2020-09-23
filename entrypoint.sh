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
  echo $CONSUL_CLIENT_CONFIG | base64 -d | jq '.auto_encrypt.ip_san = ['\"$EC2_HOST_ADDRESS\"'] | .advertise_addr = '\"$EC2_HOST_ADDRESS\"' | .node_name = '\"$EC2_NODE_NAME\"'' > /consul/config/client.json
fi

# If we do not need to register a service just run the command
if [ ! -z "$SERVICE_CONFIG" ]; then
  # Wait until Consul can be contacted
  until curl -s -k ${CONSUL_HTTP_ADDR}/v1/status/leader | grep 8300; do
    echo "Waiting for Consul to start"
    sleep 1
  done

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

# register any central config from individual files
if [ ! -z "$CENTRAL_CONFIG" ]; then
  IFS=';' read -r -a configs <<< ${CENTRAL_CONFIG}

  for file in "${configs[@]}"; do
    echo "Writing central config $file"
    consul config write $file
     
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
      echo "### Error writing central config: $file ###"
      cat $file
      echo ""
      exit 1
    fi
  done
fi

# register any central config from a folder
if [ ! -z "$CENTRAL_CONFIG_DIR" ]; then
  for file in `ls -v $CENTRAL_CONFIG_DIR/*`; do 
    echo "Writing central config $file"
    consul config write $file
    echo ""

    exit_status=$?
    if [ $exit_status -ne 0 ]; then
      echo "### Error writing central config: $file ###"
      cat $file
      echo ""
      exit 1
    fi
  done
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
