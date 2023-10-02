resource "aws_s3_bucket" "s3" {
  for_each = local.s3_resources
  bucket   = each.value.bucket
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
      }
    ]
  })
}

resource "aws_iam_access_key" "s3" {
  for_each = local.s3_resources
  user     = aws_iam_user.s3[each.key].name
}