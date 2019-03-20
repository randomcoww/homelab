#!/usr/bin/env bash

terraform apply -auto-approve \
    -target=module.renderer \
    -target=local_file.ca_pem \
    -target=local_file.matchbox_private_key_pem \
    -target=local_file.matchbox_cert_pem 

docker run -it --rm \
    --user $(id -u):$(id -g) \
    -v "$(pwd)"/output/renderer:/etc/matchbox \
    -v "$(pwd)"/output/renderer:/var/lib/matchbox \
    -p 8080:8080 \
    -p 8081:8081 \
    quay.io/coreos/matchbox:latest \
        -data-path /var/lib/matchbox \
        -assets-path /var/lib/matchbox \
        -address 0.0.0.0:8080 \
        -rpc-address 0.0.0.0:8081
