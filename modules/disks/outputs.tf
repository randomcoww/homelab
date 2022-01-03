output "ignition" {
  value = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      disks = local.disks
    })
  ]
}