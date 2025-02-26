resource "terraform_data" "write-local-disk" {
  for_each = toset(var.hosts)

  provisioner "remote-exec" {
    inline = var.command
  }
  connection {
    type        = "ssh"
    host        = each.key
    user        = local.users.ssh.name
    private_key = tls_private_key.ssh-client.private_key_pem
    certificate = ssh_user_cert.ssh-client.cert_authorized_key
  }
  triggers_replace = [
    timestamp(),
  ]
}