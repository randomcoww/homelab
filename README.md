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

Apply basic addons and generate manifest files

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

#### Traefik

```bash
kubectl apply -f manifests/traefik.yaml
```

#### Minio

```bash
kubectl label node worker-0.local minio-data=true
kubectl apply -f manifests/minio.yaml
```

#### Monitoring

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

Currently the PSP `requiredDropCapabilities` causes loki pod to crashloop

```bash
kubectl patch -n monitoring psp loki -p='{
  "spec": {
    "requiredDropCapabilities": [
      ""
    ]
  }
}'
```

#### OpenEBS

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

Currently additional PSP is needed for PVC pods to run

```bash
kubectl apply -n openebs -f manifests/openebs_psp.yaml
```

#### Common service

```bash
kubectl apply -f manifests/common.yaml
```

---

### Recovery

Terraform needs access to a state file on AWS S3 to run. If both gateways are down and resources need to be generated using terraform, WAN access can be enabled in the client as follows

```
nmcli c up wan
```