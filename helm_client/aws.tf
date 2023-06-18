resource "aws_iam_user" "vaultwarden-backup" {
  name = local.vaultwarden.backup_user
}

resource "aws_iam_user_policy" "vaultwarden-backup" {
  name = aws_iam_user.vaultwarden-backup.name
  user = aws_iam_user.vaultwarden-backup.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          "arn:aws:s3:::${local.vaultwarden.backup_bucket}",
          "arn:aws:s3:::${local.vaultwarden.backup_bucket}/${local.vaultwarden.backup_path}",
          "arn:aws:s3:::${local.vaultwarden.backup_bucket}/${local.vaultwarden.backup_path}/*",
        ]
      },
    ]
  })
}

resource "aws_iam_access_key" "vaultwarden-backup" {
  user = aws_iam_user.vaultwarden-backup.name
}