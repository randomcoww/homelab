output "ignition" {
  value = [
    for f in fileset(".", "${path.module}/ignition/*") :
    templatefile(f, {
      disks = local.disks
    })
  ]
}