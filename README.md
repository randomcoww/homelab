## Terraform configs for provisioning homelab resources

Build container includes terraform with plugins:

```
buildtool() {
    set -x
    podman run -it --rm \
        -v $HOME/.aws:/root/.aws \
        -v $(pwd):/root/mnt \
        -w /root/mnt/resourcesv2 \
        --net=host \
        randomcoww/tf-env:latest "$@"
    rc=$?; set +x; return $rc
}
```

### Run local matchbox server

Configurations for creating hypervisor images are generated on a local Matchbox instance. This will generate necessary TLS certs and start a local Matchbox instance using Podman:

```bash
buildtool start-renderer
```

### Define secrets

```bash
cat > secrets.tfvars <<EOF
desktop_password = "$(echo 'password' | mkpasswd -m sha-512 -s)"
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

### Create hypervisor images

Hypervisor images are live USB disks created using [Fedora CoreOS assembler](https://github.com/coreos/coreos-assembler). Generate ignition configuration to local Matchbox server:

```bash
buildtool terraform apply \
    -var-file=secrets.tfvars \
    -target=module.ignition-local
```

#### KVM hosts

Run build from https://github.com/randomcoww/fedora-coreos-custom

VMs running on the host will boot off of the same kernel and initramfs as the hypervisor.

#### Desktop

Run build from https://github.com/randomcoww/fedora-silverblue-custom

### Setup SSH access from desktop

```bash
KEY=$HOME/.ssh/id_ecdsa
ssh-keygen -q -t ecdsa -N '' -f $KEY 2>/dev/null <<< y >/dev/null

buildtool terraform apply \
    -auto-approve \
    -target=null_resource.output-triggers \
    -var="ssh_client_public_key=$(cat $KEY.pub)"

buildtool terraform output ssh-client-certificate > $KEY-cert.pub
```

### Generate configuration on hypervisor hosts

Each hypervisor runs a PXE boot environment on an internal network for provisioning VMs local to the host. VMs run Fedora CoreOS using Ignition for boot time configuration.

Ignition configuration is generated on each hypervisor as follows:

```bash
buildtool terraform apply \
    -target=module.ignition-local \
    -target=module.ignition-kvm-0 \
    -target=module.ignition-kvm-1 \
    -target=module.ignition-desktop
```

Define libvirt domains on each hypervisor:

```bash
buildtool tf-wrapper apply \
    -target=module.libvirt-kvm-0 \
    -target=module.libvirt-kvm-1 \
    -target=module.libvirt-desktop
```

### Start VMs

```bash
virsh -c qemu+ssh://core@kvm-0.local/system net-start sriov
virsh -c qemu+ssh://core@kvm-0.local/system start gateway-0
virsh -c qemu+ssh://core@kvm-0.local/system start controller-0
virsh -c qemu+ssh://core@kvm-0.local/system start worker-0

virsh -c qemu+ssh://core@kvm-1.local/system net-start sriov
virsh -c qemu+ssh://core@kvm-1.local/system start gateway-1
virsh -c qemu+ssh://core@kvm-1.local/system start controller-1
virsh -c qemu+ssh://core@kvm-1.local/system start worker-1

virsh -c qemu+ssh://core@desktop.local/system net-start sriov
virsh -c qemu+ssh://core@desktop.local/system start controller-2
virsh -c qemu+ssh://core@desktop.local/system start worker-2
virsh -c qemu+ssh://core@desktop.local/system start test-0
```

### Deploy kubernetes services

```bash
buildtool terraform apply \
    -var-file=secrets.tfvars \
    -target=module.generic-manifest-local
```

Write kubeconfig file:

```bash
buildtool terraform apply \
    -target=null_resource.output-triggers

mkdir -p ~/.kube
buildtool terraform output kubeconfig > ~/.kube/config
```

#### Basic addons

```bash
kubectl apply -f http://127.0.0.1:8080/generic?manifest=bootstrap
kubectl apply -f http://127.0.0.1:8080/generic?manifest=kube-proxy
kubectl apply -f http://127.0.0.1:8080/generic?manifest=flannel
kubectl apply -f http://127.0.0.1:8080/generic?manifest=kapprover
kubectl apply -f http://127.0.0.1:8080/generic?manifest=coredns
```

#### MetalLb

https://metallb.universe.tf/installation/#installation-by-manifest

```
kubectl apply -f http://127.0.0.1:8080/generic?manifest=metallb-network
```

#### Traefik

```
kubectl apply -f manifests/traefik.yaml
```

#### Monitoring

```
helm repo add loki https://grafana.github.io/loki/charts
helm repo add stable https://kubernetes-charts.storage.googleapis.com

kubectl create namespace monitoring

helm template loki \
    --namespace=monitoring \
    loki/loki | kubectl -n monitoring apply -f -

helm template promtail \
    --namespace monitoring \
    loki/promtail | kubectl -n monitoring apply -f -

helm template prometheus \
    --namespace monitoring \
    --set alertmanager.enabled=false \
    --set configmapReload.prometheus.enabled=false \
    --set configmapReload.alertmanager.enabled=false \
    --set initChownData.enabled=false \
    --set podSecurityPolicy.enabled=true \
    --set kube-state-metrics.podSecurityPolicy.enabled=true \
    --set pushgateway.enabled=false \
    --set server.persistentVolume.enabled=false \
    stable/prometheus | kubectl -n monitoring apply -f -

kubectl apply -n monitoring -f manifests/grafana.yaml
```
Allow non cluster nodes to send logs to loki:

```
kubectl apply -f http://127.0.0.1:8080/generic?manifest=loki-lb-service
```

Currently the PSP `requiredDropCapabilities` causes loki pod to crashloop:
```
kubectl patch -n monitoring psp loki -p='{
  "spec": {
    "requiredDropCapabilities": [
      ""
    ]
  }
}'
```

#### OpenEBS

```
helm repo add openebs https://openebs.github.io/charts

kubectl create namespace openebs

helm template openebs \
    --namespace openebs \
    --set rbac.pspEnabled=true \
    --set ndm.enabled=true \
    --set ndmOperator.enabled=true \
    --set localprovisioner.enabled=false \
    --set analytics.enabled=false \
    --set defaultStorageConfig.enabled=false \
    --set snapshotOperator.enabled=false \
    openebs/openebs | kubectl -n openebs apply -f -
```

Add block devices (IDs specific to my hardware)
```
kubectl apply -n openebs -f manifests/openebs_spc.yaml
```

Currently additional PSP is needed for PVC pods to run:
```
kubectl apply -n openebs -f manifests/openebs_psp.yaml
```

#### Minio

```
kubectl apply -f manifests/minio.yaml
```

#### Apply secrets

```bash
kubectl create namespace common

buildtool terraform apply \
    -var-file=secrets.tfvars \
    -target=module.kubernetes-addons
```
