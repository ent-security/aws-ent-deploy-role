# Ent Deploy Role — Pulumi (TypeScript)

Deploys the Ent Home deployment role using Pulumi in TypeScript.

## Prerequisites

- Node.js 18+
- Pulumi CLI: https://www.pulumi.com/docs/install/
- AWS credentials configured (`aws configure` or env vars)

## Install

```bash
cd pulumi/typescript
npm install
```

## Configure

Pulumi configuration is stack-scoped. Select (or create) a stack, then set values:

```bash
pulumi stack init dev
pulumi config set entAwsAccountArn arn:aws:iam::123456789012:root
pulumi config set roleName HomeProdAssumeAdmin   # optional
```

| Key | Description | Default |
|---|---|---|
| `entAwsAccountArn` | Ent's AWS account ARN | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
| `roleName` | IAM role name | `HomeProdAssumeAdmin` |
| `rolePath` | IAM role path | `/` |
| `roleDescription` | IAM role description | (matches Terraform default) |
| `tags` | Map of tags to apply to the role (`pulumi config set --path tags.key value`) | `{}` |

## Deploy

```bash
pulumi up
```

After deploy, the `roleArn` stack output is the ARN to paste into the Ent AWS connection panel:

```bash
pulumi stack output roleArn
```

## Destroy

```bash
pulumi destroy
```

## Test

```bash
npm test
```
