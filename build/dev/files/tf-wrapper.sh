#!/usr/bin/env bash
set -xe

terraform init
terraform apply -target=local_file.ssh-ca-key

KEY=$HOME/.ssh/id_ecdsa
ssh-keygen -q -t ecdsa -N '' -f $KEY 2>/dev/null <<< y >/dev/null

CA=$(pwd)/output/ssh-ca-key.pem
chmod 400 $CA
ssh-keygen -s $CA -I $(whoami) -n core -V +1h -z 1 $KEY.pub

terraform $@