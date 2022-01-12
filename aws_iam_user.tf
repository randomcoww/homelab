resource "aws_iam_user" "etcd-s3-backup" {
  name = "etcd-s3-backup-${var.cluster_name}"
}

resource "aws_iam_user_policy" "etcd-s3-backup-access" {
  name = aws_iam_user.etcd-s3-backup.name
  user = aws_iam_user.etcd-s3-backup.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          "arn:aws:s3:::${var.etcd_s3_backup_bucket}/${var.cluster_name}",
          "arn:aws:s3:::${var.etcd_s3_backup_bucket}/${var.cluster_name}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "etcd-s3-backup" {
  user = aws_iam_user.etcd-s3-backup.name
  depends_on = [
    aws_iam_user_policy.etcd-s3-backup-access
  ]
}