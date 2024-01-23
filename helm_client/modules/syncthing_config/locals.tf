locals {
  syncthing_members = [
    for _, hostname in var.hostnames :
    {
      hostname  = hostname
      device_id = data.syncthing_device.syncthing[hostname].id
      cert      = tls_locally_signed_cert.syncthing[hostname].cert_pem
      key       = tls_private_key.syncthing[hostname].private_key_pem
    }
  ]
}