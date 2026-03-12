# aws-ent-deploy-role

Infrastructure as Code to create the Ent Security Deployment Role in AWS. Supports both Terraform and CloudFormation.

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

### Terraform Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `ent_aws_account_arn` | Ent's AWS account ARN | (provided by module) | No |
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

## Directory Structure

```
aws-ent-deploy-role/
├── cloudformation/
│   └── template.yaml
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

This role grants full access to the following AWS services:

| Service | Actions |
|---------|---------|
| ACM | `acm:*` |
| Athena | `athena:*` |
| Bedrock | `bedrock:*` |
| BCM Data Exports | `bcm-data-exports:*` |
| CloudWatch | `cloudwatch:*` |
| CloudWatch Logs | `logs:*` |
| Cognito | `cognito-idp:*` |
| Cost Explorer | `ce:*` |
| EC2 | `ec2:*` |
| ECR | `ecr:*` |
| EKS | `eks:*` |
| ElastiCache | `elasticache:*` |
| ELB | `elasticloadbalancing:*` |
| Glue | `glue:*` |
| Grafana | `grafana:*` |
| IAM | `iam:*` |
| Kendra | `kendra:*` |
| KMS | `kms:*` |
| Lambda | `lambda:*` |
| OpenSearch Serverless | `aoss:*` |
| RDS | `rds:*`, `rds-db:*` |
| Resource Groups | `resource-groups:*` |
| Resource Tagging | `tag:*` |
| Route 53 | `route53:*` |
| S3 | `s3:*` |
| SageMaker | `sagemaker:*` |
| Secrets Manager | `secretsmanager:*` |
| Shield | `shield:*` |
| SNS | `sns:*` |
| SQS | `sqs:*` |
| STS | `sts:*` |
| WAF | `wafv2:*` |
| X-Ray | `xray:*` |
