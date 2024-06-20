module "disks" {
  for_each = local.members.disks
  source   = "./modules/disks"

  ignition_version = local.ignition_version
  disks            = lookup(each.value, "disks", {})
}

module "mounts" {
  for_each = local.members.mounts
  source   = "./modules/mounts"

  ignition_version = local.ignition_version
  mounts           = lookup(each.value, "mounts", [])
}