# Partition the role is deployed into (aws, aws-us-gov, aws-cn). Used to build
# resource ARNs so the policy works in commercial and GovCloud alike.
data "aws_partition" "current" {}

data "aws_iam_policy_document" "ent_deploy_assume_role" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "AWS"
      identifiers = [var.ent_aws_account_arn]
    }

    dynamic "condition" {
      for_each = var.role_sts_external_id != "" ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.role_sts_external_id]
      }
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
          "arn:${data.aws_partition.current.partition}:athena:*:*:workgroup/e???????????????-*",
          "arn:${data.aws_partition.current.partition}:athena:*:*:datacatalog/e???????????????-*",
        ]
      },
      {
        Sid    = "BedrockAccess"
        Effect = "Allow"
        Action = ["bedrock:*"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:bedrock:*:*:inference-profile/*",
          "arn:${data.aws_partition.current.partition}:bedrock:*:*:application-inference-profile/*",
          "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
        ]
      },
      {
        Sid    = "CostAndUsageReportAccess"
        Effect = "Allow"
        Action = [
          "cur:Describe*",
          "cur:Get*",
          "cur:PutReportDefinition",
        ]
        Resource = "*"
      },
      {
        Sid    = "BCMDataExportsAccess"
        Effect = "Allow"
        Action = ["bcm-data-exports:*"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:bcm-data-exports:*:*:export/*",
          "arn:${data.aws_partition.current.partition}:bcm-data-exports:*:*:table/*",
        ]
      },
      {
        Sid      = "CloudWatchAccess"
        Effect   = "Allow"
        Action   = ["cloudwatch:*"]
        Resource = ["arn:${data.aws_partition.current.partition}:cloudwatch:*:*:alarm:e???????????????-*"]
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
        Resource = "arn:${data.aws_partition.current.partition}:ecr:*:*:repository/e???????????????-*"
      },
      {
        Sid      = "ECRAuthTokenAccess"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "EFSAccess"
        Effect = "Allow"
        Action = ["elasticfilesystem:*"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:elasticfilesystem:*:*:file-system/*",
          "arn:${data.aws_partition.current.partition}:elasticfilesystem:*:*:access-point/*",
        ]
      },
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = ["eks:*"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:eks:*:*:cluster/e???????????????-*",
          "arn:${data.aws_partition.current.partition}:eks:*:*:nodegroup/e???????????????-*/*/*",
          "arn:${data.aws_partition.current.partition}:eks:*:*:access-entry/e???????????????-*/*",
          "arn:${data.aws_partition.current.partition}:eks:*:*:addon/e???????????????-*/*/*",
          "arn:${data.aws_partition.current.partition}:eks:*:*:podidentityassociation/e???????????????-*/*",
        ]
      },
      {
        Sid      = "EKSDescribeAddonVersionsAccess"
        Effect   = "Allow"
        Action   = ["eks:DescribeAddonVersions"]
        Resource = "*"
      },
      {
        Sid    = "ElastiCacheAccess"
        Effect = "Allow"
        Action = ["elasticache:*"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:elasticache:*:*:cluster:e???????????????-*",
          "arn:${data.aws_partition.current.partition}:elasticache:*:*:replicationgroup:e???????????????-*",
          "arn:${data.aws_partition.current.partition}:elasticache:*:*:parametergroup:e???????????????-*",
          "arn:${data.aws_partition.current.partition}:elasticache:*:*:subnetgroup:e???????????????-*",
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
          "arn:${data.aws_partition.current.partition}:glue:*:*:catalog",
          "arn:${data.aws_partition.current.partition}:glue:*:*:database/e???????????????*",
          "arn:${data.aws_partition.current.partition}:glue:*:*:table/e???????????????*/*",
        ]
      },
      {
        Sid    = "IAMAccess"
        Effect = "Allow"
        Action = ["iam:*"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:iam::*:role/e???????????????-*",
          "arn:${data.aws_partition.current.partition}:iam::*:policy/e???????????????-*",
          "arn:${data.aws_partition.current.partition}:iam::*:instance-profile/e???????????????-*",
          "arn:${data.aws_partition.current.partition}:iam::*:policy/AmazonEKS_*",
          "arn:${data.aws_partition.current.partition}:iam::*:oidc-provider/oidc.eks.*.amazonaws.com/*",
        ]
      },
      {
        Sid      = "IAMSessionContextAccess"
        Effect   = "Allow"
        Action   = ["iam:GetRole"]
        Resource = "*"
      },
      {
        Sid      = "IAMServiceLinkedRoleAccess"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "arn:${data.aws_partition.current.partition}:iam::*:role/aws-service-role/*"
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
              "backup.amazonaws.com",
              "elasticfilesystem.amazonaws.com",
            ]
          }
        }
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = ["kms:*"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:kms:*:*:key/*",
          "arn:${data.aws_partition.current.partition}:kms:*:*:alias/e???????????????-*",
          "arn:${data.aws_partition.current.partition}:kms:*:*:alias/eks/e???????????????-*",
        ]
      },
      {
        Sid    = "KMSAccountLevelAccess"
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:ListAliases",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = ["logs:*"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:*:*:log-group:e???????????????-*",
          "arn:${data.aws_partition.current.partition}:logs:*:*:log-group:/aws/*/e???????????????-*",
          "arn:${data.aws_partition.current.partition}:logs:*:*:log-group:/????????-????-????-????-????????????/*",
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
          "arn:${data.aws_partition.current.partition}:rds:*:*:db:e???????????????-*",
          "arn:${data.aws_partition.current.partition}:rds:*:*:cluster:e???????????????-*",
          "arn:${data.aws_partition.current.partition}:rds:*:*:pg:e???????????????-*",
          "arn:${data.aws_partition.current.partition}:rds:*:*:subgrp:e???????????????-*",
          "arn:${data.aws_partition.current.partition}:rds:*:*:es:e???????????????-*",
          "arn:${data.aws_partition.current.partition}:rds:*:*:es:db-event-sub-*",
          "arn:${data.aws_partition.current.partition}:rds-db:*:*:dbuser:*/*",
        ]
      },
      {
        Sid      = "RDSDescribeAccess"
        Effect   = "Allow"
        Action   = ["rds:DescribeDBInstances"]
        Resource = "*"
      },
      {
        Sid      = "ResourceGroupsAccess"
        Effect   = "Allow"
        Action   = ["resource-groups:*"]
        Resource = "arn:${data.aws_partition.current.partition}:resource-groups:*:*:group/e???????????????-*"
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
          "arn:${data.aws_partition.current.partition}:s3:::e???????????????-*",
          "arn:${data.aws_partition.current.partition}:s3:::e???????????????-*/*",
        ]
      },
      {
        Sid      = "S3ListAllMyBucketsAccess"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = ["secretsmanager:*"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:secretsmanager:*:*:secret:e???????????????-*",
          "arn:${data.aws_partition.current.partition}:secretsmanager:*:*:secret:mks*",
          "arn:${data.aws_partition.current.partition}:secretsmanager:*:*:secret:rds!*",
          "arn:${data.aws_partition.current.partition}:secretsmanager:*:*:secret:grafana/????????-????-????-????-????????????-*/*",
        ]
      },
      {
        Sid    = "SNSAccess"
        Effect = "Allow"
        Action = ["sns:*"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:sns:*:*:e???????????????-*",
          "arn:${data.aws_partition.current.partition}:sns:*:*:db-event-notifications",
        ]
      },
      {
        Sid      = "SQSAccess"
        Effect   = "Allow"
        Action   = ["sqs:*"]
        Resource = "arn:${data.aws_partition.current.partition}:sqs:*:*:e???????????????-*"
      },
      {
        Sid = "STSAssumeRoleAccess"
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
          "sts:AssumeRoleWithWebIdentity",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:iam::*:role/e???????????????-*"
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
        Sid    = "WAFv2Access"
        Effect = "Allow"
        Action = ["wafv2:*"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:wafv2:*:*:regional/webacl/e???????????????-*/*",
          "arn:${data.aws_partition.current.partition}:wafv2:*:*:global/webacl/e???????????????-*/*",
        ]
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