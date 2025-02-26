resource "terraform_data" "write-local-disk" {
  for_each = {
    for host_key, host in local.hosts :
    host_key => host
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOF
      set -ex -o pipefail

      export image_url=$(xargs -n1 -a /proc/cmdline | grep ^coreos.live.rootfs_url= | sed -r 's/coreos.live.rootfs_url=(.*)-rootfs(.*)\.img$/\1\2.iso/')
      export ignition_url=$(xargs -n1 -a /proc/cmdline | grep ^ignition.config.url= | sed 's/ignition.config.url=//')
      export disk=/dev/$(lsblk -ndo pkname /dev/disk/by-label/fedora-coreos-* | head -1)

      curl $image_url --output coreos.iso
      curl $ignition_url | coreos-installer iso ignition embed coreos.iso

      sudo dd if=coreos.iso of=$disk bs=4M
      sync
      rm coreos.iso
      EOF
    ]
  }
  connection {
    type        = "ssh"
    host        = cidrhost(each.value.networks.service.prefix, each.value.netnum)
    user        = local.users.ssh.name
    private_key = tls_private_key.ssh-client.private_key_pem
    certificate = ssh_user_cert.ssh-client.cert_authorized_key
  }
  triggers_replace = [
    timestamp(),
  ]
}