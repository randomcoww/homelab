### Generate local credentials

Write credentials for management access from localhost.

```bash
tofu -chdir=client_credentials init -upgrade && \
tofu -chdir=client_credentials apply -auto-approve -var "ssh_client={key_id=\"$(whoami)\",public_key_openssh=\"ssh_client_public_key=$(cat $HOME/.ssh/id_ecdsa.pub)\"}"

SSH_KEY=$HOME/.ssh/id_ecdsa
tofu -chdir=client_credentials output -raw ssh_user_cert_authorized_key > $SSH_KEY-cert.pub

tofu -chdir=client_credentials output -raw kubeconfig > $HOME/.kube/config

mkdir -p $HOME/.config/rclone
tofu -chdir=client_credentials output -raw rclone_config > $HOME/.config/rclone/rclone.conf

mkdir -p $HOME/.mc/certs/CAs
tofu -chdir=client_credentials output -json mc_config > $HOME/.mc/config.json
tofu -chdir=client_credentials output -json internal_ca | jq -r '.cert_pem' > $HOME/.mc/certs/CAs/ca.crt
```

---

### Generate host configuration

```bash
tofu -chdir=ignition init -upgrade && \
tofu -chdir=ignition apply
```

---

### Build OS images

See [fedora-coreos-config-custom](https://github.com/randomcoww/fedora-coreos-config-custom)

Run `live-image-build` workflow in the repo above. An updated image tag should be merged into this project once finished and the new tag is picked up by a Renovate run.

---

### Deploy services to Kubernetes

Deploy Kubernetes services. Some services rely on MinIO and will crash loop until MinIO resources are created (below).

```bash
tofu -chdir=kubernetes_service init -upgrade && \
tofu -chdir=kubernetes_service apply -var-file=../secrets.tfvars
```

Create MinIO resources and secrets containing access credentials in Kubernetes. MinIO must be running in Kubernetes for this to work.

```bash
tofu -chdir=minio_resources init -upgrade && \
tofu -chdir=minio_resources apply
```

---

#### Registry management

```bash
regctl registry set reg.cluster.internal --tls enabled --cacert "$(cat $HOME/.mc/certs/CAs/ca.crt)"

regctl repo ls reg.cluster.internal
regctl tag ls reg.cluster.internal/${REPO}
regctl tag delete reg.cluster.internal/${REPO}:${TAG}
```

---

### Services

Get LDAP admin password

```bash
tofu -chdir=kubernetes_service output -json lldap | jq
```

Get llama.cpp API key

```bash
tofu -chdir=kubernetes_service output -json llama-cpp | jq
```

---

### Roll out host updates

Trigger rolling reboot of hosts coordinated by `kured`. Nodes occasionally fail to network boot falling back to booting from backup USB disk. `kured` will also attempt to restart nodes in this state.

```bash
tofu -chdir=rolling_reboot init -upgrade && \
tofu -chdir=rolling_reboot apply
```