### Terraform configs for provisioning homelab resources

All VMs run CoreOS Container Linux.
Config rendering is handled by [CoreOS Matchbox](https://github.com/coreos/matchbox/).

#### Renderer

[Renderer](setup_renderer) generates minimal configuration for standing up a local Matchbox server that accepts configuration from terraform.
This is used to generate configuration for provisioning the VM host and PXE boot environment VM before a network boot environment is available.

#### Provisioner

[Provisioner](setup_provisioner) is configuration for Matchbox and the network PXE environment itself. These configs can be pushed to the local renderer to generate. Currently, the rendered configs need to be commited to the repo path [static](static) and referenced through github raw in [libvirt](static/libvirt/provisioner-0.xml) and [ignition](static/ignition/provisioner-0.ign) to stand up the server.

A [packer config](setup_provisioner/packer) hits the local renderer for the kickstart configuration to build an image for the KVM host server to run the provisioner (and any other) environment component.

#### Remaining environment

[Setup environment](setup_environment) contains configuration that will only work after the provisioner is deployed. Currently, it will just deploy a Kubernetes cluster.

#### Data persistence

All VMs run Container Linux on ramdisk and are wiped out on VM or host reboot. Etcd and Matchbox data are confgured to write to NFS.
