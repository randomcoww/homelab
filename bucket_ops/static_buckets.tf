resource "minio_s3_bucket" "static-bucket" {
  for_each = {
    boot = {
      acl = "public-read"
    }
    ebooks = {}
    music  = {}
    fluxcd = {}
  }

  bucket         = each.key
  acl            = lookup(each.value, "acl", "private")
  force_destroy  = false
  object_locking = lookup(each.value, "object_locking", false)
}