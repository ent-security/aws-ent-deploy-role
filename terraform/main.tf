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
        Sid      = "OpenSearchServerlessAccess"
        Effect   = "Allow"
        Action   = ["aoss:*"]
        Resource = "*"
      },
      {
        Sid      = "AthenaAccess"
        Effect   = "Allow"
        Action   = ["athena:*"]
        Resource = "*"
      },
      {
        Sid      = "CostAndUsageReportAccess"
        Effect   = "Allow"
        Action   = ["bcm-data-exports:*"]
        Resource = "*"
      },
      {
        Sid      = "CostAndUsageReportLegacyAccess"
        Effect   = "Allow"
        Action   = ["cur:*"]
        Resource = "*"
      },
      {
        Sid      = "BedrockAccess"
        Effect   = "Allow"
        Action   = ["bedrock:*"]
        Resource = "*"
      },
      {
        Sid      = "CostExplorerAccess"
        Effect   = "Allow"
        Action   = ["ce:*"]
        Resource = "*"
      },
      {
        Sid      = "CloudWatchAccess"
        Effect   = "Allow"
        Action   = ["cloudwatch:*"]
        Resource = "*"
      },
      {
        Sid      = "CognitoAccess"
        Effect   = "Allow"
        Action   = ["cognito-idp:*"]
        Resource = "*"
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
        Resource = "*"
      },
      {
        Sid      = "EKSAccess"
        Effect   = "Allow"
        Action   = ["eks:*"]
        Resource = "*"
      },
      {
        Sid      = "ElastiCacheAccess"
        Effect   = "Allow"
        Action   = ["elasticache:*"]
        Resource = "*"
      },
      {
        Sid      = "ELBAccess"
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:*"]
        Resource = "*"
      },
      {
        Sid      = "GlueAccess"
        Effect   = "Allow"
        Action   = ["glue:*"]
        Resource = "*"
      },
      {
        Sid      = "GrafanaAccess"
        Effect   = "Allow"
        Action   = ["grafana:*"]
        Resource = "*"
      },
      {
        Sid      = "IAMAccess"
        Effect   = "Allow"
        Action   = ["iam:*"]
        Resource = "*"
      },
      {
        Sid      = "KendraAccess"
        Effect   = "Allow"
        Action   = ["kendra:*"]
        Resource = "*"
      },
      {
        Sid      = "KMSAccess"
        Effect   = "Allow"
        Action   = ["kms:*"]
        Resource = "*"
      },
      {
        Sid      = "LambdaAccess"
        Effect   = "Allow"
        Action   = ["lambda:*"]
        Resource = "*"
      },
      {
        Sid      = "CloudWatchLogsAccess"
        Effect   = "Allow"
        Action   = ["logs:*"]
        Resource = "*"
      },
      {
        Sid      = "RDSAccess"
        Effect   = "Allow"
        Action   = ["rds:*", "rds-db:*"]
        Resource = "*"
      },
      {
        Sid      = "ResourceGroupsAccess"
        Effect   = "Allow"
        Action   = ["resource-groups:*"]
        Resource = "*"
      },
      {
        Sid      = "Route53Access"
        Effect   = "Allow"
        Action   = ["route53:*"]
        Resource = "*"
      },
      {
        Sid      = "S3Access"
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = "*"
      },
      {
        Sid      = "SageMakerAccess"
        Effect   = "Allow"
        Action   = ["sagemaker:*"]
        Resource = "*"
      },
      {
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:*"]
        Resource = "*"
      },
      {
        Sid      = "ShieldAccess"
        Effect   = "Allow"
        Action   = ["shield:*"]
        Resource = "*"
      },
      {
        Sid      = "SNSAccess"
        Effect   = "Allow"
        Action   = ["sns:*"]
        Resource = "*"
      },
      {
        Sid      = "SQSAccess"
        Effect   = "Allow"
        Action   = ["sqs:*"]
        Resource = "*"
      },
      {
        Sid      = "STSAccess"
        Effect   = "Allow"
        Action   = ["sts:*"]
        Resource = "*"
      },
      {
        Sid      = "TaggingAccess"
        Effect   = "Allow"
        Action   = ["tag:*"]
        Resource = "*"
      },
      {
        Sid      = "WAFAccess"
        Effect   = "Allow"
        Action   = ["wafv2:*"]
        Resource = "*"
      },
      {
        Sid      = "XRayAccess"
        Effect   = "Allow"
        Action   = ["xray:*"]
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