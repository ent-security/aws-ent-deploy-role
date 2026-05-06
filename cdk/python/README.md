# Ent Deploy Role — AWS CDK (Python)

Deploys the Ent Home deployment role using AWS CDK v2 in Python.

## Prerequisites

- Python 3.9+
- AWS CDK CLI: `npm install -g aws-cdk`
- AWS credentials configured

## Install

```bash
cd cdk/python
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Configure

Pass configuration via `-c key=value` flags on the CDK CLI.

| Key | Description | Default |
|---|---|---|
| `ent_aws_account_arn` | Ent's AWS account ARN | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
| `role_name` | IAM role name | `HomeProdAssumeAdmin` |
| `role_path` | IAM role path | `/` |
| `role_description` | IAM role description | (matches Terraform default) |
| `tags` | Map of tags to apply to the role (pass via `-c tags='{"key":"value"}'`) | `{}` |

## Deploy

```bash
cdk bootstrap
cdk deploy \
  -c ent_aws_account_arn=arn:aws:iam::123456789012:root \
  -c role_name=HomeProdAssumeAdmin
```

After deploy, the `RoleArn` output is the ARN to paste into the Ent AWS connection panel.

## Destroy

```bash
cdk destroy
```

## Test

```bash
pip install -r requirements-dev.txt
pytest
```
