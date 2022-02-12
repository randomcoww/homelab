locals {
  syncthing_members = [
    for i in range(var.replica_count) :
    {
      pod_name  = "${var.resource_name}-${i}"
      device_id = data.syncthing.syncthing[i].device_id
      cert      = tls_locally_signed_cert.syncthing[i].cert_pem
      key       = tls_private_key.syncthing[i].private_key_pem
    }
  ]

  addon_manifests = {
    for f in fileset(".", "${path.module}/manifests/*.yaml") :
    basename(f) => templatefile(f, {
      container_images    = var.container_images
      resource_name       = var.resource_name
      namespace           = var.resource_namespace
      replica_count       = var.replica_count
      syncthing_members   = local.syncthing_members
      syncthing_home_path = "/var/lib/syncthing"
      syncthing_peer_port = 22000
      sync_data_path      = var.sync_data_path
    })
  }
}
