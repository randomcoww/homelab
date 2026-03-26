module "disks" {
  for_each = local.members.disks
  source   = "./modules/disks"

  butane_version = local.butane_version
  disks          = lookup(each.value, "disks", {})
}