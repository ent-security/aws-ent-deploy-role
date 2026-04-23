# Ent Deploy Role — AWS CDK (TypeScript)

Deploys the Ent Home deployment role using AWS CDK v2 in TypeScript.

## Prerequisites

- Node.js 18+
- AWS CDK CLI: `npm install -g aws-cdk`
- AWS credentials configured (`aws configure` or env vars)

## Install

```bash
cd cdk/typescript
npm install
```

## Configure

Pass configuration via `-c key=value` flags on the CDK CLI, or set them in `cdk.context.json`.

| Key | Description | Default |
|---|---|---|
| `ent_aws_account_arn` | Ent's AWS account ARN | `arn:aws:iam::000000000000:root` |
| `role_name` | IAM role name | `HomeProdAssumeAdmin` |
| `role_path` | IAM role path | `/` |
| `role_description` | IAM role description | (matches Terraform default) |

## Deploy

```bash
npx cdk bootstrap   # one-time per account/region
npx cdk deploy \
  -c ent_aws_account_arn=arn:aws:iam::123456789012:root \
  -c role_name=HomeProdAssumeAdmin
```

After deploy, the `RoleArn` output is the ARN to paste into the Ent AWS connection panel.

## Destroy

```bash
npx cdk destroy
```

## Test

```bash
npm test
```
