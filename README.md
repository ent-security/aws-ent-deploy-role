# aws-ent-deploy-role

Infrastructure as Code to create the Ent Security Deployment Role in AWS. Supports Terraform (including OpenTofu), CloudFormation, AWS CDK (TypeScript and Python), and Pulumi (TypeScript, Python, and Go).

## Terraform Usage

**Note** the example below uses `ref=main`. It is recommended to pin this module to a specific tag version (i.e. `ref=1.0.0`) to avoid breaking changes. See the [releases page](https://github.com/ent-security/aws-ent-deploy-role/releases) for a list of published versions.

```hcl
module "ent_deployment_role" {
  source = "git::https://github.com/ent-security/aws-ent-deploy-role//terraform?ref=main"
}

# this will output the Role ARN
output "ent_deployment_role" {
  value = module.ent_deployment_role.role_arn
}
```

After you apply this terraform, it will output the Role ARN that you can paste into the AWS connection panel in Ent to initiate the connection.

### Deploying with Terraform / OpenTofu

The Terraform module in this repository works unmodified with [OpenTofu](https://opentofu.org/) — the open-source fork of Terraform. Anywhere the instructions below say `terraform`, you can substitute `tofu` and get the same result.

If you want to deploy the module directly (e.g. from a local clone), you can use either tool:

```bash
cd terraform/
# Initialize providers
terraform init    # or: tofu init

# Preview the changes
terraform plan    # or: tofu plan

# Apply (review the plan output before confirming)
terraform apply   # or: tofu apply
```

To customize the deployment, create a `terraform.tfvars` file:

```hcl
role_name           = "HomeProdAssumeAdmin"
ent_aws_account_arn = "arn:aws:iam::123456789012:root"
tags = {
  Environment = "production"
  ManagedBy   = "terraform"
}
```

### Terraform Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `ent_aws_account_arn` | Ent's AWS account ARN | (provided by module) | No |
| `role_sts_external_id` | STS ExternalId condition value. When non-empty, Ent Home must supply this value in its AssumeRole call. Empty string means no ExternalId constraint (not recommended for production). | `""` | No |
| `role_name` | IAM role name | `HomeProdAssumeAdmin` | No |
| `role_path` | Path of IAM role | `/` | No |
| `role_description` | IAM Role description | (provided by module) | No |
| `tags` | A map of tags to add to IAM role resources | `{}` | No |

### Terraform Outputs

| Output | Description |
|--------|-------------|
| `role_arn` | The ARN of the role |
| `role_name` | The name of the role |
| `policy_arn` | The ARN of the policy |

### Requirements

- Terraform >= 0.13.0
- AWS Provider >= 3.1.15

## CloudFormation Usage

Deploy using the AWS CLI:

```bash
aws cloudformation deploy \
  --template-file cloudformation/template.yaml \
  --stack-name ent-deploy-role \
  --capabilities CAPABILITY_NAMED_IAM
```

Or deploy via the AWS Console:
1. Navigate to CloudFormation in the AWS Console
2. Click "Create stack" > "With new resources"
3. Upload the `cloudformation/template.yaml` file
4. Fill in the parameters and deploy

### CloudFormation Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `EntAwsAccountArn` | The AWS ARN that can assume this role | (provided by template) | No |
| `RoleName` | IAM role name | `HomeProdAssumeAdmin` | No |
| `RolePath` | Path of IAM role | `/` | No |
| `RoleDescription` | IAM Role description | (provided by template) | No |

### CloudFormation Outputs

| Output | Description |
|--------|-------------|
| `RoleArn` | The ARN of the role |
| `RoleName` | The name of the role |
| `PolicyArn` | The ARN of the policy |

## CDK Usage

This repository ships standalone CDK v2 apps in TypeScript and Python. Both read the authoritative `policy.json` and `role.json` at synthesis time.

### CDK TypeScript

```bash
cd cdk/typescript
npm install
npx cdk bootstrap   # one-time per account/region
npx cdk deploy \
  -c ent_aws_account_arn=arn:aws:iam::123456789012:root \
  -c role_name=HomeProdAssumeAdmin
```

See [`cdk/typescript/README.md`](./cdk/typescript/README.md) for full usage.

### CDK Python

```bash
cd cdk/python
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cdk bootstrap
cdk deploy \
  -c ent_aws_account_arn=arn:aws:iam::123456789012:root \
  -c role_name=HomeProdAssumeAdmin
```

See [`cdk/python/README.md`](./cdk/python/README.md) for full usage.

### CDK Configuration

| Key | Description | Default |
|---|---|---|
| `ent_aws_account_arn` | Ent's AWS account ARN | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
| `role_name` | IAM role name | `HomeProdAssumeAdmin` |
| `role_path` | IAM role path | `/` |
| `role_description` | IAM role description | (matches Terraform default) |

### CDK Outputs

| Output | Description |
|---|---|
| `RoleArn` | The ARN of the role |
| `RoleName` | The name of the role |
| `PolicyArn` | The ARN of the policy |

## Pulumi Usage

This repository ships standalone Pulumi programs in TypeScript, Python, and Go. All three read the authoritative `policy.json` and `role.json` at deploy time.

### Pulumi TypeScript

```bash
cd pulumi/typescript
npm install
pulumi stack init dev
pulumi config set ent-deploy-role:entAwsAccountArn arn:aws:iam::123456789012:root
pulumi up
```

See [`pulumi/typescript/README.md`](./pulumi/typescript/README.md) for full usage.

### Pulumi Python

```bash
cd pulumi/python
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pulumi stack init dev
pulumi config set ent-deploy-role:entAwsAccountArn arn:aws:iam::123456789012:root
pulumi up
```

See [`pulumi/python/README.md`](./pulumi/python/README.md) for full usage.

### Pulumi Go

```bash
cd pulumi/go
go mod tidy
pulumi stack init dev
pulumi config set ent-deploy-role:entAwsAccountArn arn:aws:iam::123456789012:root
pulumi up
```

See [`pulumi/go/README.md`](./pulumi/go/README.md) for full usage.

### Pulumi Configuration

| Key | Description | Default |
|---|---|---|
| `entAwsAccountArn` | Ent's AWS account ARN | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
| `roleName` | IAM role name | `HomeProdAssumeAdmin` |
| `rolePath` | IAM role path | `/` |
| `roleDescription` | IAM role description | (matches Terraform default) |
| `tags` | Map of tags (set with `--path`) | `{}` |

### Pulumi Outputs

| Output | Description |
|---|---|
| `roleArn` | The ARN of the role |
| `roleName` | The name of the role |
| `policyArn` | The ARN of the policy |

## AWS CLI Usage

Deploy using the AWS CLI with the provided `role.json` and `policy.json` files:

1. Update `role.json` with your Ent AWS Account ARN:

```bash
sed -i '' 's/<ENT_AWS_ACCOUNT_ARN>/YOUR_ENT_AWS_ACCOUNT_ARN/' role.json
```

2. Create the IAM role:

```bash
aws iam create-role \
  --role-name HomeProdAssumeAdmin \
  --path / \
  --description "Role that allows HomeDev SSO to assume EntHomePermissions role" \
  --assume-role-policy-document file://role.json
```

3. Create the IAM policy:

```bash
aws iam create-policy \
  --policy-name EntHomePermissions \
  --policy-document file://policy.json
```

4. Attach the policy to the role:

```bash
aws iam attach-role-policy \
  --role-name HomeProdAssumeAdmin \
  --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/EntHomePermissions"
```

## Setup

The following steps demonstrate how to connect AWS in Ent when using this module.

### Terraform

1. Add the code above to your terraform code
2. Replace `main` in `ref=main` with the latest version from the [releases page](https://github.com/ent-security/aws-ent-deploy-role/releases)
3. In your browser, open the AWS connection settings page in Ent
4. Back in your terminal, run `terraform init` to download/update the module
5. Run `terraform apply` and **IMPORTANT** review the plan output before typing `yes`
6. When the terraform is applied, it will output the Role ARN, copy the ARN
7. Paste the Role ARN into the Role ARN field in the AWS Connections drawer in Ent
8. Click the `Save & Test Connection` button

### CloudFormation

1. Open the AWS connection settings page in Ent
2. Deploy the CloudFormation stack
3. Once deployed, find the Role ARN in the stack Outputs
4. Paste the Role ARN into the Role ARN field in the AWS Connections drawer in Ent
5. Click the `Save & Test Connection` button

### CDK

1. Open the AWS connection settings page in Ent
2. Pick a CDK variant (TypeScript or Python) and follow its README to install prerequisites
3. Run `cdk deploy -c ent_aws_account_arn=<your-arn> -c role_name=<name>`
4. Copy the `RoleArn` stack output
5. Paste the Role ARN into the Role ARN field in the AWS Connections drawer in Ent
6. Click the `Save & Test Connection` button

### Pulumi

1. Open the AWS connection settings page in Ent
2. Pick a Pulumi variant (TypeScript, Python, or Go) and follow its README to install prerequisites
3. Run `pulumi config set ent-deploy-role:entAwsAccountArn <your-arn>` then `pulumi up`
4. Copy the `roleArn` stack output
5. Paste the Role ARN into the Role ARN field in the AWS Connections drawer in Ent
6. Click the `Save & Test Connection` button

## Directory Structure

```
aws-ent-deploy-role/
├── cdk/
│   ├── typescript/
│   └── python/
├── cloudformation/
│   └── template.yaml
├── pulumi/
│   ├── typescript/
│   ├── python/
│   └── go/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── role.json
├── policy.json
└── README.md
```

## Permissions

This role grants scoped access to the AWS services below. Each statement is constrained in one of three ways: (a) scoped to resource ARNs that match `ent-platform`'s auto-generated name prefix, (b) retained unscoped because the AWS service does not support resource-level permissions for the calls Ent needs, or (c) filtered to a read-only or service-linked-role subset.

| Service | Actions | Resource scope |
|---------|---------|----------------|
| ACM | `acm:*` | unscoped (ACM certificates have auto-generated UUIDs) |
| Athena | `athena:*` | workgroups/datacatalogs prefixed `e???????????????-` |
| BCM Data Exports | `bcm-data-exports:*` | export and table resource types (CUR export reads from AWS-managed `table/COST_AND_USAGE_REPORT`) |
| Bedrock | `bedrock:*` | inference-profile resource types (UUIDs) + AWS-owned foundation-models (needed by `CreateInferenceProfile`) |
| Cost and Usage Report | `cur:Describe*`, `cur:Get*`, `cur:PutReportDefinition` | unscoped (BCM Data Exports' `CreateExport` internally calls the legacy `cur:PutReportDefinition` API) |
| CloudWatch | `cloudwatch:*` | alarms prefixed `e???????????????-` |
| EC2 | `ec2:*` | unscoped (VPC primitives don't support resource-level permissions) |
| ECR | `ecr:*` | repositories prefixed `e???????????????-` |
| ECR (auth token) | `ecr:GetAuthorizationToken` | unscoped (action does not support resource-level permissions) |
| EFS | `elasticfilesystem:*` | file-systems and access-points (IDs are auto-generated like KMS keys) |
| EKS | `eks:*` | clusters/nodegroups/addons/access-entries/pod-identity-associations prefixed `e???????????????-` |
| EKS (addon versions) | `eks:DescribeAddonVersions` | unscoped (account-level API; `aws_eks_addon_version` data source reads it for metrics-server/adot/ebs-csi/cert-manager/pod-identity-agent) |
| ElastiCache | `elasticache:*` | cache-clusters + replication/parameter/subnet groups prefixed `e???????????????-` |
| ELB | `elasticloadbalancing:*` | unscoped (ALB Controller creates LBs with dynamic names) |
| Glue | `glue:*` | catalog + databases/tables prefixed `e???????????????` (Glue databases disallow hyphens so `ent-platform` substitutes `_`, e.g. `e96f0ec181aeb8f6_cur`) |
| IAM | `iam:*` | roles/policies/instance-profiles prefixed `e???????????????-`; also `policy/AmazonEKS_*` (EKS pod-identity module creates `AmazonEKS_EBS_CSI-<timestamp>` directly) and `oidc-provider/oidc.eks.*.amazonaws.com/*` (EKS IRSA OIDC providers) |
| IAM (session context) | `iam:GetRole` | unscoped (Terraform's `aws_iam_session_context` reads the deploy role itself, which does not match the `e???????????????-` prefix) |
| IAM (service-linked) | `iam:CreateServiceLinkedRole` | `iam:AWSServiceName` allowlist: EKS, ELB, RDS, ElastiCache, OpenSearch, Backup, EFS (EFS `PutBackupPolicy` creates both `AWSServiceRoleForBackup` and `AWSServiceRoleForAmazonElasticFileSystem` on first use) |
| KMS | `kms:*` | aliases prefixed `e???????????????-` or `eks/e???????????????-` (keys have UUIDs) |
| KMS (account-level) | `kms:CreateKey`, `kms:ListAliases` | unscoped (neither action supports resource-level permissions) |
| CloudWatch Logs | `logs:*` | log-groups prefixed `e???????????????-`, `/aws/*/e???????????????-*` (AWS-service-managed paths for RDS/ElastiCache/flow-logs/EKS), and `/<tenant-uuid>/*` (e.g. CloudTrail CIS-alarms log group created under `/<tenant_id>/aws/cloudtrail/…`) |
| CloudWatch Logs (describe) | `logs:DescribeLogGroups`, `logs:DescribeLogStreams` | unscoped (describe APIs don't support resource-level permissions) |
| RDS | `rds:*`, `rds-db:*` | DB/cluster/parameter/subnet/event resources prefixed `e???????????????-`, plus event-subscriptions prefixed `db-event-sub-` (hardcoded default name in `ent-platform`'s `db_event_subscription` module) |
| RDS (describe) | `rds:DescribeDBInstances` | unscoped (terraform provider calls this against `db:*` rather than a specific instance ARN) |
| Resource Groups | `resource-groups:*` | groups prefixed `e???????????????-` |
| Route 53 | `route53:*` | unscoped (hosted-zone list APIs don't support resource-level) |
| S3 | `s3:*` | buckets prefixed `e???????????????-` |
| S3 (list buckets) | `s3:ListAllMyBuckets` | unscoped (account-level API; Terraform's `aws_canonical_user_id` data source calls it and it doesn't support resource-level permissions) |
| Secrets Manager | `secretsmanager:*` | secrets prefixed `e???????????????-`, `mks` (macOS SSH keys), `rds!` (RDS-managed master-password secrets), or `grafana/<tenant-uuid>-<env>/*` (Grafana OAuth config in `platform-monitoring`) |
| SNS | `sns:*` | topics prefixed `e???????????????-` and `db-event-notifications` (hardcoded default in `ent-platform`'s `db_event_subscription` module) |
| SQS | `sqs:*` | queues prefixed `e???????????????-` |
| STS (assume role) | `sts:AssumeRole`, `sts:TagSession`, `sts:AssumeRoleWithWebIdentity` | roles prefixed `e???????????????-` |
| STS (identity) | `sts:GetCallerIdentity`, `sts:DecodeAuthorizationMessage`, `sts:GetAccessKeyInfo` | unscoped (these calls don't take resources) |
| WAFv2 | `wafv2:*` | regional/global web-ACLs prefixed `e???????????????-` |
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

AOSS (OpenSearch Serverless), Cost Explorer, Cognito IDP, Amazon Managed Grafana, Kendra, Lambda, SageMaker, Shield, X-Ray, and the write surface of Cost and Usage Reports (`cur` beyond `Describe*`/`Get*`).

If you enable an Ent feature that later requires one of these, add a scoped statement for it and re-deploy.
