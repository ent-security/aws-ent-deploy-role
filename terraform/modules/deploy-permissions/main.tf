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
# A single managed policy carrying all 36 statements exceeds AWS's 6144-character managed-policy
# hard limit. The permission set is therefore split across FOUR functional managed policies along
# service-domain boundaries — compute/network, data/storage, identity/security, and
# observability/platform — each well under the limit (see scripts/check-policy-size.sh). Every
# statement is assigned to exactly one domain by its Sid (local.statement_group); the union of the
# four is the full permission set. The zero-diff test in tests/ asserts each rendered policy == its
# EntHomeAccess.<domain>.json file. (The split's set-equality to the pre-split single policy was
# validated before merge via a throwaway reference anchor, since removed.)
#
# The four policies are named ${var.policy_name}{Compute,Data,Security,Platform} from the
# var.policy_name prefix (default "EntHomeAccess"), so a consumer overriding the prefix still gets
# four suffixed names.

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
      Sid      = "S3AccountPublicAccessBlockAccess"
      Effect   = "Allow"
      Action   = ["s3:GetAccountPublicAccessBlock"]
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
      # Read the account's "Running On-Demand G and VT instances" vCPU quota -- the applied value via
      # GetServiceQuota, or the AWS default via GetAWSDefaultServiceQuota when the account has no applied
      # override (GetServiceQuota throws NoSuchResourceException there) -- and file an increase so the
      # capability-aware GPU profile selection in ent-platform can degrade to a launchable card (or raise
      # the quota for a better one) instead of wedging the production-stack rollout on a Pending GPU pod.
      # Scoped to the EC2 quota namespace -- quota ARNs are account-global, not tenant-prefixed.
      Sid    = "ServiceQuotasEC2Access"
      Effect = "Allow"
      Action = [
        "servicequotas:GetServiceQuota",
        "servicequotas:GetAWSDefaultServiceQuota",
        "servicequotas:ListRequestedServiceQuotaChangeHistoryByQuota",
        "servicequotas:RequestServiceQuotaIncrease",
      ]
      Resource = "arn:${local.partition}:servicequotas:*:*:ec2/*"
    },
    {
      # servicequotas:ListServiceQuotas has no resource-level support (it enumerates a service's quotas
      # rather than acting on one), so it must be granted account-wide with Resource "*" -- unlike the
      # quota-scoped Get/Request actions above.
      Sid      = "ServiceQuotasListAccess"
      Effect   = "Allow"
      Action   = ["servicequotas:ListServiceQuotas"]
      Resource = "*"
    },
  ]

  # Functional split: each statement's Sid maps to exactly one of the four service domains. The
  # union of the four lists is the full permission set. Keep this map in lockstep with the four
  # EntHomeAccess.<domain>.json files — a Sid added to the policy must land in exactly one domain
  # here AND in the matching file.
  statement_group = {
    # Compute & Networking -> EntHomeAccessCompute (EntHomeAccess.compute-network.json)
    EC2Access                      = "compute-network"
    EKSAccess                      = "compute-network"
    EKSDescribeAddonVersionsAccess = "compute-network"
    ECRAccess                      = "compute-network"
    ECRAuthTokenAccess             = "compute-network"
    ELBAccess                      = "compute-network"
    Route53Access                  = "compute-network"

    # Data & Storage -> EntHomeAccessData (EntHomeAccess.data-storage.json)
    S3Access                         = "data-storage"
    S3ListAllMyBucketsAccess         = "data-storage"
    S3AccountPublicAccessBlockAccess = "data-storage"
    RDSAccess                        = "data-storage"
    RDSDescribeAccess                = "data-storage"
    EFSAccess                        = "data-storage"
    ElastiCacheAccess                = "data-storage"
    AthenaAccess                     = "data-storage"
    GlueAccess                       = "data-storage"

    # Identity & Security -> EntHomeAccessSecurity (EntHomeAccess.identity-security.json)
    IAMAccess                  = "identity-security"
    IAMSessionContextAccess    = "identity-security"
    IAMServiceLinkedRoleAccess = "identity-security"
    STSAssumeRoleAccess        = "identity-security"
    STSIdentityAccess          = "identity-security"
    KMSAccess                  = "identity-security"
    KMSAccountLevelAccess      = "identity-security"
    SecretsManagerAccess       = "identity-security"
    CertificateManagerAccess   = "identity-security"
    WAFv2Access                = "identity-security"

    # Observability & Platform -> EntHomeAccessPlatform (EntHomeAccess.observability-platform.json)
    CloudWatchAccess             = "observability-platform"
    CloudWatchLogsAccess         = "observability-platform"
    CloudWatchLogsDescribeAccess = "observability-platform"
    CostAndUsageReportAccess     = "observability-platform"
    BCMDataExportsAccess         = "observability-platform"
    ServiceQuotasEC2Access       = "observability-platform"
    ServiceQuotasListAccess      = "observability-platform"
    ResourceGroupsAccess         = "observability-platform"
    TaggingAccess                = "observability-platform"
    SNSAccess                    = "observability-platform"
    SQSAccess                    = "observability-platform"
    BedrockAccess                = "observability-platform"
  }

  # Per-domain definition: the name suffix appended to var.policy_name. Drives one aws_iam_policy
  # each via for_each. Map keys match the statement_group values.
  groups = {
    compute-network        = { suffix = "Compute" }
    data-storage           = { suffix = "Data" }
    identity-security      = { suffix = "Security" }
    observability-platform = { suffix = "Platform" }
  }

  # Drop excluded Sids (GovCloud partition prune), keeping the original relative order, then bucket
  # the survivors by domain. Fails loud (Terraform errors on the missing map key) if a statement's
  # Sid is absent from statement_group — a new statement must be categorized.
  included_statements = [for s in local.all_statements : s if !contains(var.excluded_statement_sids, s.Sid)]
  grouped_statements = {
    for key, _ in local.groups :
    key => [for s in local.included_statements : s if local.statement_group[s.Sid] == key]
  }
}

resource "aws_iam_policy" "this" {
  for_each = local.groups

  name        = "${var.policy_name}${each.value.suffix}"
  description = var.policy_description
  path        = var.policy_path

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.grouped_statements[each.key]
  })

  tags = var.tags
}
