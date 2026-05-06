# Ent Deploy Role — Pulumi (Python)

Deploys the Ent Home deployment role using Pulumi in Python.

## Prerequisites

- Python 3.9+
- Pulumi CLI: see https://www.pulumi.com/docs/install/
- AWS credentials configured

## Install

```bash
cd pulumi/python
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pulumi stack init dev
```

## Configure

```bash
pulumi config set ent-deploy-role:entAwsAccountArn arn:aws:iam::123456789012:root
pulumi config set ent-deploy-role:roleName HomeProdAssumeAdmin
```

| Key | Description | Default |
|---|---|---|
| `entAwsAccountArn` | Ent's AWS account ARN | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
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
pip install -r requirements-dev.txt
pytest
```
