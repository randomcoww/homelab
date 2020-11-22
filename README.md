## Terraform configs for provisioning homelab resources

### Provisioning

#### Setup buildtool command

```bash
buildtool() {
    set -x
    podman run -it --rm --security-opt label=disable \
        -v $HOME/.aws:/root/.aws \
        -v $(pwd):/root/mnt \
        -v /var/cache:/var/cache \
        -w /root/mnt/resources \
        --net=host \
        randomcoww/tf-env:latest "$@"
    rc=$?; set +x; return $rc
}
```

#### Define secrets

```bash
cat > secrets.tfvars <<EOF
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
buildtool terraform apply \
    -var-file=secrets.tfvars \
    -target=module.template-hypervisor \
    -target=local_file.ignition
```

**KVM hosts**

Run build from https://github.com/randomcoww/fedora-coreos-custom. Write generated ISO file to disk (USB flash drive is sufficient) and boot from it.

**Client hosts**

Run build from https://github.com/randomcoww/fedora-silverblue-custom. Write generated ISO file to disk (USB flash drive is sufficient) and boot from it.

#### Start VMs

```bash
buildtool terraform apply \
    -target=module.ignition-kvm-0 \
    -target=module.libvirt-kvm-0

buildtool terraform apply \
    -target=module.ignition-kvm-1 \
    -target=module.libvirt-kvm-1
```

#### Start kubernetes addons

Create namespaces

```bash
buildtool terraform apply \
    -var-file=secrets.tfvars \
    -target=module.kubernetes-namespaces
```

Create addons

```bash
buildtool terraform apply \
    -var-file=secrets.tfvars \
    -target=module.kubernetes-addons
```

---

### Remote access

**SSH**

Generate a new key as needed
```bash
KEY=$HOME/.ssh/id_ecdsa \
ssh-keygen -q -t ecdsa -N '' -f $KEY 2>/dev/null <<< y >/dev/null
```

Sign public key
```bash
KEY=$HOME/.ssh/id_ecdsa \
buildtool terraform apply \
    -auto-approve \
    -target=null_resource.output \
    -var="ssh_client_public_key=$(cat $KEY.pub)" && \
buildtool terraform output ssh-client-certificate > $KEY-cert.pub
```

Access Libvirt through SSH
```bash
virsh -c qemu+ssh://core@kvm-0.local/system
virsh -c qemu+ssh://core@kvm-1.local/system
```

**Kubeconfig**

```bash
buildtool terraform apply \
    -target=null_resource.output && \
mkdir -p ~/.kube && \
buildtool terraform output kubeconfig > ~/.kube/config
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

---

### Recovery

Terraform needs access to a state file on AWS S3 to run. If both gateways are down and resources need to be generated using terraform, WAN access can be enabled in the client as follows

```bash
nmcli c down lan
nmcli c up wan
```
