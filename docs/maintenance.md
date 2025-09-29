### Generate local credentials

Write credentials for management access from localhost.

```bash
terraform -chdir=client_credentials init -upgrade && \
terraform -chdir=client_credentials apply -auto-approve -var "ssh_client={key_id=\"$(whoami)\",public_key_openssh=\"ssh_client_public_key=$(cat $HOME/.ssh/id_ecdsa.pub)\"}"

SSH_KEY=$HOME/.ssh/id_ecdsa
terraform -chdir=client_credentials output -raw ssh_user_cert_authorized_key > $SSH_KEY-cert.pub

terraform -chdir=client_credentials output -raw kubeconfig > $HOME/.kube/config

mkdir -p $HOME/.mc/certs/CAs
terraform -chdir=client_credentials output -json mc_config > $HOME/.mc/config.json
terraform -chdir=client_credentials output -json minio_client | jq -r '.ca_cert_pem' > $HOME/.mc/certs/CAs/ca.crt
```

---

### Build OS images

See [fedora-coreos-config](https://github.com/randomcoww/fedora-coreos-config)

Run `live-image-build` workflow in the repo above. An updated image tag should be merged into this project once finished and the new tag is picked up by a Renovate run.

---

### Generate network boot configuration

Generate and push host ignition and iPXE scripts to Matchbox for network booting.

```bash
terraform -chdir=ignition init -upgrade && \
terraform -chdir=ignition apply -auto-approve && \
terraform -chdir=matchbox_client init -upgrade && \
terraform -chdir=matchbox_client apply
```

---

### Rollout host updates

Trigger rolling reboot of hosts coordinated by `kured`. Nodes occasionally fail to network boot falling back to booting from backup USB disk. `kured` will also attempt to restart nodes in this state.

```bash
terraform -chdir=rolling_reboot init -upgrade && \
terraform -chdir=rolling_reboot apply
```

---

### Deploy services to Kubernetes

Deploy Kubernetes services. Some services rely on MinIO and will crash loop until MinIO resources are created (below).

```bash
terraform -chdir=kubernetes_service init -upgrade && \
terraform -chdir=kubernetes_service apply -var-file=../secrets.tfvars
```

Create MinIO resources and secrets containing access credentials in Kubernetes. MinIO must be running in Kubernetes for this to work.

```bash
terraform -chdir=minio_resources init -upgrade && \
terraform -chdir=minio_resources apply
```