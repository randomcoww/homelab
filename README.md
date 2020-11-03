## Terraform configs for provisioning homelab resources

### Setup

**Build container includes terraform with plugins:**

```bash
buildtool() {
    set -x
    podman run -it --rm --security-opt label=disable \
        -v $HOME/.aws:/root/.aws \
        -v $(pwd):/root/mnt \
        -v /var/cache:/var/cache \
        -w /root/mnt/resourcesv2 \
        --net=host \
        randomcoww/tf-env:latest "$@"
    rc=$?; set +x; return $rc
}
```

**Define secrets:**

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

### Create hypervisor images

Hypervisor images are live USB disks created using [Fedora CoreOS assembler](https://github.com/coreos/coreos-assembler)

```bash
buildtool terraform apply \
    -target=module.hypervisor
```

```bash
buildtool terraform apply \
    -var-file=secrets.tfvars \
    -target=local_file.ignition-local
```

**KVM hosts:**

Run build from https://github.com/randomcoww/fedora-coreos-custom

VMs running on the host will boot off of the same kernel and initramfs as the hypervisor.

**Client devices:**

Run build from https://github.com/randomcoww/fedora-silverblue-custom

### Start VMs

Each hypervisor runs a PXE boot environment on an internal network for provisioning VMs local to the host. VMs run Fedora CoreOS using Ignition for boot time configuration.

**Configure ignition and libvirt on each hypervisor:**

```bash
buildtool terraform apply \
    -target=module.ignition-kvm-0 \
    -target=module.libvirt-kvm-0

buildtool terraform apply \
    -target=module.ignition-kvm-1 \
    -target=module.libvirt-kvm-1
```

**Setup SSH access:**

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
    -target=null_resource.output-triggers \
    -var="ssh_client_public_key=$(cat $KEY.pub)" && \
buildtool terraform output ssh-client-certificate > $KEY-cert.pub
```

**Launch VMs:**

```bash
virsh -c qemu+ssh://core@kvm-0.local/system net-start pf0
virsh -c qemu+ssh://core@kvm-0.local/system start gateway-0
virsh -c qemu+ssh://core@kvm-0.local/system start controller-0
virsh -c qemu+ssh://core@kvm-1.local/system start controller-1
virsh -c qemu+ssh://core@kvm-0.local/system start worker-0

virsh -c qemu+ssh://core@kvm-1.local/system net-start pf0
virsh -c qemu+ssh://core@kvm-1.local/system start gateway-1
virsh -c qemu+ssh://core@kvm-1.local/system start controller-1
virsh -c qemu+ssh://core@kvm-1.local/system start controller-2
virsh -c qemu+ssh://core@kvm-1.local/system start worker-1
```

### Deploy kubernetes services

**Create namespaces**

```bash
buildtool terraform apply \
    -target=module.kubernetes-namespaces
```

**Apply basic addons and generate manifest files:**

```bash
buildtool terraform apply \
    -var-file=secrets.tfvars \
    -target=data.null_data_source.kubernetes-manifests \
    -target=module.kubernetes-addons \
    -target=local_file.kubernetes-addons
```

**Write kubeconfig file:**

```bash
buildtool terraform apply \
    -target=null_resource.output-triggers

mkdir -p ~/.kube
buildtool terraform output kubeconfig > ~/.kube/config
```

**MetalLb:**

```bash
kubectl apply -f resourcesv2/output/addons/metallb.yaml
kubectl apply -f resourcesv2/output/addons/metallb-network.yaml
```

Add `LoadBalancer` services for external-dns:

```bash
kubectl apply -f resourcesv2/output/addons/external-dns.yaml
```

**Traefik:**

```bash
kubectl apply -f manifests/traefik.yaml
```

**Minio:**

```bash
kubectl label node worker-0.local minio-data=true
kubectl apply -f manifests/minio.yaml
```

**Monitoring:**

```bash
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

**Allow non cluster nodes to send logs to loki:**

```bash
kubectl apply -f resourcesv2/output/addons/loki-lb-service.yaml
```

Currently the PSP `requiredDropCapabilities` causes loki pod to crashloop:
```bash
kubectl patch -n monitoring psp loki -p='{
  "spec": {
    "requiredDropCapabilities": [
      ""
    ]
  }
}'
```

**OpenEBS:**

```bash
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
    --set webhook.enabled=false \
    openebs/openebs | kubectl -n openebs apply -f -
```

Add block devices (IDs specific to my hardware)
```bash
kubectl apply -n openebs -f manifests/openebs_spc.yaml
```

Currently additional PSP is needed for PVC pods to run:
```bash
kubectl apply -n openebs -f manifests/openebs_psp.yaml
```

**Common service:**

```bash
kubectl apply -f manifests/common.yaml
```

### Recover from no gateways running

**Internet access is needed to fetch the terraform state file. From client:**

```
nmcli c up wan
```

**Start VMs as above. Switch to LAN:**

```
nmcli c down wan
nmcli c up lan
```
