# Narrow EntHomeAccess Deploy Role Scope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Narrow the `EntHomeAccess` IAM policy — remove 12 unused services, scope remaining resources to `ent-platform`'s auto-generated name prefix shape `e???????????????-*`, and update all three policy representations (`policy.json`, Terraform, CloudFormation) plus the README.

**Architecture:** Three synchronized representations of the same IAM policy live side-by-side in this repo. The plan edits each one with the same narrowed statements, verifies with the representation's native validator, then diffs them against each other to prove equivalence.

**Tech Stack:** AWS IAM policy language, Terraform (AWS provider), CloudFormation YAML, plain JSON.

**Spec:** [`docs/superpowers/specs/2026-04-17-narrow-deploy-role-scope-design.md`](../specs/2026-04-17-narrow-deploy-role-scope-design.md)

---

## Pre-flight: Pending decision

Before starting Task 1, the human owner must decide whether to keep or drop `resource-groups` from the policy. The code review found one terraform reference in `ent-platform/deploy/tofu/home/main.tf`. This plan **keeps** it (narrowed). If the owner confirms it is unused, delete the `ResourceGroupsAccess` statement from all three representations before committing Task 1 — it is called out inline below.

## File structure

- Modify `policy.json` — plain JSON, ships for AWS CLI users.
- Modify `terraform/main.tf` — jsonencoded policy attached to the IAM role.
- Modify `cloudformation/template.yaml` — managed policy inside the CFN stack.
- Modify `README.md` — permissions table + new resource-scoping section.

No new files. No deleted files. No changes to `role.json`, `terraform/variables.tf`, `terraform/outputs.tf`, `terraform/versions.tf`.

---

## Task 1: Rewrite `policy.json` with narrowed scope

**Files:**
- Modify: `policy.json` (complete replacement)

- [ ] **Step 1: Replace the entire contents of `policy.json` with the narrowed policy**

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CertificateManagerAccess",
            "Effect": "Allow",
            "Action": [
                "acm:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AthenaAccess",
            "Effect": "Allow",
            "Action": [
                "athena:*"
            ],
            "Resource": [
                "arn:aws:athena:*:*:workgroup/e???????????????-*",
                "arn:aws:athena:*:*:datacatalog/e???????????????-*"
            ]
        },
        {
            "Sid": "BedrockAccess",
            "Effect": "Allow",
            "Action": [
                "bedrock:*"
            ],
            "Resource": [
                "arn:aws:bedrock:*:*:inference-profile/*",
                "arn:aws:bedrock:*:*:application-inference-profile/*"
            ]
        },
        {
            "Sid": "CostAndUsageReportReadAccess",
            "Effect": "Allow",
            "Action": [
                "cur:Describe*",
                "cur:Get*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CloudWatchAccess",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:*"
            ],
            "Resource": [
                "arn:aws:cloudwatch:*:*:alarm:e???????????????-*"
            ]
        },
        {
            "Sid": "EC2Access",
            "Effect": "Allow",
            "Action": [
                "ec2:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ECRAccess",
            "Effect": "Allow",
            "Action": [
                "ecr:*"
            ],
            "Resource": "arn:aws:ecr:*:*:repository/e???????????????-*"
        },
        {
            "Sid": "EKSAccess",
            "Effect": "Allow",
            "Action": [
                "eks:*"
            ],
            "Resource": [
                "arn:aws:eks:*:*:cluster/e???????????????-*",
                "arn:aws:eks:*:*:nodegroup/e???????????????-*/*/*",
                "arn:aws:eks:*:*:access-entry/e???????????????-*/*",
                "arn:aws:eks:*:*:addon/e???????????????-*/*/*"
            ]
        },
        {
            "Sid": "ElastiCacheAccess",
            "Effect": "Allow",
            "Action": [
                "elasticache:*"
            ],
            "Resource": [
                "arn:aws:elasticache:*:*:replicationgroup:e???????????????-*",
                "arn:aws:elasticache:*:*:parametergroup:e???????????????-*",
                "arn:aws:elasticache:*:*:subnetgroup:e???????????????-*"
            ]
        },
        {
            "Sid": "ELBAccess",
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "GlueAccess",
            "Effect": "Allow",
            "Action": [
                "glue:*"
            ],
            "Resource": [
                "arn:aws:glue:*:*:catalog",
                "arn:aws:glue:*:*:database/e???????????????-*",
                "arn:aws:glue:*:*:table/e???????????????-*/*"
            ]
        },
        {
            "Sid": "IAMAccess",
            "Effect": "Allow",
            "Action": [
                "iam:*"
            ],
            "Resource": [
                "arn:aws:iam::*:role/e???????????????-*",
                "arn:aws:iam::*:policy/e???????????????-*",
                "arn:aws:iam::*:instance-profile/e???????????????-*"
            ]
        },
        {
            "Sid": "IAMServiceLinkedRoleAccess",
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "arn:aws:iam::*:role/aws-service-role/*",
            "Condition": {
                "StringLike": {
                    "iam:AWSServiceName": [
                        "eks.amazonaws.com",
                        "eks-nodegroup.amazonaws.com",
                        "eks-fargate-pods.amazonaws.com",
                        "elasticloadbalancing.amazonaws.com",
                        "rds.amazonaws.com",
                        "elasticache.amazonaws.com",
                        "opensearchservice.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Sid": "KMSAccess",
            "Effect": "Allow",
            "Action": [
                "kms:*"
            ],
            "Resource": [
                "arn:aws:kms:*:*:key/*",
                "arn:aws:kms:*:*:alias/e???????????????-*"
            ]
        },
        {
            "Sid": "CloudWatchLogsAccess",
            "Effect": "Allow",
            "Action": [
                "logs:*"
            ],
            "Resource": [
                "arn:aws:logs:*:*:log-group:e???????????????-*",
                "arn:aws:logs:*:*:log-group:e???????????????-*:*",
                "arn:aws:logs:*:*:log-group:/aws/eks/e???????????????-*/*"
            ]
        },
        {
            "Sid": "RDSAccess",
            "Effect": "Allow",
            "Action": [
                "rds:*",
                "rds-db:*"
            ],
            "Resource": [
                "arn:aws:rds:*:*:db:e???????????????-*",
                "arn:aws:rds:*:*:cluster:e???????????????-*",
                "arn:aws:rds:*:*:pg:e???????????????-*",
                "arn:aws:rds:*:*:subgrp:e???????????????-*",
                "arn:aws:rds:*:*:es:e???????????????-*",
                "arn:aws:rds-db:*:*:dbuser:*/*"
            ]
        },
        {
            "Sid": "ResourceGroupsAccess",
            "Effect": "Allow",
            "Action": [
                "resource-groups:*"
            ],
            "Resource": "arn:aws:resource-groups:*:*:group/e???????????????-*"
        },
        {
            "Sid": "Route53Access",
            "Effect": "Allow",
            "Action": [
                "route53:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "S3Access",
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::e???????????????-*",
                "arn:aws:s3:::e???????????????-*/*"
            ]
        },
        {
            "Sid": "SecretsManagerAccess",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:*"
            ],
            "Resource": [
                "arn:aws:secretsmanager:*:*:secret:e???????????????-*",
                "arn:aws:secretsmanager:*:*:secret:mks*"
            ]
        },
        {
            "Sid": "SNSAccess",
            "Effect": "Allow",
            "Action": [
                "sns:*"
            ],
            "Resource": "arn:aws:sns:*:*:e???????????????-*"
        },
        {
            "Sid": "SQSAccess",
            "Effect": "Allow",
            "Action": [
                "sqs:*"
            ],
            "Resource": "arn:aws:sqs:*:*:e???????????????-*"
        },
        {
            "Sid": "STSAssumeRoleAccess",
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession",
                "sts:AssumeRoleWithWebIdentity"
            ],
            "Resource": "arn:aws:iam::*:role/e???????????????-*"
        },
        {
            "Sid": "STSIdentityAccess",
            "Effect": "Allow",
            "Action": [
                "sts:GetCallerIdentity",
                "sts:DecodeAuthorizationMessage",
                "sts:GetAccessKeyInfo"
            ],
            "Resource": "*"
        },
        {
            "Sid": "TaggingAccess",
            "Effect": "Allow",
            "Action": [
                "tag:*"
            ],
            "Resource": "*"
        }
    ]
}
```

If the pre-flight decision was to drop `resource-groups`, remove the `ResourceGroupsAccess` statement block above before writing the file.

- [ ] **Step 2: Verify the file is valid JSON**

Run: `python3 -c "import json; json.load(open('policy.json'))" && echo OK`
Expected: `OK`

- [ ] **Step 3: Sanity-check the statement count and SIDs**

Run: `python3 -c "import json; p=json.load(open('policy.json')); print(len(p['Statement'])); print('\n'.join(s['Sid'] for s in p['Statement']))"`
Expected (if `ResourceGroupsAccess` kept): `25` followed by the 25 SIDs listed in Step 1, in order. If dropped: `24`.

- [ ] **Step 4: Commit**

```bash
git add policy.json
git commit -m "Narrow policy.json: remove 12 unused services and scope resources to ent-platform prefix"
```

---

## Task 2: Mirror narrowed policy into `terraform/main.tf`

**Files:**
- Modify: `terraform/main.tf:14-228` (replace the entire `aws_iam_policy.ent_deploy_permissions` resource block)

- [ ] **Step 1: Replace the `aws_iam_policy "ent_deploy_permissions"` resource block**

Locate the existing block (starts at `resource "aws_iam_policy" "ent_deploy_permissions" {` on line 14, ends at the closing `}` on line 228). Replace it with the block below. Leave the surrounding `data "aws_iam_policy_document"` (lines 1-12) and `aws_iam_role` / `aws_iam_role_policy_attachment` blocks (lines 230-243) untouched.

```hcl
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
```

If the pre-flight decision was to drop `resource-groups`, remove the `ResourceGroupsAccess` block before writing.

- [ ] **Step 2: Initialize and validate the Terraform module**

Run:
```bash
cd terraform
terraform init -backend=false
terraform validate
cd ..
```
Expected: `Success! The configuration is valid.`

If `terraform` is not installed, try `tofu init -backend=false && tofu validate` — OpenTofu is a drop-in replacement and the README says the module supports it.

- [ ] **Step 3: Render the policy to JSON and compare SID lists with `policy.json`**

Run:
```bash
python3 <<'EOF'
import json, re, subprocess
with open('policy.json') as f: pj = json.load(f)
with open('terraform/main.tf') as f: tf = f.read()
tf_sids = re.findall(r'Sid\s*=\s*"([^"]+)"', tf)
pj_sids = [s['Sid'] for s in pj['Statement']]
print('policy.json:', pj_sids)
print('terraform :', tf_sids)
print('match' if pj_sids == tf_sids else 'MISMATCH')
EOF
```
Expected: `match`.

- [ ] **Step 4: Commit**

```bash
git add terraform/main.tf
git commit -m "Mirror narrowed policy into terraform/main.tf"
```

---

## Task 3: Mirror narrowed policy into `cloudformation/template.yaml`

**Files:**
- Modify: `cloudformation/template.yaml:34-213` (replace the `EntDeployPolicy` resource's `Statement` list)

- [ ] **Step 1: Replace the `Statement` block inside the `EntDeployPolicy` resource**

Locate the `EntDeployPolicy` resource (starts at line 34). Inside it, replace the entire `Statement:` YAML list (starting at line 42 with `Statement:` and ending at line 213 with the last `Resource: '*'` for `XRayAccess`) with the block below. Keep `ManagedPolicyName`, `Description`, `Path`, `Version` lines and everything else unchanged.

```yaml
        Statement:
          - Sid: CertificateManagerAccess
            Effect: Allow
            Action:
              - acm:*
            Resource: '*'
          - Sid: AthenaAccess
            Effect: Allow
            Action:
              - athena:*
            Resource:
              - arn:aws:athena:*:*:workgroup/e???????????????-*
              - arn:aws:athena:*:*:datacatalog/e???????????????-*
          - Sid: BedrockAccess
            Effect: Allow
            Action:
              - bedrock:*
            Resource:
              - arn:aws:bedrock:*:*:inference-profile/*
              - arn:aws:bedrock:*:*:application-inference-profile/*
          - Sid: CostAndUsageReportReadAccess
            Effect: Allow
            Action:
              - cur:Describe*
              - cur:Get*
            Resource: '*'
          - Sid: CloudWatchAccess
            Effect: Allow
            Action:
              - cloudwatch:*
            Resource:
              - arn:aws:cloudwatch:*:*:alarm:e???????????????-*
          - Sid: EC2Access
            Effect: Allow
            Action:
              - ec2:*
            Resource: '*'
          - Sid: ECRAccess
            Effect: Allow
            Action:
              - ecr:*
            Resource: arn:aws:ecr:*:*:repository/e???????????????-*
          - Sid: EKSAccess
            Effect: Allow
            Action:
              - eks:*
            Resource:
              - arn:aws:eks:*:*:cluster/e???????????????-*
              - arn:aws:eks:*:*:nodegroup/e???????????????-*/*/*
              - arn:aws:eks:*:*:access-entry/e???????????????-*/*
              - arn:aws:eks:*:*:addon/e???????????????-*/*/*
          - Sid: ElastiCacheAccess
            Effect: Allow
            Action:
              - elasticache:*
            Resource:
              - arn:aws:elasticache:*:*:replicationgroup:e???????????????-*
              - arn:aws:elasticache:*:*:parametergroup:e???????????????-*
              - arn:aws:elasticache:*:*:subnetgroup:e???????????????-*
          - Sid: ELBAccess
            Effect: Allow
            Action:
              - elasticloadbalancing:*
            Resource: '*'
          - Sid: GlueAccess
            Effect: Allow
            Action:
              - glue:*
            Resource:
              - arn:aws:glue:*:*:catalog
              - arn:aws:glue:*:*:database/e???????????????-*
              - arn:aws:glue:*:*:table/e???????????????-*/*
          - Sid: IAMAccess
            Effect: Allow
            Action:
              - iam:*
            Resource:
              - arn:aws:iam::*:role/e???????????????-*
              - arn:aws:iam::*:policy/e???????????????-*
              - arn:aws:iam::*:instance-profile/e???????????????-*
          - Sid: IAMServiceLinkedRoleAccess
            Effect: Allow
            Action:
              - iam:CreateServiceLinkedRole
            Resource: arn:aws:iam::*:role/aws-service-role/*
            Condition:
              StringLike:
                iam:AWSServiceName:
                  - eks.amazonaws.com
                  - eks-nodegroup.amazonaws.com
                  - eks-fargate-pods.amazonaws.com
                  - elasticloadbalancing.amazonaws.com
                  - rds.amazonaws.com
                  - elasticache.amazonaws.com
                  - opensearchservice.amazonaws.com
          - Sid: KMSAccess
            Effect: Allow
            Action:
              - kms:*
            Resource:
              - arn:aws:kms:*:*:key/*
              - arn:aws:kms:*:*:alias/e???????????????-*
          - Sid: CloudWatchLogsAccess
            Effect: Allow
            Action:
              - logs:*
            Resource:
              - arn:aws:logs:*:*:log-group:e???????????????-*
              - arn:aws:logs:*:*:log-group:e???????????????-*:*
              - arn:aws:logs:*:*:log-group:/aws/eks/e???????????????-*/*
          - Sid: RDSAccess
            Effect: Allow
            Action:
              - rds:*
              - rds-db:*
            Resource:
              - arn:aws:rds:*:*:db:e???????????????-*
              - arn:aws:rds:*:*:cluster:e???????????????-*
              - arn:aws:rds:*:*:pg:e???????????????-*
              - arn:aws:rds:*:*:subgrp:e???????????????-*
              - arn:aws:rds:*:*:es:e???????????????-*
              - arn:aws:rds-db:*:*:dbuser:*/*
          - Sid: ResourceGroupsAccess
            Effect: Allow
            Action:
              - resource-groups:*
            Resource: arn:aws:resource-groups:*:*:group/e???????????????-*
          - Sid: Route53Access
            Effect: Allow
            Action:
              - route53:*
            Resource: '*'
          - Sid: S3Access
            Effect: Allow
            Action:
              - s3:*
            Resource:
              - arn:aws:s3:::e???????????????-*
              - arn:aws:s3:::e???????????????-*/*
          - Sid: SecretsManagerAccess
            Effect: Allow
            Action:
              - secretsmanager:*
            Resource:
              - arn:aws:secretsmanager:*:*:secret:e???????????????-*
              - arn:aws:secretsmanager:*:*:secret:mks*
          - Sid: SNSAccess
            Effect: Allow
            Action:
              - sns:*
            Resource: arn:aws:sns:*:*:e???????????????-*
          - Sid: SQSAccess
            Effect: Allow
            Action:
              - sqs:*
            Resource: arn:aws:sqs:*:*:e???????????????-*
          - Sid: STSAssumeRoleAccess
            Effect: Allow
            Action:
              - sts:AssumeRole
              - sts:TagSession
              - sts:AssumeRoleWithWebIdentity
            Resource: arn:aws:iam::*:role/e???????????????-*
          - Sid: STSIdentityAccess
            Effect: Allow
            Action:
              - sts:GetCallerIdentity
              - sts:DecodeAuthorizationMessage
              - sts:GetAccessKeyInfo
            Resource: '*'
          - Sid: TaggingAccess
            Effect: Allow
            Action:
              - tag:*
            Resource: '*'
```

If the pre-flight decision was to drop `resource-groups`, remove the `ResourceGroupsAccess` block before writing.

- [ ] **Step 2: Verify the file is valid YAML**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('cloudformation/template.yaml')); print('OK')"
```
Expected: `OK`. If Python's `yaml` module is missing, install with `pip3 install pyyaml` or use `python3 -c "import json, subprocess; print(subprocess.check_output(['yq', '.', 'cloudformation/template.yaml']).decode()[:50])"`.

- [ ] **Step 3: Validate as a CloudFormation template**

Preferred (requires AWS CLI + credentials):
```bash
aws cloudformation validate-template --template-body file://cloudformation/template.yaml
```
Expected: JSON output with `Parameters` and `Description` keys, no `Error` field.

Alternative (no AWS creds, install if absent with `pip3 install cfn-lint`):
```bash
cfn-lint cloudformation/template.yaml
```
Expected: no output (exit 0).

- [ ] **Step 4: Confirm SID list matches `policy.json`**

Run:
```bash
python3 <<'EOF'
import json, yaml
with open('policy.json') as f: pj = json.load(f)
with open('cloudformation/template.yaml') as f: cfn = yaml.safe_load(f)
pj_sids = [s['Sid'] for s in pj['Statement']]
cfn_sids = [s['Sid'] for s in cfn['Resources']['EntDeployPolicy']['Properties']['PolicyDocument']['Statement']]
print('policy.json:', pj_sids)
print('cloudform  :', cfn_sids)
print('match' if pj_sids == cfn_sids else 'MISMATCH')
EOF
```
Expected: `match`.

- [ ] **Step 5: Commit**

```bash
git add cloudformation/template.yaml
git commit -m "Mirror narrowed policy into cloudformation/template.yaml"
```

---

## Task 4: Verify the three representations are semantically equivalent

**Files:**
- No file changes unless drift is found.

- [ ] **Step 1: Verify SID order matches across all three representations and `policy.json` equals `cloudformation/template.yaml` statement-for-statement**

Run:
```bash
python3 <<'EOF'
import json, yaml, re

def norm(stmt_list):
    def k(x):
        if isinstance(x, list):
            return tuple(sorted(str(i) for i in x))
        return str(x)
    return [{
        'Sid': s['Sid'],
        'Effect': s['Effect'],
        'Action': k(s['Action']),
        'Resource': k(s['Resource']),
        'Condition': json.dumps(s.get('Condition', {}), sort_keys=True),
    } for s in stmt_list]

pj = norm(json.load(open('policy.json'))['Statement'])
cfn = norm(yaml.safe_load(open('cloudformation/template.yaml'))['Resources']['EntDeployPolicy']['Properties']['PolicyDocument']['Statement'])
tf_sids = re.findall(r'Sid\s*=\s*"([^"]+)"', open('terraform/main.tf').read())

print('SIDs  (policy.json)  :', [s['Sid'] for s in pj])
print('SIDs  (cloudform)    :', [s['Sid'] for s in cfn])
print('SIDs  (terraform)    :', tf_sids)

ok = [s['Sid'] for s in pj] == [s['Sid'] for s in cfn] == tf_sids
print('SID order match:', 'OK' if ok else 'MISMATCH')

if pj == cfn:
    print('policy.json == cloudformation: OK')
else:
    print('policy.json != cloudformation: MISMATCH')
    for a, b in zip(pj, cfn):
        if a != b:
            print('  diff:', a['Sid'])
            print('   pj :', a)
            print('   cfn:', b)
EOF
```
Expected: three SID lists identical in order, both `SID order match: OK` and `policy.json == cloudformation: OK`. Terraform's deep equivalence is covered by Task 2 (`terraform validate` + SID check) plus the pattern spot-check in Step 2 below.

- [ ] **Step 2: Terraform — spot-check representative Resource lines match policy.json**

Run:
```bash
for pat in \
  "arn:aws:s3:::e???????????????-*" \
  "arn:aws:eks:*:*:cluster/e???????????????-*" \
  "arn:aws:iam::*:role/e???????????????-*" \
  "arn:aws:iam::*:role/aws-service-role/*" \
  "arn:aws:secretsmanager:*:*:secret:mks*" \
  "sts:GetCallerIdentity"
do
  grep -q -F "$pat" terraform/main.tf && grep -q -F "$pat" policy.json && grep -q -F "$pat" cloudformation/template.yaml && echo "OK  $pat" || echo "MISS $pat"
done
```
Expected: `OK` for every row.

- [ ] **Step 3: If everything matches, no commit needed.** If drift found, fix the drifted file, re-run Step 1, and commit with message `Fix drift between policy representations`.

---

## Task 5: Update `README.md`

**Files:**
- Modify: `README.md:181-221` (the Permissions table + surrounding text)

- [ ] **Step 1: Replace the `## Permissions` section (starting line 181) through end-of-file with the block below**

```markdown
## Permissions

This role grants scoped access to the AWS services below. Each statement is constrained in one of three ways: (a) scoped to resource ARNs that match `ent-platform`'s auto-generated name prefix, (b) retained unscoped because the AWS service does not support resource-level permissions for the calls Ent needs, or (c) filtered to a read-only or service-linked-role subset.

| Service | Actions | Resource scope |
|---------|---------|----------------|
| ACM | `acm:*` | unscoped (ACM certificates have auto-generated UUIDs) |
| Athena | `athena:*` | workgroups/datacatalogs prefixed `e???????????????-` |
| Bedrock | `bedrock:*` | inference-profile resource types (UUIDs) |
| Cost and Usage Report (read-only) | `cur:Describe*`, `cur:Get*` | unscoped |
| CloudWatch | `cloudwatch:*` | alarms prefixed `e???????????????-` |
| EC2 | `ec2:*` | unscoped (VPC primitives don't support resource-level permissions) |
| ECR | `ecr:*` | repositories prefixed `e???????????????-` |
| EKS | `eks:*` | clusters/nodegroups/addons/access-entries prefixed `e???????????????-` |
| ElastiCache | `elasticache:*` | replication/parameter/subnet groups prefixed `e???????????????-` |
| ELB | `elasticloadbalancing:*` | unscoped (ALB Controller creates LBs with dynamic names) |
| Glue | `glue:*` | catalog + databases/tables prefixed `e???????????????-` |
| IAM | `iam:*` | roles/policies/instance-profiles prefixed `e???????????????-` |
| IAM (service-linked) | `iam:CreateServiceLinkedRole` | `aws:AWSServiceName` allowlist: EKS, ELB, RDS, ElastiCache, OpenSearch |
| KMS | `kms:*` | aliases prefixed `e???????????????-` (keys have UUIDs) |
| CloudWatch Logs | `logs:*` | log-groups prefixed `e???????????????-` |
| RDS | `rds:*`, `rds-db:*` | DB/cluster/parameter/subnet/event resources prefixed `e???????????????-` |
| Resource Groups | `resource-groups:*` | groups prefixed `e???????????????-` |
| Route 53 | `route53:*` | unscoped (hosted-zone list APIs don't support resource-level) |
| S3 | `s3:*` | buckets prefixed `e???????????????-` |
| Secrets Manager | `secretsmanager:*` | secrets prefixed `e???????????????-` or `mks` (macOS SSH keys) |
| SNS | `sns:*` | topics prefixed `e???????????????-` |
| SQS | `sqs:*` | queues prefixed `e???????????????-` |
| STS (assume role) | `sts:AssumeRole`, `sts:TagSession`, `sts:AssumeRoleWithWebIdentity` | roles prefixed `e???????????????-` |
| STS (identity) | `sts:GetCallerIdentity`, `sts:DecodeAuthorizationMessage`, `sts:GetAccessKeyInfo` | unscoped (these calls don't take resources) |
| Resource Tagging API | `tag:*` | unscoped (multi-resource API) |

### Resource scoping

Most resources that Ent provisions in your account are named with an auto-generated prefix of the form:

```
e[0-9a-f]{15}-
```

(The literal letter `e`, fifteen lowercase hex characters, and a hyphen — for example `e1a2b3c4d5e6f78-`.) The prefix is a SHA-256 of the tenant, environment, and region, produced at deploy time by Ent's Deployment service. The IAM policy uses the glob `e???????????????-*` to match exactly this shape.

**Cross-repo dependency:** this policy assumes the prefix generator in `ent-platform`'s `deploy/tofu/platform/regional.tf`. If that formula changes shape in a future Ent release, the policy must be updated in lockstep or new deployments will fail with `AccessDenied`.

### Services not granted

For transparency, the following services were intentionally excluded from this role because they are not used by Ent:

AOSS (OpenSearch Serverless), BCM Data Exports, Cost Explorer, Cognito IDP, Amazon Managed Grafana, Kendra, Lambda, SageMaker, Shield, WAFv2, X-Ray, and the write surface of Cost and Usage Reports (`cur` beyond `Describe*`/`Get*`).

If you enable an Ent feature that later requires one of these, add a scoped statement for it and re-deploy.
```

- [ ] **Step 2: Verify the README renders cleanly**

Run: `python3 -c "import re; open('README.md').read()"` — no-op but ensures the file is readable.
Optional: preview with a Markdown viewer of your choice to confirm the table renders.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Document narrowed permissions, resource scoping, and excluded services in README"
```

---

## Task 6: Optional — IAM Policy Simulator verification

This task is optional and requires AWS credentials (any account). `simulate-custom-policy` evaluates the policy document inline — no policy needs to be created in IAM, so there is no cleanup step.

**Files:**
- No file changes.

- [ ] **Step 1: Set up inputs**

```bash
POLICY=$(python3 -c "import json; print(json.dumps(json.load(open('policy.json'))))")
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
```

`--policy-input-list` accepts policy documents as inline strings; the multiline file content needs compacting first or the shell will trip on embedded newlines and quotes.

- [ ] **Step 2: Simulate representative allowed calls (should all return `allowed`)**

```bash
for spec in \
  "s3:CreateBucket::arn:aws:s3:::e1a2b3c4d5e6f78-tfstate" \
  "eks:CreateCluster::arn:aws:eks:us-east-1:${ACCOUNT}:cluster/e1a2b3c4d5e6f78-home-prod" \
  "ecr:PutImage::arn:aws:ecr:us-east-1:${ACCOUNT}:repository/e1a2b3c4d5e6f78-ent-home-api" \
  "rds:CreateDBInstance::arn:aws:rds:us-east-1:${ACCOUNT}:db:e1a2b3c4d5e6f78-db" \
  "secretsmanager:GetSecretValue::arn:aws:secretsmanager:us-east-1:${ACCOUNT}:secret:mks-ssh-abc"
do
  action=${spec%%::*}; arn=${spec##*::}
  decision=$(aws iam simulate-custom-policy \
    --policy-input-list "$POLICY" \
    --action-names "$action" \
    --resource-arns "$arn" \
    --query 'EvaluationResults[0].EvalDecision' --output text)
  echo "$decision  $action  $arn"
done
```
Expected: every line prints `allowed`.

- [ ] **Step 3: Simulate representative denied calls (should all return `implicitDeny`)**

```bash
for spec in \
  "s3:CreateBucket::arn:aws:s3:::some-random-customer-bucket" \
  "eks:CreateCluster::arn:aws:eks:us-east-1:${ACCOUNT}:cluster/production-cluster" \
  "lambda:CreateFunction::arn:aws:lambda:us-east-1:${ACCOUNT}:function:my-fn"
do
  action=${spec%%::*}; arn=${spec##*::}
  decision=$(aws iam simulate-custom-policy \
    --policy-input-list "$POLICY" \
    --action-names "$action" \
    --resource-arns "$arn" \
    --query 'EvaluationResults[0].EvalDecision' --output text)
  echo "$decision  $action  $arn"
done
```
Expected: every line prints `implicitDeny`.

- [ ] **Step 4: (No commit.) Paste the simulator output into the PR description.**

---

## PR preparation

Before opening the PR, confirm:

- [ ] `git log --oneline main..HEAD` shows four commits (Task 1, 2, 3, 5). Six if Task 4 or 6 required drift fixes.
- [ ] `resource-groups` decision has been made (see Pre-flight).
- [ ] PR description includes: the set of services removed, the ARN scoping pattern, the cross-repo dependency on `ent-platform`'s prefix generator, and the v2.0.0 intent.
- [ ] PR description calls out the staging-deploy verification as a pre-merge gate (the IAM simulator is a useful sanity check but not a full replacement for an end-to-end deploy).
