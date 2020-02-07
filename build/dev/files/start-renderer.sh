#!/usr/bin/env bash
set -xe

terraform init
terraform apply -auto-approve \
    -target=local_file.matchbox-ca-pem \
    -target=local_file.matchbox-private-key-pem \
    -target=local_file.matchbox-cert-pem

mkdir -p data assets

matchbox \
    -data-path data \
    -assets-path assets \
    -ca-file output/local-renderer/ca.crt \
    -cert-file output/local-renderer/server.crt \
    -key-file output/local-renderer/server.key \
    -address 0.0.0.0:8080 \
    -rpc-address 0.0.0.0:8081