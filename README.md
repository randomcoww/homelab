### Terraform configs for provisioning homelab resources

All VMs run CoreOS Container Linux.
Config rendering is handled by [CoreOS Matchbox](https://github.com/coreos/matchbox/).

#### Renderer

[Renderer](setup_renderer) generates minimal configuration for standing up a local Matchbox server that accepts configuration from terraform.
This is used to generate configuration for provisioning the VM host and PXE boot environment VM before a network boot environment is available.

```
cd setup_renderer
./run_matchbox.sh
```

#### Provisioner

[Provisioner](setup_provisioner) is configuration for Matchbox and the network PXE environment itself. These configs can be pushed to the local renderer to generate. Currently, the rendered configs need to be commited to the repo path [static](static) and referenced through github raw in [libvirt](docs/libvirt/provisioner-0.xml) and [ignition](docs/ignition/provisioner-0.ign) to stand up the server.

Hypervisor/storage hardware hosts (store-*) images are built using [livecd-creator](https://github.com/livecd-tools/livecd-tools).

With local matchbox running:
```
wget -O store-0.ks \
    http://127.0.0.1:8080/generic?host=store-0

livecd-creator \
    --verbose \
    --config=store-0.ks \
    --cache=/var/cache/live \
    --releasever 28 \
    --title store-1
```

#### Remaining environment

[Setup environment](setup_environment) contains configuration that will only work after the provisioner is deployed. Currently it will deploy a three master and two worker Kubernetes cluster from libvirt configs in [docs](docs/libvirt)

#### VM data persistence

* Hypervisor images are intended to boot from a flash drive and run on RAM disk. There is no configuration for persistence by default.
* Proviosioner and Kubernetes VMs also run on RAM disk using the default configuration of Container Linux PXE boot. There is no root disk persistence.