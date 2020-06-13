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

or

```
buildtool() {
    set -x
    podman run -it --rm \
        -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
        -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
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

### Setup SSH access

Sign client SSH key

```bash
KEY=$HOME/.ssh/id_ecdsa
ssh-keygen -q -t ecdsa -N '' -f $KEY 2>/dev/null <<< y >/dev/null

buildtool terraform apply \
    -auto-approve \
    -target=null_resource.output-triggers \
    -var="ssh_client_public_key=$(cat $KEY.pub)"

buildtool terraform output ssh-client-certificate > $KEY-cert.pub
```

### Create hypervisor images

Hypervisor images are live USB disks created using [Fedora CoreOS assembler](https://github.com/coreos/coreos-assembler). Generate ignition configuration to local Matchbox server:

```bash
buildtool tf-wrapper apply \
    -target=module.ignition-local
```

#### KVM hosts

Run build from https://github.com/randomcoww/fedora-coreos-custom

VMs running on the host will boot off of the same kernel and initramfs as the hypervisor.

#### Desktop

Run build from https://github.com/randomcoww/fedora-silverblue-custom

### Generate configuration on hypervisor hosts

Each hypervisor runs a PXE boot environment on an internal network for provisioning VMs local to the host. VMs run Fedora CoreOS using Ignition for boot time configuration.

Ignition configuration is generated on each hypervisor as follows:

```bash
buildtool tf-wrapper apply \
    -target=module.ignition-local \
    -target=module.ignition-kvm-0 \
    -target=module.ignition-kvm-1
```

Define VMs on each hypervisor:

```bash
buildtool tf-wrapper apply \
    -target=module.libvirt-kvm-0 \
    -target=module.libvirt-kvm-1
```

### Start gateway VMs

This will provide a basic infrastructure including NAT routing, DHCP and basic DNS.

```bash
virsh -c qemu+ssh://core@kvm-0.local/system start gateway-0
virsh -c qemu+ssh://core@kvm-1.local/system start gateway-1
```

### Start Kubernetes cluster VMs

Etcd data is restored from S3 on fresh start of a cluster if there is an existing backup. A backup is made every 30 minutes. Local data is discarded when the etcd container stops.

```bash
virsh -c qemu+ssh://core@kvm-0.local/system start controller-0
virsh -c qemu+ssh://core@kvm-1.local/system start controller-1
virsh -c qemu+ssh://core@kvm-0.local/system start controller-2

virsh -c qemu+ssh://core@kvm-0.local/system start worker-0
virsh -c qemu+ssh://core@kvm-1.local/system start worker-1
```

Write kubeconfig file:

```bash
buildtool tf-wrapper apply \
    -target=local_file.kubeconfig-admin

export KUBECONFIG=$(pwd)/output/default-cluster-012.kubeconfig
```

### Generate basic Kubernetes addons

```bash
buildtool tf-wrapper apply \
    -target=module.kubernetes-addons
```

Apply addons:

```bash
kubectl apply -f http://127.0.0.1:8080/generic?manifest=bootstrap
kubectl apply -f http://127.0.0.1:8080/generic?manifest=kube-proxy
kubectl apply -f http://127.0.0.1:8080/generic?manifest=flannel
kubectl apply -f http://127.0.0.1:8080/generic?manifest=kapprover
kubectl apply -f http://127.0.0.1:8080/generic?manifest=coredns
kubectl apply -f http://127.0.0.1:8080/generic?manifest=metallb-network
kubectl apply -f http://127.0.0.1:8080/generic?manifest=loki-lb-service

kubectl apply -f http://127.0.0.1:8080/generic?manifest=traefik-tls-ingress
kubectl apply -f http://127.0.0.1:8080/generic?manifest=minio-tls-ingress
kubectl apply -f http://127.0.0.1:8080/generic?manifest=common-tls-ingress
kubectl apply -f http://127.0.0.1:8080/generic?manifest=monitoring-tls-ingress

kubectl apply -f http://127.0.0.1:8080/generic?manifest=minio-minio-auth
kubectl apply -f http://127.0.0.1:8080/generic?manifest=common-minio-auth
kubectl apply -f http://127.0.0.1:8080/generic?manifest=monitoring-grafana-auth
kubectl apply -f http://127.0.0.1:8080/generic?manifest=common-wireguard-client
```

### Deploy services on Kubernetes

#### MetalLb

https://metallb.universe.tf/installation/#installation-by-manifest


#### Traefik

```
kubectl apply -f manifests/traefik.yaml
```

#### Monitoring

```
helm repo add loki https://grafana.github.io/loki/charts
helm repo add stable https://kubernetes-charts.storage.googleapis.com

helm template loki \
    --namespace=monitoring \
    loki/loki

helm template promtail \
    --namespace monitoring \
    loki/promtail

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
    stable/prometheus

helm template loki-grafana \
    --namespace=monitoring \
    --set persistence.enabled=false \
    --set initChownData.enabled=false \
    --set testFramework.enabled=false \
    stable/grafana

kubectl apply -f manifests/grafana.yaml
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
helm repo add stable https://kubernetes-charts.storage.googleapis.com

OPENEBS_VERSION=1.9.0

helm template openebs \
    --namespace openebs \
    --set rbac.pspEnabled=true \
    --set ndm.enabled=true \
    --set ndmOperator.enabled=true \
    --set localprovisioner.enabled=false \
    --set analytics.enabled=false \
    --set defaultStorageConfig.enabled=false \
    --set snapshotOperator.enabled=false \
    --set webhook.imageTag=$OPENEBS_VERSION \
    --set ndm.filters.includePaths=/dev/vd \
    stable/openebs
```

Currently additional PSP is needed for Jiva PVC pods to run:
```
kubectl apply -f manifests/openebs_psp.yaml
```

#### Minio

```
kubectl apply -f manifests/minio.yaml
```
