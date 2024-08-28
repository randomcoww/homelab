resource "aws_s3_bucket" "bucket" {
  for_each = {
    for _, res in local.s3_resources :
    res.bucket => true
  }
  bucket = each.key
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket" {
  for_each = aws_s3_bucket.bucket
  bucket   = each.key
  rule {
    id     = each.key
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  for_each = aws_s3_bucket.bucket
  bucket   = each.key
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "bucket" {
  for_each = aws_s3_bucket.bucket
  bucket   = each.key
  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_iam_user" "s3" {
  for_each = local.s3_resources
  name     = each.key
}

resource "aws_iam_user_policy" "s3" {
  for_each = local.s3_resources
  name     = aws_iam_user.s3[each.key].name
  user     = aws_iam_user.s3[each.key].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          "arn:aws:s3:::${each.value.bucket}",
          "arn:aws:s3:::${each.value.resource}",
          "arn:aws:s3:::${each.value.resource}/*",
        ]
      },
    ]
  })
}

resource "aws_iam_access_key" "s3" {
  for_each = local.s3_resources
  user     = aws_iam_user.s3[each.key].name
}