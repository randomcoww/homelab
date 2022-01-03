output "ignition" {
  value = [
    for f in fileset(".", "${path.module}/ignition/*") :
    templatefile(f, {
      user = var.user
      certs = local.certs
    })
  ]
}