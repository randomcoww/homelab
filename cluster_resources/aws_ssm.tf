data "aws_caller_identity" "caller" {}

resource "aws_iam_user" "ssm" {
  for_each = local.ssm_resources
  name     = each.key
}

resource "aws_iam_user_policy" "ssm" {
  for_each = local.ssm_resources
  name     = aws_iam_user.ssm[each.key].name
  user     = aws_iam_user.ssm[each.key].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          "arn:aws:ssm:${local.aws_region}:${data.aws_caller_identity.caller.account_id}:parameter/${each.value.resource}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "ssm" {
  for_each = local.ssm_resources
  user     = aws_iam_user.ssm[each.key].name
}