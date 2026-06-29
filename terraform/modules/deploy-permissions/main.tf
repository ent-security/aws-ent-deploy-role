# Shared Ent Home deploy-permission policy — the single source of truth for the IAM permissions
# attached to the deploy role in BOTH partitions (commercial via assume-role, GovCloud via Roles
# Anywhere). The statement bodies are identical across partitions; only two things vary:
#
#   1. ARN partition — templated from data.aws_partition.current.partition, so the same statements
#      render arn:aws:* in the commercial partition and arn:aws-us-gov:* in GovCloud.
#   2. Service availability — statements for services absent from a partition are dropped via
#      var.excluded_statement_sids (see the govcloud/ root). This is the documented
#      "partition-override" spot; add Sids here as GovCloud apply surfaces unavailable services.
#
# Commercial rendering (partition == "aws", no exclusions) is byte-for-byte equivalent to the
# pre-refactor terraform/main.tf policy and the authoritative policy.json — enforced by the
# zero-diff test in terraform/commercial/tests/.

data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition

  all_statements = [
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
        "arn:${local.partition}:athena:*:*:workgroup/e???????????????-*",
        "arn:${local.partition}:athena:*:*:datacatalog/e???????????????-*",
      ]
    },
    {
      Sid    = "BedrockAccess"
      Effect = "Allow"
      Action = ["bedrock:*"]
      Resource = [
        "arn:${local.partition}:bedrock:*:*:inference-profile/*",
        "arn:${local.partition}:bedrock:*:*:application-inference-profile/*",
        "arn:${local.partition}:bedrock:*::foundation-model/*",
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
        "arn:${local.partition}:bcm-data-exports:*:*:export/*",
        "arn:${local.partition}:bcm-data-exports:*:*:table/*",
      ]
    },
    {
      Sid      = "CloudWatchAccess"
      Effect   = "Allow"
      Action   = ["cloudwatch:*"]
      Resource = ["arn:${local.partition}:cloudwatch:*:*:alarm:e???????????????-*"]
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
      Resource = "arn:${local.partition}:ecr:*:*:repository/e???????????????-*"
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
        "arn:${local.partition}:elasticfilesystem:*:*:file-system/*",
        "arn:${local.partition}:elasticfilesystem:*:*:access-point/*",
      ]
    },
    {
      Sid    = "EKSAccess"
      Effect = "Allow"
      Action = ["eks:*"]
      Resource = [
        "arn:${local.partition}:eks:*:*:cluster/e???????????????-*",
        "arn:${local.partition}:eks:*:*:nodegroup/e???????????????-*/*/*",
        "arn:${local.partition}:eks:*:*:access-entry/e???????????????-*/*",
        "arn:${local.partition}:eks:*:*:addon/e???????????????-*/*/*",
        "arn:${local.partition}:eks:*:*:podidentityassociation/e???????????????-*/*",
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
        "arn:${local.partition}:elasticache:*:*:cluster:e???????????????-*",
        "arn:${local.partition}:elasticache:*:*:replicationgroup:e???????????????-*",
        "arn:${local.partition}:elasticache:*:*:parametergroup:e???????????????-*",
        "arn:${local.partition}:elasticache:*:*:subnetgroup:e???????????????-*",
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
        "arn:${local.partition}:glue:*:*:catalog",
        "arn:${local.partition}:glue:*:*:database/e???????????????*",
        "arn:${local.partition}:glue:*:*:table/e???????????????*/*",
      ]
    },
    {
      Sid    = "IAMAccess"
      Effect = "Allow"
      Action = ["iam:*"]
      Resource = [
        "arn:${local.partition}:iam::*:role/e???????????????-*",
        "arn:${local.partition}:iam::*:policy/e???????????????-*",
        "arn:${local.partition}:iam::*:instance-profile/e???????????????-*",
        "arn:${local.partition}:iam::*:policy/AmazonEKS_*",
        "arn:${local.partition}:iam::*:oidc-provider/oidc.eks.*.amazonaws.com/*",
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
      Resource = "arn:${local.partition}:iam::*:role/aws-service-role/*"
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
        "arn:${local.partition}:kms:*:*:key/*",
        "arn:${local.partition}:kms:*:*:alias/e???????????????-*",
        "arn:${local.partition}:kms:*:*:alias/eks/e???????????????-*",
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
        "arn:${local.partition}:logs:*:*:log-group:e???????????????-*",
        "arn:${local.partition}:logs:*:*:log-group:/aws/*/e???????????????-*",
        "arn:${local.partition}:logs:*:*:log-group:/????????-????-????-????-????????????/*",
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
        "arn:${local.partition}:rds:*:*:db:e???????????????-*",
        "arn:${local.partition}:rds:*:*:cluster:e???????????????-*",
        "arn:${local.partition}:rds:*:*:pg:e???????????????-*",
        "arn:${local.partition}:rds:*:*:subgrp:e???????????????-*",
        "arn:${local.partition}:rds:*:*:es:e???????????????-*",
        "arn:${local.partition}:rds:*:*:es:db-event-sub-*",
        "arn:${local.partition}:rds-db:*:*:dbuser:*/*",
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
      Resource = "arn:${local.partition}:resource-groups:*:*:group/e???????????????-*"
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
        "arn:${local.partition}:s3:::e???????????????-*",
        "arn:${local.partition}:s3:::e???????????????-*/*",
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
        "arn:${local.partition}:secretsmanager:*:*:secret:e???????????????-*",
        "arn:${local.partition}:secretsmanager:*:*:secret:mks*",
        "arn:${local.partition}:secretsmanager:*:*:secret:rds!*",
        "arn:${local.partition}:secretsmanager:*:*:secret:grafana/????????-????-????-????-????????????-*/*",
      ]
    },
    {
      Sid    = "SNSAccess"
      Effect = "Allow"
      Action = ["sns:*"]
      Resource = [
        "arn:${local.partition}:sns:*:*:e???????????????-*",
        "arn:${local.partition}:sns:*:*:db-event-notifications",
      ]
    },
    {
      Sid      = "SQSAccess"
      Effect   = "Allow"
      Action   = ["sqs:*"]
      Resource = "arn:${local.partition}:sqs:*:*:e???????????????-*"
    },
    {
      Sid    = "STSAssumeRoleAccess"
      Effect = "Allow"
      Action = [
        "sts:AssumeRole",
        "sts:TagSession",
        "sts:AssumeRoleWithWebIdentity",
      ]
      Resource = "arn:${local.partition}:iam::*:role/e???????????????-*"
    },
    {
      Sid    = "STSIdentityAccess"
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
      # Regional web-ACLs exist in every partition. The global (CLOUDFRONT-scope) web-ACL only
      # exists where CloudFront does — i.e. the commercial partition — so it is omitted in GovCloud.
      Resource = concat(
        ["arn:${local.partition}:wafv2:*:*:regional/webacl/e???????????????-*/*"],
        local.partition == "aws" ? ["arn:${local.partition}:wafv2:*:*:global/webacl/e???????????????-*/*"] : [],
      )
    },
    {
      Sid      = "TaggingAccess"
      Effect   = "Allow"
      Action   = ["tag:*"]
      Resource = "*"
    },
    {
      # Read the account's "Running On-Demand G and VT instances" vCPU quota and file an increase so
      # the capability-aware GPU profile selection in ent-platform can degrade to a launchable card (or
      # raise the quota for a better one) instead of wedging the production-stack rollout on a Pending
      # GPU pod. Scoped to the EC2 quota namespace -- quota ARNs are account-global, not tenant-prefixed.
      Sid    = "ServiceQuotasEC2Access"
      Effect = "Allow"
      Action = [
        "servicequotas:GetServiceQuota",
        "servicequotas:ListRequestedServiceQuotaChangeHistoryByQuota",
        "servicequotas:RequestServiceQuotaIncrease",
      ]
      Resource = "arn:${local.partition}:servicequotas:*:*:ec2/*"
    },
  ]

  statements = [for s in local.all_statements : s if !contains(var.excluded_statement_sids, s.Sid)]
}

resource "aws_iam_policy" "this" {
  name        = var.policy_name
  description = var.policy_description
  path        = var.policy_path

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.statements
  })
}
