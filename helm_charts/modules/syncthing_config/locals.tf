locals {
  syncthing_members = [
    for i in range(var.replicas) :
    {
      pod_name  = "${var.name}-${i}"
      device_id = data.syncthing_device.syncthing[i].id
      cert      = tls_locally_signed_cert.syncthing[i].cert_pem
      key       = tls_private_key.syncthing[i].private_key_pem
    }
  ]
}