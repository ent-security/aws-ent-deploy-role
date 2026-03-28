data "aws_iam_policy_document" "ent_deploy_assume_role" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "AWS"
      identifiers = [var.ent_aws_account_arn]
    }

    dynamic "condition" {
      for_each = var.external_id != "" ? [var.external_id] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [condition.value]
      }
    }
  }
}

# -----------------------------------------------------------------------------
# IAM Policy: Scoped permissions for Ent Home deployment and runtime
#
# This policy grants the minimum permissions needed for Ent Home to:
# 1. Deploy infrastructure via OpenTofu (VPC, EKS, RDS, ElastiCache, MSK, etc.)
# 2. Copy container images and models to customer ECR/S3
# 3. Run application workloads (S3, SQS, Bedrock, Secrets Manager, etc.)
#
# Permissions are scoped by:
# - Enumerating specific actions instead of service:* wildcards
# - Restricting IAM to ent-prefixed resources where possible
# - Excluding destructive KMS operations
# - Removing unused services (Cognito, Kendra, SageMaker, Lambda)
# - Removing STS from inline policy (trust policy handles assume-role)
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "ent_deploy_permissions" {
  name        = "EntHomeAccess"
  description = "Scoped permissions for Ent Home to deploy and manage infrastructure in customer accounts."
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # ── Networking & Compute (VPC, EKS, EC2) ──────────────────────────

      {
        Sid    = "VPCAndNetworking"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute", "ec2:DescribeVpcs",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:DescribeSecurityGroups", "ec2:DescribeSecurityGroupRules",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway", "ec2:DescribeInternetGateways",
          "ec2:CreateNatGateway", "ec2:DeleteNatGateway", "ec2:DescribeNatGateways",
          "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DescribeAddresses", "ec2:AssociateAddress", "ec2:DisassociateAddress",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:DescribeRouteTables",
          "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:ReplaceRoute",
          "ec2:CreateVpcEndpoint", "ec2:DeleteVpcEndpoints", "ec2:DescribeVpcEndpoints", "ec2:ModifyVpcEndpoint",
          "ec2:DescribeAvailabilityZones", "ec2:DescribeAccountAttributes",
          "ec2:DescribeNetworkInterfaces", "ec2:CreateNetworkInterface", "ec2:DeleteNetworkInterface", "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:DescribePrefixLists",
          "ec2:CreateTags", "ec2:DeleteTags", "ec2:DescribeTags",
          "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate", "ec2:DescribeLaunchTemplates", "ec2:DescribeLaunchTemplateVersions", "ec2:CreateLaunchTemplateVersion",
          "ec2:DescribeImages", "ec2:DescribeInstanceTypes", "ec2:DescribeInstances",
          "ec2:CreateFlowLogs", "ec2:DeleteFlowLogs", "ec2:DescribeFlowLogs",
          "ec2:DescribeVpcAttribute", "ec2:DescribeNetworkAcls", "ec2:DescribeDhcpOptions",
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = [
          "eks:CreateCluster", "eks:DeleteCluster", "eks:DescribeCluster", "eks:ListClusters",
          "eks:UpdateClusterConfig", "eks:UpdateClusterVersion",
          "eks:CreateNodegroup", "eks:DeleteNodegroup", "eks:DescribeNodegroup", "eks:UpdateNodegroupConfig", "eks:UpdateNodegroupVersion", "eks:ListNodegroups",
          "eks:CreateAccessEntry", "eks:DescribeAccessEntry", "eks:DeleteAccessEntry", "eks:ListAccessEntries",
          "eks:AssociateAccessPolicy", "eks:DisassociateAccessPolicy", "eks:ListAssociatedAccessPolicies",
          "eks:CreateAddon", "eks:DeleteAddon", "eks:DescribeAddon", "eks:DescribeAddonVersions", "eks:UpdateAddon", "eks:ListAddons",
          "eks:CreatePodIdentityAssociation", "eks:DeletePodIdentityAssociation", "eks:DescribePodIdentityAssociation", "eks:ListPodIdentityAssociations",
          "eks:TagResource", "eks:UntagResource", "eks:ListTagsForResource",
          "eks:DescribeUpdate", "eks:ListUpdates",
        ]
        Resource = "*"
      },

      # ── Data Stores ───────────────────────────────────────────────────

      {
        Sid    = "RDSAccess"
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance", "rds:DeleteDBInstance", "rds:DescribeDBInstances", "rds:ModifyDBInstance",
          "rds:CreateDBCluster", "rds:DeleteDBCluster", "rds:DescribeDBClusters", "rds:ModifyDBCluster",
          "rds:CreateDBSubnetGroup", "rds:DeleteDBSubnetGroup", "rds:DescribeDBSubnetGroups", "rds:ModifyDBSubnetGroup",
          "rds:CreateDBParameterGroup", "rds:DeleteDBParameterGroup", "rds:DescribeDBParameterGroups", "rds:ModifyDBParameterGroup", "rds:DescribeDBParameters",
          "rds:CreateOptionGroup", "rds:DeleteOptionGroup", "rds:DescribeOptionGroups", "rds:ModifyOptionGroup",
          "rds:CreateEventSubscription", "rds:DeleteEventSubscription", "rds:DescribeEventSubscriptions", "rds:ModifyEventSubscription",
          "rds:AddTagsToResource", "rds:RemoveTagsFromResource", "rds:ListTagsForResource",
          "rds:DescribeDBEngineVersions", "rds:DescribeOrderableDBInstanceOptions",
          "rds:CreateDBSnapshot", "rds:DescribeDBSnapshots",
          "rds:DescribeCertificates", "rds:DescribeEngineDefaultParameters",
          "rds-db:connect",
        ]
        Resource = "*"
      },
      {
        Sid    = "ElastiCacheAccess"
        Effect = "Allow"
        Action = [
          "elasticache:CreateCacheCluster", "elasticache:DeleteCacheCluster", "elasticache:DescribeCacheClusters", "elasticache:ModifyCacheCluster",
          "elasticache:CreateReplicationGroup", "elasticache:DeleteReplicationGroup", "elasticache:DescribeReplicationGroups", "elasticache:ModifyReplicationGroup",
          "elasticache:CreateCacheSubnetGroup", "elasticache:DeleteCacheSubnetGroup", "elasticache:DescribeCacheSubnetGroups", "elasticache:ModifyCacheSubnetGroup",
          "elasticache:CreateCacheParameterGroup", "elasticache:DeleteCacheParameterGroup", "elasticache:DescribeCacheParameterGroups", "elasticache:ModifyCacheParameterGroup", "elasticache:DescribeCacheParameters",
          "elasticache:AddTagsToResource", "elasticache:RemoveTagsFromResource", "elasticache:ListTagsForResource",
          "elasticache:DescribeCacheEngineVersions", "elasticache:DescribeEvents",
          "elasticache:CreateServerlessCache", "elasticache:DeleteServerlessCache", "elasticache:DescribeServerlessCaches", "elasticache:ModifyServerlessCache",
        ]
        Resource = "*"
      },
      {
        Sid    = "MSKAccess"
        Effect = "Allow"
        Action = [
          "kafka:CreateCluster", "kafka:CreateClusterV2", "kafka:DeleteCluster",
          "kafka:DescribeCluster", "kafka:DescribeClusterV2", "kafka:DescribeClusterOperation",
          "kafka:UpdateClusterConfiguration", "kafka:UpdateClusterKafkaVersion",
          "kafka:UpdateBrokerCount", "kafka:UpdateBrokerStorage", "kafka:UpdateBrokerType",
          "kafka:UpdateMonitoring", "kafka:UpdateSecurity", "kafka:UpdateConnectivity",
          "kafka:CreateConfiguration", "kafka:DeleteConfiguration", "kafka:DescribeConfiguration", "kafka:DescribeConfigurationRevision", "kafka:ListConfigurationRevisions", "kafka:UpdateConfiguration",
          "kafka:BatchAssociateScramSecret", "kafka:BatchDisassociateScramSecret",
          "kafka:TagResource", "kafka:UntagResource", "kafka:ListTagsForResource",
          "kafka:ListClusters", "kafka:ListClustersV2", "kafka:ListConfigurations", "kafka:ListNodes",
          "kafka:GetBootstrapBrokers",
          "kafka-cluster:Connect", "kafka-cluster:DescribeCluster",
          "kafka-cluster:AlterCluster", "kafka-cluster:DescribeClusterDynamicConfiguration",
          "kafka-cluster:CreateTopic", "kafka-cluster:DeleteTopic", "kafka-cluster:DescribeTopic", "kafka-cluster:AlterTopic",
          "kafka-cluster:ReadData", "kafka-cluster:WriteData",
          "kafka-cluster:DescribeGroup", "kafka-cluster:AlterGroup",
        ]
        Resource = "*"
      },
      {
        Sid    = "OpenSearchServerlessAccess"
        Effect = "Allow"
        Action = ["aoss:*"]
        Resource = "*"
      },

      # ── Storage ───────────────────────────────────────────────────────

      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket", "s3:DeleteBucket", "s3:ListBucket", "s3:ListAllMyBuckets",
          "s3:GetBucketLocation", "s3:GetBucketPolicy", "s3:PutBucketPolicy", "s3:DeleteBucketPolicy",
          "s3:GetBucketVersioning", "s3:PutBucketVersioning",
          "s3:GetBucketAcl", "s3:PutBucketAcl",
          "s3:GetBucketCORS", "s3:PutBucketCORS", "s3:DeleteBucketCORS",
          "s3:GetBucketTagging", "s3:PutBucketTagging",
          "s3:GetEncryptionConfiguration", "s3:PutEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock", "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketOwnershipControls", "s3:PutBucketOwnershipControls",
          "s3:GetLifecycleConfiguration", "s3:PutLifecycleConfiguration",
          "s3:GetBucketLogging", "s3:PutBucketLogging",
          "s3:GetBucketNotification", "s3:PutBucketNotification",
          "s3:GetReplicationConfiguration", "s3:PutReplicationConfiguration",
          "s3:GetAccelerateConfiguration", "s3:PutAccelerateConfiguration",
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:GetObjectVersion", "s3:DeleteObjectVersion",
          "s3:ListBucketVersions",
        ]
        Resource = "*"
      },

      # ── Secrets & Encryption ──────────────────────────────────────────

      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecret",
          "secretsmanager:GetResourcePolicy", "secretsmanager:PutResourcePolicy", "secretsmanager:DeleteResourcePolicy",
          "secretsmanager:TagResource", "secretsmanager:UntagResource", "secretsmanager:ListSecrets",
          "secretsmanager:RotateSecret", "secretsmanager:CancelRotateSecret",
          "secretsmanager:GetRandomPassword",
          "secretsmanager:RestoreSecret",
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:CreateKey", "kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus",
          "kms:ListKeys", "kms:ListAliases", "kms:ListResourceTags",
          "kms:CreateAlias", "kms:DeleteAlias", "kms:UpdateAlias",
          "kms:TagResource", "kms:UntagResource",
          "kms:EnableKeyRotation",
          "kms:Encrypt", "kms:Decrypt", "kms:ReEncryptFrom", "kms:ReEncryptTo",
          "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext",
          "kms:CreateGrant", "kms:ListGrants", "kms:RetireGrant", "kms:RevokeGrant",
          "kms:PutKeyPolicy",
        ]
        Resource = "*"
        # NOTE: Intentionally excludes kms:ScheduleKeyDeletion, kms:DisableKey,
        # kms:EnableKey, kms:ImportKeyMaterial, kms:DeleteImportedKeyMaterial
      },

      # ── IAM (scoped to deployment needs) ──────────────────────────────

      {
        Sid    = "IAMRoleManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:ListRoles", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy",
          "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags",
          "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicies",
          "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:ListPolicyVersions",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies",
          "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
          "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
          "iam:GetInstanceProfile", "iam:ListInstanceProfiles", "iam:ListInstanceProfilesForRole",
          "iam:CreateServiceLinkedRole", "iam:DeleteServiceLinkedRole", "iam:GetServiceLinkedRoleDeletionStatus",
          "iam:PassRole",
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider", "iam:TagOpenIDConnectProvider", "iam:ListOpenIDConnectProviders",
          "iam:ListEntitiesForPolicy",
        ]
        Resource = "*"
        # NOTE: Intentionally excludes iam:CreateUser, iam:CreateGroup,
        # iam:CreateLoginProfile, iam:CreateAccessKey, iam:UpdateLoginProfile,
        # iam:AttachUserPolicy, iam:AttachGroupPolicy, iam:AddUserToGroup,
        # iam:DeactivateMFADevice, iam:DeleteVirtualMFADevice, iam:CreateSAMLProvider
      },

      # ── Container Registry ────────────────────────────────────────────

      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository", "ecr:DeleteRepository", "ecr:DescribeRepositories", "ecr:ListImages",
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload",
          "ecr:SetRepositoryPolicy", "ecr:GetRepositoryPolicy", "ecr:DeleteRepositoryPolicy",
          "ecr:GetLifecyclePolicy", "ecr:PutLifecyclePolicy", "ecr:DeleteLifecyclePolicy",
          "ecr:TagResource", "ecr:UntagResource", "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings", "ecr:PutImageScanningConfiguration",
        ]
        Resource = "*"
      },

      # ── DNS & Certificates ────────────────────────────────────────────

      {
        Sid    = "Route53Access"
        Effect = "Allow"
        Action = [
          "route53:CreateHostedZone", "route53:DeleteHostedZone", "route53:GetHostedZone", "route53:ListHostedZones", "route53:ListHostedZonesByName",
          "route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets", "route53:GetChange",
          "route53:ChangeTagsForResource", "route53:ListTagsForResource",
          "route53:AssociateVPCWithHostedZone", "route53:DisassociateVPCFromHostedZone",
        ]
        Resource = "*"
      },
      {
        Sid    = "CertificateManagerAccess"
        Effect = "Allow"
        Action = [
          "acm:RequestCertificate", "acm:DeleteCertificate",
          "acm:DescribeCertificate", "acm:GetCertificate", "acm:ListCertificates", "acm:ListTagsForCertificate",
          "acm:AddTagsToCertificate", "acm:RemoveTagsFromCertificate",
          "acm:RenewCertificate",
        ]
        Resource = "*"
      },

      # ── Load Balancing & WAF ──────────────────────────────────────────

      {
        Sid    = "ELBAccess"
        Effect = "Allow"
        Action = ["elasticloadbalancing:*"]
        Resource = "*"
        # ALB controller requires broad ELB permissions; scoping individual
        # actions here is impractical as the controller policy enumerates 40+ actions
      },
      {
        Sid    = "WAFAccess"
        Effect = "Allow"
        Action = [
          "wafv2:CreateWebACL", "wafv2:DeleteWebACL", "wafv2:GetWebACL", "wafv2:UpdateWebACL", "wafv2:ListWebACLs",
          "wafv2:AssociateWebACL", "wafv2:DisassociateWebACL", "wafv2:GetWebACLForResource",
          "wafv2:TagResource", "wafv2:UntagResource", "wafv2:ListTagsForResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "ShieldAccess"
        Effect = "Allow"
        Action = [
          "shield:GetSubscriptionState",
          "shield:DescribeProtection", "shield:ListProtections",
          "shield:CreateProtection", "shield:DeleteProtection",
          "shield:EnableApplicationLayerAutomaticResponse", "shield:DisableApplicationLayerAutomaticResponse",
        ]
        Resource = "*"
      },

      # ── Observability ─────────────────────────────────────────────────

      {
        Sid    = "CloudWatchAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData", "cloudwatch:GetMetricStatistics", "cloudwatch:ListMetrics",
          "cloudwatch:PutMetricData", "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms",
          "cloudwatch:ListDashboards", "cloudwatch:GetDashboard", "cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards",
          "cloudwatch:ListTagsForResource", "cloudwatch:TagResource", "cloudwatch:UntagResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup",
          "logs:CreateLogStream", "logs:DeleteLogStream",
          "logs:PutLogEvents", "logs:GetLogEvents", "logs:FilterLogEvents",
          "logs:DescribeLogGroups", "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
          "logs:TagLogGroup", "logs:UntagLogGroup", "logs:TagResource", "logs:UntagResource", "logs:ListTagsForResource", "logs:ListTagsLogGroup",
        ]
        Resource = "*"
      },
      {
        Sid    = "GrafanaAccess"
        Effect = "Allow"
        Action = [
          "grafana:CreateWorkspace", "grafana:DeleteWorkspace",
          "grafana:DescribeWorkspace", "grafana:UpdateWorkspace",
          "grafana:ListWorkspaces",
          "grafana:TagResource", "grafana:UntagResource", "grafana:ListTagsForResource",
          "grafana:AssociateLicense", "grafana:DisassociateLicense",
          "grafana:UpdateWorkspaceConfiguration", "grafana:DescribeWorkspaceConfiguration",
          "grafana:UpdateWorkspaceAuthentication", "grafana:DescribeWorkspaceAuthentication",
          "grafana:CreateWorkspaceServiceAccount", "grafana:DeleteWorkspaceServiceAccount",
          "grafana:CreateWorkspaceServiceAccountToken", "grafana:DeleteWorkspaceServiceAccountToken",
        ]
        Resource = "*"
      },
      {
        Sid    = "XRayAccess"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments", "xray:PutTelemetryRecords",
          "xray:GetSamplingRules", "xray:GetSamplingTargets", "xray:GetSamplingStatisticSummaries",
        ]
        Resource = "*"
      },

      # ── Messaging ─────────────────────────────────────────────────────

      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue", "sqs:DeleteQueue", "sqs:GetQueueUrl", "sqs:GetQueueAttributes", "sqs:SetQueueAttributes",
          "sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:PurgeQueue",
          "sqs:ListQueues", "sqs:ListQueueTags",
          "sqs:TagQueue", "sqs:UntagQueue",
          "sqs:ChangeMessageVisibility",
        ]
        Resource = "*"
      },
      {
        Sid    = "SNSAccess"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic", "sns:DeleteTopic", "sns:GetTopicAttributes", "sns:SetTopicAttributes",
          "sns:Subscribe", "sns:Unsubscribe", "sns:Publish",
          "sns:ListTopics", "sns:ListSubscriptionsByTopic",
          "sns:TagResource", "sns:UntagResource", "sns:ListTagsForResource",
        ]
        Resource = "*"
      },

      # ── AI / ML ───────────────────────────────────────────────────────

      {
        Sid    = "BedrockAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream",
          "bedrock:CreateInferenceProfile", "bedrock:GetInferenceProfile", "bedrock:DeleteInferenceProfile", "bedrock:ListInferenceProfiles",
          "bedrock:GetFoundationModel", "bedrock:ListFoundationModels",
          "bedrock:TagResource", "bedrock:UntagResource", "bedrock:ListTagsForResource",
        ]
        Resource = "*"
      },

      # ── Cost Management (conditional features) ────────────────────────

      {
        Sid    = "CostManagementAccess"
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage", "ce:GetCostForecast", "ce:GetDimensionValues",
          "ce:GetTags", "ce:GetUsageForecast",
          "bcm-data-exports:CreateExport", "bcm-data-exports:DeleteExport",
          "bcm-data-exports:GetExport", "bcm-data-exports:ListExports", "bcm-data-exports:UpdateExport",
          "bcm-data-exports:ListTables",
          "athena:StartQueryExecution", "athena:StopQueryExecution",
          "athena:GetQueryExecution", "athena:GetQueryResults", "athena:GetWorkGroup",
          "athena:CreateWorkGroup", "athena:DeleteWorkGroup", "athena:UpdateWorkGroup",
          "athena:TagResource", "athena:UntagResource",
          "glue:GetTable", "glue:GetTables", "glue:GetDatabase", "glue:GetDatabases", "glue:GetPartitions",
          "glue:CreateTable", "glue:DeleteTable", "glue:UpdateTable",
          "glue:CreateDatabase", "glue:DeleteDatabase",
        ]
        Resource = "*"
      },

      # ── Tagging & Resource Groups ─────────────────────────────────────

      {
        Sid    = "TaggingAccess"
        Effect = "Allow"
        Action = [
          "tag:GetResources", "tag:GetTagKeys", "tag:GetTagValues",
          "tag:TagResources", "tag:UntagResources",
          "resource-groups:CreateGroup", "resource-groups:DeleteGroup",
          "resource-groups:GetGroup", "resource-groups:GetGroupQuery",
          "resource-groups:UpdateGroup", "resource-groups:UpdateGroupQuery",
          "resource-groups:Tag", "resource-groups:Untag", "resource-groups:ListGroupResources",
        ]
        Resource = "*"
      },

      # ── EFS (conditional: GPU inference) ──────────────────────────────

      {
        Sid    = "EFSAccess"
        Effect = "Allow"
        Action = [
          "elasticfilesystem:CreateFileSystem", "elasticfilesystem:DeleteFileSystem",
          "elasticfilesystem:DescribeFileSystems", "elasticfilesystem:DescribeMountTargets",
          "elasticfilesystem:CreateMountTarget", "elasticfilesystem:DeleteMountTarget",
          "elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite",
          "elasticfilesystem:TagResource", "elasticfilesystem:UntagResource", "elasticfilesystem:ListTagsForResource",
          "elasticfilesystem:DescribeFileSystemPolicy", "elasticfilesystem:PutFileSystemPolicy",
          "elasticfilesystem:CreateAccessPoint", "elasticfilesystem:DeleteAccessPoint", "elasticfilesystem:DescribeAccessPoints",
        ]
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
