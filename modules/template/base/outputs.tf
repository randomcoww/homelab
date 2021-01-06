locals {
  params = {}
}

output "ignition" {
  value = {
    for host, params in var.hosts :
    host => [
      for f in fileset(".", "${path.module}/templates/ignition/*") :
      templatefile(f, {
        p        = params
        luks_key = random_password.luks-key[host].result
      })
    ]
  }
}