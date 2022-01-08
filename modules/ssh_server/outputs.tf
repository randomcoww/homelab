output "ignition_snippets" {
  value = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      users = local.users
      certs = local.certs
    })
  ]
}