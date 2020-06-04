data "aws_s3_bucket_object" "secrets" {
  bucket = var.s3_secrets_bucket
  key    = "secrets.yaml"
}