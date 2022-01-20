resource "aws_iam_user" "s3-backup" {
  name = var.s3_backup_key
}

resource "aws_iam_user_policy" "s3-backup" {
  name = aws_iam_user.s3-backup.name
  user = aws_iam_user.s3-backup.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          "arn:aws:s3:::${local.s3_backup_path}",
          "arn:aws:s3:::${local.s3_backup_path}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "s3-backup" {
  user = aws_iam_user.s3-backup.name
}