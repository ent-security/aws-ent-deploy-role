# Ent Deploy Role — Pulumi (Go)

Deploys the Ent Home deployment role using Pulumi in Go.

## Prerequisites

- Go 1.21+
- Pulumi CLI: see https://www.pulumi.com/docs/install/
- AWS credentials configured

## Install

```bash
cd pulumi/go
go mod tidy
pulumi stack init dev
```

## Configure

```bash
pulumi config set ent-deploy-role:entAwsAccountArn arn:aws:iam::123456789012:root
pulumi config set ent-deploy-role:roleName HomeProdAssumeAdmin
```

| Key | Description | Default |
|---|---|---|
| `entAwsAccountArn` | Ent's AWS account ARN | `arn:aws:iam::000000000000:root` |
| `roleName` | IAM role name | `HomeProdAssumeAdmin` |
| `rolePath` | IAM role path | `/` |
| `roleDescription` | IAM role description | (matches Terraform default) |
| `tags` | Map of tags (use `--path`) | `{}` |

## Deploy

```bash
pulumi up
```

The `roleArn` output is the ARN to paste into the Ent AWS connection panel.

## Destroy

```bash
pulumi destroy
```

## Test

```bash
go test ./...
```
