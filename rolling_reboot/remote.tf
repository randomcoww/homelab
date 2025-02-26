resource "terraform_data" "sentinel-file" {
  for_each = {
    for host_key, host in local.hosts :
    host_key => host if lookup(host, "enable_rolling_reboot", false)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo touch /var/run/reboot-required",
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