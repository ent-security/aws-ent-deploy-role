data "aws_iam_policy_document" "ent_deploy_assume_role" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.ent_aws_account_arn]
    }

    dynamic "condition" {
      for_each = var.role_sts_externalid != null ? [true] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.role_sts_externalid]
      }
    }
  }
}

resource "aws_iam_policy" "ent_deploy_permissions" {
  name        = "EntAdditionalPermissions"
  description = "Custom policy for permissions in addition to the SecurityAudit policy"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
            "backup:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "sts:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "eks:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "s3:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "iam:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "ecr:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "secretsmanager:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "rds:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "cloudwatch:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "logs:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "aoss:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "elasticache:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "sns:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "ec2:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "kms:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "route53:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "route53domains:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "acm:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "sqs:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "resource-groups:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "tag:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
            "bedrock:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "ent" {
  name        = var.role_name
  path        = var.role_path
  description = var.role_description

  assume_role_policy = data.aws_iam_policy_document.ent_deploy_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ent_deploy_permissions" {
  role       = aws_iam_role.ent.name
  policy_arn = aws_iam_policy.ent_deploy_permissions.arn
}