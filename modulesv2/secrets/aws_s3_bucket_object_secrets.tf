data "aws_s3_bucket_object" "secrets" {
  bucket = var.s3_secrets_bucket
  key    = var.s3_secrets_key
}