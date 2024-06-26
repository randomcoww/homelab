module "disks" {
  for_each = local.members.disks
  source   = "./modules/disks"

  ignition_version = local.ignition_version
  disks            = lookup(each.value, "disks", {})
}