#!/usr/bin/env bash
set -xe

KNOWN_HOSTS=$HOME/.ssh/known_hosts
KEY=$HOME/.ssh/id_ecdsa
ssh-keygen -q -t ecdsa -N '' -f $KEY 2>/dev/null <<< y >/dev/null

terraform init
terraform apply \
  -auto-approve \
  -target=module.ssh_common \
  -var="ssh_client_public_key=$(cat $KEY.pub)"

terraform output ssh-client-certificate > $KEY-cert.pub
echo -n "@cert-authority * $(terraform output ssh-ca-authorized-key)" > $KNOWN_HOSTS

terraform $@
