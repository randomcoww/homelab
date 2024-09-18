resource "minio_s3_bucket" "data" {
  for_each = local.minio_data_buckets

  bucket        = each.value.name
  acl           = lookup(each.value, "acl", "private")
  force_destroy = false
  depends_on = [
    helm_release.minio,
  ]
}