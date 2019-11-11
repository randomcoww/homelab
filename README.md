## Terraform configs for provisioning homelab resources

### Run local Matchbox

Configurations for creating hypervisor images are generated on a local [Matchbox](https://github.com/coreos/matchbox/) instance. This will generate necessary TLS certs and start a local Matchbox instance using Podman:

```bash
cd resourcesv2
./run_matchbox.sh
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

Each hypervisor runs a PXE boot environment on an internal network for provisioning VMs local to the host. VMs run [Container Linux](https://coreos.com/os/docs/latest/) using [Ignition](https://coreos.com/ignition/docs/latest/) for boot time configuration. Configuration is generated on each hypervisor as follows:

```bash
cd resourcesv2
terraform apply -target=module.ignition-kvm-0
terraform apply -target=module.ignition-kvm-1
```

Write SSH CA configuration for accessing the hypervisor over `virsh` and `ssh`.

```bash
cd resourcesv2
terraform apply -target=local_file.ssh-ca-key
```

### Start gateway VMs

This will provide a basic infrastructure including NAT routing, DHCP and DNS.

```bash
cd templates/libvirt
virsh -c qemu+ssh://core@192.168.127.251/system define gateway-0.xml
virsh -c qemu+ssh://core@192.168.127.252/system define gateway-1.xml

virsh -c qemu+ssh://core@192.168.127.251/system start gateway-0
virsh -c qemu+ssh://core@192.168.127.252/system start gateway-1
```

### Start Kubernetes cluster VMs

```bash
cd templates/libvirt
virsh -c qemu+ssh://core@192.168.127.251/system define controller-0.xml
virsh -c qemu+ssh://core@192.168.127.252/system define controller-1.xml
virsh -c qemu+ssh://core@192.168.127.252/system define controller-2.xml

virsh -c qemu+ssh://core@192.168.127.251/system start controller-0
virsh -c qemu+ssh://core@192.168.127.252/system start controller-1
virsh -c qemu+ssh://core@192.168.127.252/system start controller-2

virsh -c qemu+ssh://core@192.168.127.251/system define worker-0.xml
virsh -c qemu+ssh://core@192.168.127.252/system define worker-1.xml

virsh -c qemu+ssh://core@192.168.127.251/system start worker-0
virsh -c qemu+ssh://core@192.168.127.252/system start worker-1
```

Write admin kubeconfig file:

```bash
terraform apply -target=local_file.kubeconfig-admin
```

### Generate basic Kubernetes addons

```bash
terraform apply -target=mofule.kubernetes-addons
```

Apply addons:

```bash
kubectl apply -f http://127.0.0.1:8080/generic?manifest=kube-proxy
kubectl apply -f http://127.0.0.1:8080/generic?manifest=flannel
kubectl apply -f http://127.0.0.1:8080/generic?manifest=kapprover
kubectl apply -f http://127.0.0.1:8080/generic?manifest=coredns
```
