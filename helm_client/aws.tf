# VW sqlite stream #

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

# authelia sqlite stream #

resource "aws_iam_user" "authelia-backup" {
  name = local.authelia.backup_user
}

resource "aws_iam_user_policy" "authelia-backup" {
  name = aws_iam_user.authelia-backup.name
  user = aws_iam_user.authelia-backup.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          "arn:aws:s3:::${local.authelia.backup_bucket}",
          "arn:aws:s3:::${local.authelia.backup_bucket}/${local.authelia.backup_path}",
          "arn:aws:s3:::${local.authelia.backup_bucket}/${local.authelia.backup_path}/*",
        ]
      },
    ]
  })
}

resource "aws_iam_access_key" "authelia-backup" {
  user = aws_iam_user.authelia-backup.name
}

# file backup #

resource "aws_iam_user" "s3-backup" {
  name = local.s3_backup.backup_user
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
          "arn:aws:s3:::${local.s3_backup.backup_bucket}",
          "arn:aws:s3:::${local.s3_backup.backup_bucket}/*",
        ]
      },
    ]
  })
}

resource "aws_iam_access_key" "s3-backup" {
  user = aws_iam_user.s3-backup.name
}