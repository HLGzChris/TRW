#!/bin/sh

# Trust custom certificates if present
if [ -d /opt/custom-certificates ]; then
  echo "Trusting custom certificates from /opt/custom-certificates."
  export NODE_OPTIONS="--use-openssl-ca $NODE_OPTIONS"
  export SSL_CERT_DIR=/opt/custom-certificates
  c_rehash /opt/custom-certificates
fi

# Start n8n with or without arguments
if [ "$#" -gt 0 ]; then
  exec n8n "$@"
else
  exec n8n
fi