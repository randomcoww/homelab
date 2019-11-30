## Terraform configs for provisioning homelab resources

### Run local Matchbox

Configurations for creating hypervisor images are generated on a local [Matchbox](https://github.com/coreos/matchbox/) instance. This will generate necessary TLS certs and start a local Matchbox instance using Podman:

```bash
cd resourcesv2
./run_renderer.sh
```

### Create hypervisor images

Hypervisor images are live USB disks created using Kickstart and livemedia-creator. Generate Kickstart configuration to local Matchbox server:

```bash
cd resourcesv2
terraform apply -target=module.kickstart
```

Generate live USB images:

```bash
cd build
export FEDORA_RELEASE=31
export ISO_FILE=Fedora-Server-netinst-x86_64-31-1.9.iso

wget \
    https://download.fedoraproject.org/pub/fedora/linux/releases/$FEDORA_RELEASE/Server/x86_64/iso/$ISO_FILE

sudo livemedia-creator \
    --make-iso \
    --iso=$ISO_FILE \
    --project Fedora \
    --volid kvm \
    --releasever $FEDORA_RELEASE \
    --title kvm \
    --resultdir ./result \
    --tmp . \
    --ks=./kvm-0.ks \
    --no-virt \
    --lorax-templates ./lorax-kvm

sudo livemedia-creator \
    --make-iso \
    --iso=$ISO_FILE \
    --project Fedora \
    --volid kvm \
    --releasever $FEDORA_RELEASE \
    --title kvm \
    --resultdir ./result \
    --tmp . \
    --ks=./kvm-1.ks \
    --no-virt \
    --lorax-templates ./lorax-kvm
```

Also create an image for the desktop PC:

```
sudo livemedia-creator \
    --make-iso \
    --iso=$ISO_FILE \
    --project Fedora \
    --volid desktop \
    --releasever $FEDORA_RELEASE \
    --title desktop \
    --resultdir ./result \
    --tmp . \
    --ks=./desktop-0.ks \
    --no-virt \
    --lorax-templates ./lorax-desktop
```

### Generate Ignition configuration on hypervisor hosts

Each hypervisor runs a PXE boot environment on an internal network for provisioning VMs local to the host. VMs run [Container Linux](https://coreos.com/os/docs/latest/) using [Ignition](https://coreos.com/ignition/docs/latest/) for boot time configuration.

Ignition configuration is generated on each hypervisor as follows:

```bash
cd resourcesv2
terraform apply \
    -target=module.ignition-kvm-0 \
    -target=module.ignition-kvm-1
```

Write SSH CA private key to sign a key for accessing the hypervisor over `virsh` and `ssh`.

```bash
cd resourcesv2
terraform apply -target=local_file.ssh-ca-key
```

Sign an existing key

```
CA=$(pwd)/output/ssh-ca-key.pem
KEY=$HOME/.ssh/id_ecdsa.pub
USER=$(whoami)

chmod 400 $CA
ssh-keygen -s $CA -I $USER -n core -V +1w -z 1 $KEY
```

### Define VMs

```bash
cd resourcesv2
terraform apply \
    -target=module.libvirt-kvm-0 \
    -target=module.libvirt-kvm-1
```

### Start gateway VMs

This will provide a basic infrastructure including NAT routing, DHCP and DNS.

```bash
virsh -c qemu+ssh://core@192.168.127.251/system start gateway-0
virsh -c qemu+ssh://core@192.168.127.252/system start gateway-1
```

### Start Kubernetes cluster VMs

Etcd data is restored from S3 on fresh start of a cluster if there is an existing backup. A backup is made every 30 minutes. Local data is discarded when the etcd container stops.

```bash
virsh -c qemu+ssh://core@192.168.127.251/system start controller-0
virsh -c qemu+ssh://core@192.168.127.252/system start controller-1
virsh -c qemu+ssh://core@192.168.127.251/system start controller-2

virsh -c qemu+ssh://core@192.168.127.251/system start worker-0
virsh -c qemu+ssh://core@192.168.127.252/system start worker-1
```

### Write kubeconfig file

```bash
terraform apply -target=local_file.kubeconfig-admin
export KUBECONFIG=$(pwd)/output/default-cluster-012.kubeconfig
```

### Generate basic Kubernetes addons

```bash
terraform apply -target=module.kubernetes-addons
```

Apply addons:

```bash
kubectl apply -f http://127.0.0.1:8080/generic?manifest=bootstrap
kubectl apply -f http://127.0.0.1:8080/generic?manifest=kube-proxy
kubectl apply -f http://127.0.0.1:8080/generic?manifest=flannel
kubectl apply -f http://127.0.0.1:8080/generic?manifest=kapprover
kubectl apply -f http://127.0.0.1:8080/generic?manifest=coredns
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml
kubectl apply -f http://127.0.0.1:8080/generic?manifest=metallb
kubectl apply -f http://127.0.0.1:8080/generic?secret=internal-tls
kubectl apply -f http://127.0.0.1:8080/generic?secret=minio-auth
```

### Deploy services on Kubernetes

Deploy [Traefik](https://traefik.io/) ingress:

```
cd reqourcesv2/manifests
kubectl apply -f traefik.yaml
```

Deploy [Minio](https://min.io/) storage controller:

```
cd reqourcesv2/manifests
kubectl apply -f minio.yaml
```

Deploy MPD:

```
cd reqourcesv2/manifests
kubectl apply -f mpd-rclone-pv.yaml
kubectl apply -f music-rclone-pv.yaml
kubectl apply -f mpd.yaml
```

Deploy Transmission:

```
cd reqourcesv2/manifests
kubectl create secret generic openvpn-auth-user-pass --from-file=openvpn-auth-user-pass
kubectl apply -f ingest-rclone-pv.yaml
kubectl apply -f transmission.yaml
```
