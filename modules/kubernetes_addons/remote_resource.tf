data "http" "remote-manifests" {
  for_each = local.remote_manifests
  url      = each.value
}