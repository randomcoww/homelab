#!/usr/bin/env bash
set -e

terraform apply -auto-approve \
    -target=local_file.matchbox-ca-pem \
    -target=local_file.matchbox-private-key-pem \
    -target=local_file.matchbox-cert-pem

podman run -it --rm \
    --tmpfs=/data \
    -v "$(pwd)"/assets:/assets \
    -v "$(pwd)"/output/local-renderer:/etc/matchbox \
    -p 8080:8080 \
    -p 8081:8081 \
    quay.io/coreos/matchbox:latest \
        -data-path /data \
        -assets-path /assets \
        -address 0.0.0.0:8080 \
        -rpc-address 0.0.0.0:8081
