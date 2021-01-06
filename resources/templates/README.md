## Terraform configs for provisioning homelab resources

### Provisioning

#### Setup tw (terraform wrapper) command

```bash
tw() {
    set -x
    podman run -it --rm --security-opt label=disable \
        -v $HOME/.aws:/root/.aws \
        -v $(pwd):/root/mnt \
        -v /var/cache:/var/cache \
        -w /root/mnt/resources \
        --net=host \
        ${container_images.tw} "$@"
    rc=$?; set +x; return $rc
}
```

#### Define secrets

```bash
cat > ${secrets_file} <<EOF
client_password = "$(echo 'password' | mkpasswd -m sha-512 -s)"
wireguard_config = {
  Interface = {
    PrivateKey =
    Address    =
    DNS        =
  }
  Peer = {
    PublicKey  =
    AllowedIPs =
    Endpoint   =
  }
}
EOF
```

#### Create bootable hypervisor and client images

Hypervisor images are live USB disks created using [Fedora CoreOS assembler](https://github.com/coreos/coreos-assembler)

```bash
tw terraform apply \
    -var-file=${secrets_file} \
    -target=module.template-hypervisor \
    -target=local_file.ignition
```

**Host images**

Run build from https://github.com/randomcoww/fedora-coreos-config-custom.git. Write generated ISO file to disk (USB flash drive is sufficient) and boot from it.

#### Start VMs

%{~ for k, v in hypervisor_hosts}
**${v.hostname} guests**

%{for d in v.libvirt_domains ~}
- ${d.host.hostname}
%{endfor ~}

```bash
tw terraform apply \
    -var-file=${secrets_file} \
    -target=module.ignition-${k} \
    -target=module.libvirt-${k}
```
%{endfor ~}

#### Start kubernetes addons

May need to force resource dependencies to generate

```bash
tw terraform apply \
    -var-file=${secrets_file} \
    -target=null_resource.kubernetes_resources
```

Create namespaces

```bash
tw terraform apply \
    -var-file=${secrets_file} \
    -target=module.kubernetes-namespaces
```

Create addons

```bash
tw terraform apply \
    -var-file=${secrets_file} \
    -target=module.kubernetes-addons
```

---

### Remote access

**SSH**

Generate a new key as needed
```bash
KEY=$HOME/.ssh/id_ecdsa
ssh-keygen -q -t ecdsa -N '' -f $KEY 2>/dev/null <<< y >/dev/null
```

Sign public key
```bash
KEY=$HOME/.ssh/id_ecdsa
tw terraform apply \
    -auto-approve \
    -var="ssh_client_public_key=$(cat $KEY.pub)" \
    -target=null_resource.output && \
tw terraform output ssh-client-certificate > $KEY-cert.pub
```

Access Libvirt through SSH
```bash
%{for v in values(hypervisor_hosts) ~}
virsh -c qemu+ssh://core@${v.hostname}/system
%{endfor ~}
```

**Kubeconfig**

```bash
tw terraform apply \
    -auto-approve \
    -target=null_resource.output && \
mkdir -p ~/.kube && \
tw terraform output kubeconfig > ~/.kube/config
```

---

### Cleanup and generate README

```bash
tw find ../ -name '*.tf' -exec terraform fmt '{}' \;

tw terraform apply \
    -auto-approve \
    -target=local_file.readme
```

---

### Start services

#### MetalLb

https://metallb.universe.tf/installation/#installation-by-manifest

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/manifests/metallb.yaml
```

#### Traefik

```bash
kubectl apply -f services/traefik.yaml
```

#### Minio

```bash
kubectl apply -f services/minio.yaml
```

#### Monitoring

```bash
helm repo add loki https://grafana.github.io/loki/charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm template loki \
    --namespace=monitoring \
    loki/loki | kubectl -n monitoring apply -f -

helm template promtail \
    --namespace monitoring \
    loki/promtail | kubectl -n monitoring apply -f -

helm template prometheus \
    --namespace monitoring \
    --set podSecurityPolicy.enabled=true \
    --set alertmanager.enabled=false \
    --set configmapReload.prometheus.enabled=false \
    --set configmapReload.alertmanager.enabled=false \
    --set kubeStateMetrics.enabled=true \
    --set nodeExporter.enabled=true \
    --set server.persistentVolume.enabled=false \
    --set pushgateway.enabled=false \
    prometheus-community/prometheus | kubectl -n monitoring apply -f -

kubectl apply -n monitoring -f services/grafana.yaml
```

#### Common services

```bash
kubectl apply -f services/common-psp.yaml
kubectl apply -f services/transmission
kubectl apply -f services/mpd
kubectl apply -f services/unifi
```