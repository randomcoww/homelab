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

Configurations for creating hypervisor images are generated on a local [Matchbox](https://github.com/coreos/matchbox/) instance. This will generate necessary TLS certs and start a local Matchbox instance using Podman:

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

Copy host certificate to known hosts

```bash
echo -n "@cert-authority * $(buildtool terraform output ssh-ca-authorized-key)" >> $HOME/.ssh/known_hosts
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

Each hypervisor runs a PXE boot environment on an internal network for provisioning VMs local to the host. VMs run Fedora CoreOS using [Ignition](https://coreos.com/ignition/docs/latest/) for boot time configuration.

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
kubectl apply -f https://raw.githubusercontent.com/kubernetes/website/master/content/en/examples/policy/privileged-psp.yaml
kubectl apply -f http://127.0.0.1:8080/generic?manifest=bootstrap
kubectl apply -f http://127.0.0.1:8080/generic?manifest=kube-proxy
kubectl apply -f http://127.0.0.1:8080/generic?manifest=flannel
kubectl apply -f http://127.0.0.1:8080/generic?manifest=kapprover
kubectl apply -f http://127.0.0.1:8080/generic?manifest=coredns
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml
kubectl apply -f http://127.0.0.1:8080/generic?manifest=metallb
kubectl apply -f http://127.0.0.1:8080/generic?secret=internal-tls
kubectl apply -f http://127.0.0.1:8080/generic?secret=minio-auth
kubectl apply -f http://127.0.0.1:8080/generic?secret=grafana-auth
```

### Deploy services on Kubernetes

Deploy [OpenEBS](https://www.openebs.io/):

Only Jiva is used (I don't have enough disks to dedicate to cStor). This is the same as https://openebs.github.io/charts/openebs-operator-1.6.0.yaml with some unused components removed.

```
cd reqourcesv2/manifests
kubectl apply -f openebs-operator.yaml
```

Deploy [Traefik](https://traefik.io/) ingress:

https://traefik-ui.fuzzybunny.internal

```
cd reqourcesv2/manifests
kubectl apply -f traefik.yaml
```

Deploy monitoring:

https://grafana.fuzzybunny.internal

```
cd reqourcesv2/manifests
kubectl apply -f http://127.0.0.1:8080/generic?manifest=loki
kubectl apply -f grafana/
```

Deploy [Minio](https://min.io/) storage controller:

https://minio.fuzzybunny.internal

```
cd reqourcesv2/manifests
kubectl apply -f minio.yaml
```

Deploy MPD:

https://stream.fuzzybunny.internal

```
cd reqourcesv2/manifests
kubectl apply -f mpd/
```

Deploy Transmission:

https://tr.fuzzybunny.internal

```
cd reqourcesv2/manifests
kubectl create secret generic wireguard-config --from-file=wireguard-secret
kubectl apply -f transmission/
```
