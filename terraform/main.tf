data "aws_iam_policy_document" "ent_deploy_assume_role" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "AWS"
      identifiers = [var.ent_aws_account_arn]
    }
  }
}

resource "aws_iam_policy" "ent_deploy_permissions" {
  name        = "EntHomeAccess"
  description = "Custom policy for permissions needed by Ent Home to deploy and manage resources in customer accounts. This policy is attached to the role that Ent Home assumes when deploying resources in customer accounts."
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CertificateManagerAccess"
        Effect   = "Allow"
        Action   = ["acm:*"]
        Resource = "*"
      },
      {
        Sid    = "AthenaAccess"
        Effect = "Allow"
        Action = ["athena:*"]
        Resource = [
          "arn:aws:athena:*:*:workgroup/e???????????????-*",
          "arn:aws:athena:*:*:datacatalog/e???????????????-*",
        ]
      },
      {
        Sid    = "BedrockAccess"
        Effect = "Allow"
        Action = ["bedrock:*"]
        Resource = [
          "arn:aws:bedrock:*:*:inference-profile/*",
          "arn:aws:bedrock:*:*:application-inference-profile/*",
        ]
      },
      {
        Sid    = "CostAndUsageReportReadAccess"
        Effect = "Allow"
        Action = [
          "cur:Describe*",
          "cur:Get*",
        ]
        Resource = "*"
      },
      {
        Sid      = "CloudWatchAccess"
        Effect   = "Allow"
        Action   = ["cloudwatch:*"]
        Resource = ["arn:aws:cloudwatch:*:*:alarm:e???????????????-*"]
      },
      {
        Sid      = "EC2Access"
        Effect   = "Allow"
        Action   = ["ec2:*"]
        Resource = "*"
      },
      {
        Sid      = "ECRAccess"
        Effect   = "Allow"
        Action   = ["ecr:*"]
        Resource = "arn:aws:ecr:*:*:repository/e???????????????-*"
      },
      {
        Sid      = "ECRAuthTokenAccess"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = ["eks:*"]
        Resource = [
          "arn:aws:eks:*:*:cluster/e???????????????-*",
          "arn:aws:eks:*:*:nodegroup/e???????????????-*/*/*",
          "arn:aws:eks:*:*:access-entry/e???????????????-*/*",
          "arn:aws:eks:*:*:addon/e???????????????-*/*/*",
        ]
      },
      {
        Sid    = "ElastiCacheAccess"
        Effect = "Allow"
        Action = ["elasticache:*"]
        Resource = [
          "arn:aws:elasticache:*:*:replicationgroup:e???????????????-*",
          "arn:aws:elasticache:*:*:parametergroup:e???????????????-*",
          "arn:aws:elasticache:*:*:subnetgroup:e???????????????-*",
        ]
      },
      {
        Sid      = "ELBAccess"
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:*"]
        Resource = "*"
      },
      {
        Sid    = "GlueAccess"
        Effect = "Allow"
        Action = ["glue:*"]
        Resource = [
          "arn:aws:glue:*:*:catalog",
          "arn:aws:glue:*:*:database/e???????????????-*",
          "arn:aws:glue:*:*:table/e???????????????-*/*",
        ]
      },
      {
        Sid    = "IAMAccess"
        Effect = "Allow"
        Action = ["iam:*"]
        Resource = [
          "arn:aws:iam::*:role/e???????????????-*",
          "arn:aws:iam::*:policy/e???????????????-*",
          "arn:aws:iam::*:instance-profile/e???????????????-*",
        ]
      },
      {
        Sid      = "IAMServiceLinkedRoleAccess"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "arn:aws:iam::*:role/aws-service-role/*"
        Condition = {
          StringLike = {
            "iam:AWSServiceName" = [
              "eks.amazonaws.com",
              "eks-nodegroup.amazonaws.com",
              "eks-fargate-pods.amazonaws.com",
              "elasticloadbalancing.amazonaws.com",
              "rds.amazonaws.com",
              "elasticache.amazonaws.com",
              "opensearchservice.amazonaws.com",
            ]
          }
        }
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = ["kms:*"]
        Resource = [
          "arn:aws:kms:*:*:key/*",
          "arn:aws:kms:*:*:alias/e???????????????-*",
        ]
      },
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = ["logs:*"]
        Resource = [
          "arn:aws:logs:*:*:log-group:e???????????????-*",
          "arn:aws:logs:*:*:log-group:e???????????????-*:*",
          "arn:aws:logs:*:*:log-group:/aws/eks/e???????????????-*/*",
        ]
      },
      {
        Sid    = "CloudWatchLogsDescribeAccess"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSAccess"
        Effect = "Allow"
        Action = ["rds:*", "rds-db:*"]
        Resource = [
          "arn:aws:rds:*:*:db:e???????????????-*",
          "arn:aws:rds:*:*:cluster:e???????????????-*",
          "arn:aws:rds:*:*:pg:e???????????????-*",
          "arn:aws:rds:*:*:subgrp:e???????????????-*",
          "arn:aws:rds:*:*:es:e???????????????-*",
          "arn:aws:rds-db:*:*:dbuser:*/*",
        ]
      },
      {
        Sid      = "ResourceGroupsAccess"
        Effect   = "Allow"
        Action   = ["resource-groups:*"]
        Resource = "arn:aws:resource-groups:*:*:group/e???????????????-*"
      },
      {
        Sid      = "Route53Access"
        Effect   = "Allow"
        Action   = ["route53:*"]
        Resource = "*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = [
          "arn:aws:s3:::e???????????????-*",
          "arn:aws:s3:::e???????????????-*/*",
        ]
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = ["secretsmanager:*"]
        Resource = [
          "arn:aws:secretsmanager:*:*:secret:e???????????????-*",
          "arn:aws:secretsmanager:*:*:secret:mks*",
        ]
      },
      {
        Sid      = "SNSAccess"
        Effect   = "Allow"
        Action   = ["sns:*"]
        Resource = "arn:aws:sns:*:*:e???????????????-*"
      },
      {
        Sid      = "SQSAccess"
        Effect   = "Allow"
        Action   = ["sqs:*"]
        Resource = "arn:aws:sqs:*:*:e???????????????-*"
      },
      {
        Sid = "STSAssumeRoleAccess"
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
          "sts:AssumeRoleWithWebIdentity",
        ]
        Resource = "arn:aws:iam::*:role/e???????????????-*"
      },
      {
        Sid = "STSIdentityAccess"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "sts:DecodeAuthorizationMessage",
          "sts:GetAccessKeyInfo",
        ]
        Resource = "*"
      },
      {
        Sid      = "TaggingAccess"
        Effect   = "Allow"
        Action   = ["tag:*"]
        Resource = "*"
      },
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