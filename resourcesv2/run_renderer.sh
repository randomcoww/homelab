#!/usr/bin/env bash

terraform apply -auto-approve \
    -target=local_file.matchbox-ca-pem \
    -target=local_file.matchbox-private-key-pem \
    -target=local_file.matchbox-cert-pem

podman run -it --rm \
    -v "$(pwd)"/output/local-renderer:/etc/matchbox \
    -v "$(pwd)"/output/local-renderer:/var/lib/matchbox \
    -p 8080:8080 \
    -p 8081:8081 \
    quay.io/coreos/matchbox:latest \
        -data-path /var/lib/matchbox \
        -assets-path /var/lib/matchbox \
        -address 0.0.0.0:8080 \
        -rpc-address 0.0.0.0:8081
