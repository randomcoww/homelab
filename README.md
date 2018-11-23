## Terraform configs for provisioning homelab resources

All VMs run on [CoreOS Container Linux](https://coreos.com/os/docs/latest/) using [Ignition](https://coreos.com/ignition/docs/latest/) for boot time configuration.

Config rendering is handled by [CoreOS Matchbox](https://github.com/coreos/matchbox/).

[HashiCorp Terraform](https://www.hashicorp.com/products/terraform) is used in all steps. The [Terraform Matchbox plugin](https://github.com/coreos/terraform-provider-matchbox) is needed. S3 is used at the backend store for Terraform and requires AWS access from the dev environment.

The hypervisor and all VMs run on RAM disk and keep no state. Any persistent configuration is intended to live on shared NFS (at 192.168.126.251 in my case).

### Renderer

[Renderer](setup_renderer) generates minimal configuration for standing up a local Matchbox server that accepts configuration from terraform and provides rendered configuration over http.
This is used to render configuration that cannot be provided over PXE (i.e. provisioner for the PXE server itself and hypervisor that they run on).

Generate TLS for local Matchbox
```
cd setup_renderer
terraform init
terraform apply
```

Start local Matchbox on Docker
```
./run_matchbox.sh
```

Service runs at:
```
http://127.0.0.1:8080
```

### Provisioner

[Provisioner](setup_provisioner) generates configuration for the PXE boot environment on the local Matchbox instance. Provisioner consists of a network gateway with Nftables and a PXE environemnt with a Matchbox instance of its own, DHCP and TFTP.

```
cd setup_provisioner
terraform init
terraform apply
```

#### Hypervisor Image

Generate hypervisor kickstart for live boot images:
```
wget -O store-0.ks \
    http://127.0.0.1:8080/generic?host=store-0

livecd-creator \
    --verbose \
    --config=store-0.ks \
    --cache=/var/cache/live \
    --releasever 29 \
    --title store-0

wget -O store-1.ks \
    http://127.0.0.1:8080/generic?host=store-1

livecd-creator \
    --verbose \
    --config=store-1.ks \
    --cache=/var/cache/live \
    --releasever 29 \
    --title store-1
```
These images are configured to run only in RAM disk, and no state is saved.

#### Provisioner VM

Provisioner VMs serving PXE also serve as the WAN gateway intended to boot on ISP DHCP. Ignition configuration is pulled from this github repo at boot time.

Copy and push CoreOS ignition configs to repo:
```
cd docs/ignition

wget -O provisioner-0.ign \
    http://127.0.0.1:8080/ignition?mac=52-54-00-1a-61-2a
wget -O provisioner-1.ign \
    http://127.0.0.1:8080/ignition?mac=52-54-00-1a-61-2b
    
git add provisioner-0.ign provisioner-1.ign
...
```

VM runs Kubelet in masterless mode to provide most of its services. The configuration for this is provided as a YAML manifest which is also pushed to and served from this repo:

```
cd docs/manifest

wget -O provisioner.yaml \
    http://127.0.0.1:8080/generic?manifest=provisioner
    
git add provisioner.yaml
...
```

Compatible KVM libvirt configurations are under [docs](docs/libvirt). I currently have no automation for defining and starting VMs.
```
virsh define provisioner-0.xml
virsh define provisioner-1.xml

virsh start provisioner-0
...
```

These steps are ugly and need revising.

#### Terraform Output

SSH CA private key for the hypervisor and provisioner VMs:
```
setup_provisioner/output/ssh-ca-key.pem
```

### Kubernetes and Remaining Environment

[Setup environment](setup_environment) handles generating PXE boot configurations that are pushed to the provisioner. This currently consists of a three master and two worker Kubernetes cluster.

Populate provisioner Matchbox instance:
```
cd setup_environment
terraform init
terraform apply
```

Compatible KVM libvirt configurations are under [docs](docs/libvirt). I currently have no automation for defining and starting VMs.
```
virsh define controller-0.xml
virsh define controller-1.xml
virsh define controller-2.xml
virsh define worker-0.xml
virsh define worker-1.xml

virsh start controller-0
...
```

#### Terraform Output

SSH CA private key for the Kubernetes VMs:
```
setup_environment/output/ssh-ca-key.pem
```

Admin kubeconfig:
```
setup_environment/output/kube-cluster/<name_of_cluster>/admin.kubeconfig
```

### Desktop Provisioning

[Setup desktop](setup_desktop) generates a kickstart for my desktop box. The following disk with existing partitions is assumed and the home partition is not formatted:

```
part /boot/efi --fstype=efi --size=200 --onpart /dev/nvme0n1p1
part /boot --fstype=ext4 --size=512 --onpart /dev/nvme0n1p2
part / --fstype=ext4 --size=20480 --onpart /dev/nvme0n1p3
part /home --fstype=ext4 --size=1024 --grow --noformat --onpart /dev/nvme0n1p4
```

Generate Kickstart:
```
cd setup_desktop
terraform init
terraform apply
```

I currently have no PXE boot environment for Fedora. The following boot args can be added to a Fedora 29 installer to use:
```
inst.text inst.ks=http://192.168.126.242:58080/generic?host=desktop-0
```
