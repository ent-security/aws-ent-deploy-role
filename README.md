# aws-ent-deploy-role

Infrastructure as Code to create the Ent Security Deployment Role in AWS. Supports Terraform (including OpenTofu), CloudFormation, AWS CDK (TypeScript and Python), and Pulumi (TypeScript, Python, and Go).

## Terraform Usage

**Note** the example below uses `ref=main`. It is recommended to pin this module to a specific tag version (i.e. `ref=1.0.0`) to avoid breaking changes. See the [releases page](https://github.com/ent-security/aws-ent-deploy-role/releases) for a list of published versions.

> **Module path changed.** The Terraform root moved from `//terraform` to `//terraform/commercial`
> (a major-version change) so the repo can host both the commercial role and the GovCloud
> ([Roles Anywhere](#govcloud-roles-anywhere)) variant from one shared permission policy. If you
> pin a tag from before this change, keep using `//terraform`; when you bump to the new major
> version, update the source path to `//terraform/commercial`. State migrates in place (the root
> ships `moved` blocks) — `terraform plan` shows no resource changes, only moves.

```hcl
module "ent_deployment_role" {
  source = "git::https://github.com/ent-security/aws-ent-deploy-role//terraform/commercial?ref=main"
}

# this will output the Role ARN
output "ent_deployment_role" {
  value = module.ent_deployment_role.role_arn
}
```

After you apply this terraform, it will output the Role ARN. Send the Role ARN — and the value you used for `role_sts_external_id`, if any — to your Ent contact (the engineer or sales rep who shared the deploy instructions, or `support@ent.ai`). Ent uses the ARN and ExternalId to assume the role and start your tenant deployment.

### Deploying with Terraform / OpenTofu

The Terraform module in this repository works unmodified with [OpenTofu](https://opentofu.org/) — the open-source fork of Terraform. Anywhere the instructions below say `terraform`, you can substitute `tofu` and get the same result.

If you want to deploy the module directly (e.g. from a local clone), you can use either tool:

```bash
cd terraform/commercial/
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
| `policy_arns` | ARNs of the four functional permission policies attached to the role |
| `policy_arn` | **Deprecated.** ARN of one functional policy (`EntHomeAccessSecurity`). Retained for backward compatibility — use `policy_arns` for the full set. |
| `boundary_policy_arn` | ARN of the `EntHomeAccessBoundary` permissions-boundary policy. **Not attached to this role** — see [IAM privilege-escalation guard](#iam-privilege-escalation-guard). |

The permission set is split across four functional managed policies (see [Managed-policy split](#managed-policy-split)), so `policy_arns` is the real output; the singular `policy_arn` is kept only so pre-split consumers keep resolving.

### Requirements

- Terraform >= 1.1.0 (for `moved` block support in the `commercial` root)
- AWS Provider >= 3.1.15

## GovCloud (Roles Anywhere)

GovCloud (`aws-us-gov`) tenants can't be reached with `sts:AssumeRole` — IAM does not allow a role
in one partition to trust a principal in another. The `terraform/govcloud/` root provisions the
GovCloud-side equivalent of the commercial deploy role, reached from commercial-partition Ent Home
via [IAM Roles Anywhere](https://docs.aws.amazon.com/rolesanywhere/latest/userguide/introduction.html):
Ent presents an X.509 client certificate (issued by an Ent-operated CA) to obtain temporary
GovCloud credentials for the deploy role.

It creates three resources in your GovCloud account — a **trust anchor** (anchored to the Ent CA
root certificate), the **deploy role** (whose permission policy is the same shared policy as the
commercial role, with the partition swapped to `aws-us-gov` and services unavailable in GovCloud
removed), and a **profile** binding them.

```bash
cd terraform/govcloud/
terraform init
terraform apply \
  -var 'environment=dev' \
  -var "ca_certificate_pem=$(cat ent-ca-root.pem)"
# Send the three output ARNs to your Ent contact.
```

The Ent CA root certificate (`ca_certificate_pem`) is supplied by your Ent contact during GovCloud
onboarding.

### GovCloud Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `ca_certificate_pem` | PEM-encoded Ent CA root certificate the trust anchor anchors to | — | Yes |
| `environment` | Ent Home environment to trust (`dev` or `prod`); names the trust anchor/profile | — | Yes |
| `region` | GovCloud region (selects the `aws-us-gov` partition) | `us-gov-west-1` | No |
| `session_duration` | Max session duration (seconds) for issued credentials (900–43200) | `3600` | No |
| `trusted_cert_cn` | Optional: pin the deployer certificate Subject CN in the role trust policy | `null` | No |
| `role_name` | IAM role name | `HomeProdAssumeAdmin` | No |
| `role_path` | IAM role path | `/` | No |
| `role_description` | IAM role description | (provided by module) | No |
| `tags` | A map of tags to add to created resources | `{}` | No |

### GovCloud Outputs

| Output | Description |
|--------|-------------|
| `trust_anchor_arn` | ARN of the Roles Anywhere trust anchor |
| `profile_arn` | ARN of the Roles Anywhere profile |
| `role_arn` | ARN of the deploy role |
| `boundary_policy_arn` | ARN of the `EntHomeAccessBoundary` permissions-boundary policy. **Not attached to the role** — see [IAM privilege-escalation guard](#iam-privilege-escalation-guard). |

### GovCloud Requirements

- Terraform >= 1.0.0
- AWS Provider >= 5.0.0 (for the `aws_rolesanywhere_*` resources)

## CloudFormation Usage

> **Note.** Like the Terraform, CDK, and Pulumi variants, the CloudFormation templates (`template.yaml`, `template-autocomplete.yaml`) create the permission set as the four functional managed policies (`EntHomeAccessCompute`, `EntHomeAccessData`, `EntHomeAccessSecurity`, `EntHomeAccessPlatform` — see the [functional split](#managed-policy-split)) and attach all four to the role, keeping each under AWS's 6144-character single-managed-policy limit, plus the `EntHomeAccessBoundary` permissions-boundary policy (not attached — see [IAM privilege-escalation guard](#iam-privilege-escalation-guard)). The CFN statements are hand-maintained (no zero-diff test guards them like Terraform's) — keep them in lockstep with the four `EntHomeAccess.<domain>.json` files plus `EntHomeAccess.boundary.json`.

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
| `RoleStsExternalId` | STS ExternalId condition value. When non-empty, Ent Home must supply this value in its AssumeRole call. | `""` | No |
| `RoleName` | IAM role name | `HomeProdAssumeAdmin` | No |
| `RolePath` | Path of IAM role | `/` | No |
| `RoleDescription` | IAM Role description | (provided by template) | No |

### CloudFormation Outputs

| Output | Description |
|--------|-------------|
| `RoleArn` | The ARN of the role |
| `RoleName` | The name of the role |
| `PolicyArnCompute` | The ARN of the Compute & Networking managed policy |
| `PolicyArnData` | The ARN of the Data & Storage managed policy |
| `PolicyArnSecurity` | The ARN of the Identity & Security managed policy |
| `PolicyArnPlatform` | The ARN of the Observability & Platform managed policy |
| `PolicyArn` | Deprecated — the Identity & Security policy ARN, kept for backward compatibility; use the per-domain outputs |
| `PolicyArnBoundary` | The ARN of the `EntHomeAccessBoundary` permissions-boundary policy. **Not attached to the role** — see [IAM privilege-escalation guard](#iam-privilege-escalation-guard). |

### CloudFormation (auto-callback variant)

`cloudformation/template-autocomplete.yaml` is a sibling template that creates the same IAM role and four managed policies as `template.yaml` and additionally bundles a one-shot custom-resource Lambda. On stack creation the Lambda HMAC-signs the new role's ARN and POSTs it back to Ent so the tenant deployment starts automatically — no manual hand-off of the Role ARN.

This variant is intended to be launched from a Launch Stack URL emailed to you by Ent. The URL pre-fills the `EntCallbackUrl` and `EntWebhookSecret` parameters; without them the Lambda has nowhere to call back to. **Do not deploy this template manually.** If you are deploying by hand, use `template.yaml` instead and email the Role ARN back as described above.

Extra parameters (in addition to those listed in [CloudFormation Parameters](#cloudformation-parameters)):

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `EntCallbackUrl` | HTTPS URL Ent expects the stack-creation callback to POST to. Pre-filled by the Launch Stack URL. | — | Yes |
| `EntWebhookSecret` | Per-deal HMAC secret used to sign the callback POST. `NoEcho`; pre-filled by the Launch Stack URL. | — | Yes |
| `EntTenantName` | Display name for this Ent tenant. Pre-filled from your survey response, but editable on the AWS Console review screen. | `""` | No |

The Lambda code is short enough to audit before clicking Create stack — see `cloudformation/template-autocomplete.yaml`. It only runs on the `Create` request type, signals `CFN_FAILED` (with a retry message) on any non-2xx response from Ent so the customer is never left with a silent `CREATE_COMPLETE`-with-no-handshake, and is bounded by `signal.alarm(45)` plus an outer Lambda `Timeout: 60` to guarantee the stack never hangs in `CREATE_IN_PROGRESS`.

## CDK Usage

This repository ships standalone CDK v2 apps in TypeScript and Python. Both read the four authoritative functional policy files (see [Managed-policy split](#managed-policy-split)) and `role.json` at synthesis time, creating one managed policy per file and attaching all four to the role, plus the `EntHomeAccessBoundary` permissions-boundary policy (not attached — see [IAM privilege-escalation guard](#iam-privilege-escalation-guard)).

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
| `PolicyArnCompute`, `PolicyArnData`, `PolicyArnSecurity`, `PolicyArnPlatform` | ARNs of the four functional permission policies |
| `PolicyArn` | **Deprecated.** ARN of one functional policy (`EntHomeAccessSecurity`); retained for backward compatibility |
| `PolicyArnBoundary` | ARN of the `EntHomeAccessBoundary` permissions-boundary policy. **Not attached to the role** — see [IAM privilege-escalation guard](#iam-privilege-escalation-guard). |

## Pulumi Usage

This repository ships standalone Pulumi programs in TypeScript, Python, and Go. All three read the four authoritative functional policy files (see [Managed-policy split](#managed-policy-split)) and `role.json` at deploy time, creating one managed policy per file and attaching all four to the role, plus the `EntHomeAccessBoundary` permissions-boundary policy (not attached — see [IAM privilege-escalation guard](#iam-privilege-escalation-guard)).

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
| `policyArns` | ARNs of the four functional permission policies attached to the role |
| `policyArn` | **Deprecated.** ARN of one functional policy (`EntHomeAccessSecurity`); retained for backward compatibility — use `policyArns` |
| `boundaryPolicyArn` | ARN of the `EntHomeAccessBoundary` permissions-boundary policy. **Not attached to this role** — see [IAM privilege-escalation guard](#iam-privilege-escalation-guard). |

## AWS CLI Usage

Deploy using the AWS CLI with the provided `role.json` and the four functional policy files (see [Managed-policy split](#managed-policy-split)). The permission set is split across four managed policies because the full set exceeds AWS's 6144-character single-managed-policy limit; create all four and attach each to the role. You must also create the `EntHomeAccessBoundary` policy from `EntHomeAccess.boundary.json` — **do not attach it to the role**; it is referenced only by ARN in the `IAMBoundaryEnforcement` Deny condition inside `EntHomeAccess.identity-security.json` (see [IAM privilege-escalation guard](#iam-privilege-escalation-guard)). Create it before the role/policies below, since the identity-security policy's condition references its ARN.

> **Deploying in AWS GovCloud?** The functional policy files ship with commercial `arn:aws:` ARNs — rewrite the partition before running the commands below. See [AWS partitions (GovCloud)](#aws-partitions-govcloud).

1. Update `role.json` with your Ent AWS Account ARN:

```bash
sed -i '' 's/<ENT_AWS_ACCOUNT_ARN>/YOUR_ENT_AWS_ACCOUNT_ARN/' role.json
```

   **Did your Ent contact supply an STS ExternalId?** Do **not** add the `sts:ExternalId` condition to the single combined statement in `role.json`. `sts:ExternalId` is only present in the request context when STS authorizes `sts:AssumeRole`; it is absent when STS authorizes the `sts:TagSession` call that the Ent Home deploy identity's transitive session tags (from EKS Pod Identity) trigger. Gating both actions on `sts:ExternalId` makes the deploy fail with `AccessDenied ... not authorized to perform: sts:TagSession`. Instead, write `role.json` as **two statements** — keep the ExternalId condition on `sts:AssumeRole`, and grant `sts:TagSession` without it:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EntDeployAssumeRole",
      "Effect": "Allow",
      "Principal": { "AWS": "YOUR_ENT_AWS_ACCOUNT_ARN" },
      "Action": "sts:AssumeRole",
      "Condition": { "StringEquals": { "sts:ExternalId": "YOUR_EXTERNAL_ID" } }
    },
    {
      "Sid": "EntDeployTagSession",
      "Effect": "Allow",
      "Principal": { "AWS": "YOUR_ENT_AWS_ACCOUNT_ARN" },
      "Action": "sts:TagSession"
    }
  ]
}
```

2. Create the `EntHomeAccessBoundary` permissions-boundary policy. **Do not attach it to the role** — it is referenced only by ARN from a Deny condition in the Identity & Security functional policy created in step 4:

```bash
aws iam create-policy \
  --policy-name EntHomeAccessBoundary \
  --policy-document file://EntHomeAccess.boundary.json
```

3. Create the IAM role:

```bash
aws iam create-role \
  --role-name HomeProdAssumeAdmin \
  --path / \
  --description "Role that allows HomeDev SSO to assume EntHomePermissions role" \
  --assume-role-policy-document file://role.json
```

4. Create the four functional IAM policies and attach each to the role. Each file becomes a managed policy named `EntHomeAccess<Domain>`:

```bash
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
PARTITION="aws"  # use "aws-us-gov" in GovCloud

# file:managed-policy-name pairs (one policy per functional domain). Plain list + parameter-expansion
# split (${pair%%:*} / ${pair##*:}) so this runs on Bash 3.2 (macOS default) — no associative arrays.
for pair in \
  "EntHomeAccess.compute-network.json:EntHomeAccessCompute" \
  "EntHomeAccess.data-storage.json:EntHomeAccessData" \
  "EntHomeAccess.identity-security.json:EntHomeAccessSecurity" \
  "EntHomeAccess.observability-platform.json:EntHomeAccessPlatform"; do
  file="${pair%%:*}"
  name="${pair##*:}"
  aws iam create-policy --policy-name "$name" --policy-document "file://$file"
  aws iam attach-role-policy \
    --role-name HomeProdAssumeAdmin \
    --policy-arn "arn:${PARTITION}:iam::${ACCOUNT_ID}:policy/${name}"
done
```

## Setup

There are two ways to connect AWS to Ent. Most customers use the Launch Stack flow; pick one of the manual flows if you have policy reasons not to run a customer-supplied CloudFormation template.

### Launch Stack (recommended)

Sales sends you an email with a Launch Stack button after your deal moves to onboarding. Clicking the button opens the AWS Console's CloudFormation stack creator with `template-autocomplete.yaml` pre-loaded and the per-deal callback parameters (`EntCallbackUrl`, `EntWebhookSecret`) already filled in:

1. Sign in to the AWS account where you want Ent to deploy.
2. Click the Launch Stack button in the email — this opens AWS Console with the template pre-filled.
3. Optionally edit `EntTenantName` on the review screen.
4. Acknowledge the IAM capabilities checkbox and click `Create stack`.
5. Wait for `CREATE_COMPLETE`. The bundled Lambda POSTs the new role ARN back to Ent on success and your tenant deployment starts automatically — no copy-paste required.

If the stack lands in `CREATE_FAILED` with a "Could not reach Ent endpoint" reason, delete the stack and click Launch Stack again. The callback handler is idempotent on the Ent side, so a retry is safe.

### Terraform (manual)

1. Add the module block from [Terraform Usage](#terraform-usage) to your Terraform code.
2. Pin `ref=` to a tag from the [releases page](https://github.com/ent-security/aws-ent-deploy-role/releases) rather than `main`.
3. Run `terraform init` to download the module, then `terraform apply` — **review the plan output before typing `yes`**.
4. Copy the `role_arn` output (and the value you used for `role_sts_external_id`, if any).
5. Email both to your Ent contact (or `support@ent.ai`). Ent uses them to assume the role and start your tenant deployment.

### CloudFormation (manual)

1. Deploy `cloudformation/template.yaml` with the AWS CLI or the AWS Console (see [CloudFormation Usage](#cloudformation-usage)). Set `RoleStsExternalId` if your Ent contact supplied one.
2. Once the stack reaches `CREATE_COMPLETE`, find `RoleArn` in the stack Outputs.
3. Email the Role ARN (and the ExternalId, if any) to your Ent contact.

### CDK (manual)

1. Pick a CDK variant (TypeScript or Python) and follow its README to install prerequisites.
2. Run `cdk deploy -c ent_aws_account_arn=<your-arn> -c role_name=<name>`.
3. Copy the `RoleArn` stack output.
4. Email it to your Ent contact.

### Pulumi (manual)

1. Pick a Pulumi variant (TypeScript, Python, or Go) and follow its README to install prerequisites.
2. Run `pulumi config set ent-deploy-role:entAwsAccountArn <your-arn>` then `pulumi up`.
3. Copy the `roleArn` stack output.
4. Email it to your Ent contact.

## AWS partitions (GovCloud)

Every IaC variant in this repo builds its resource ARNs from the partition it is
deployed into, so the same code works in commercial AWS and AWS GovCloud
(`aws-us-gov`) without edits:

| Variant | Partition source |
|---------|------------------|
| Terraform / OpenTofu | `data.aws_partition.current.partition` |
| CloudFormation | `${AWS::Partition}` pseudo-parameter |
| CDK (TS + Python) | `Aws.PARTITION` |
| Pulumi (TS, Python, Go) | `aws.getPartition()` |

There is no flag to set — the partition is detected from the credentials and region
you deploy with. Two things to know for GovCloud:

- **Raw AWS CLI flow only.** The functional policy files are stored with commercial `arn:aws:`
  ARNs. The IaC variants above rewrite the partition automatically, but the
  [AWS CLI Usage](#aws-cli-usage) flow submits the files as-is, so rewrite them first (the loop in
  that section already sets `PARTITION="aws-us-gov"` for the attach step):

  ```bash
  sed -i '' 's#arn:aws:#arn:aws-us-gov:#g' EntHomeAccess.compute-network.json EntHomeAccess.data-storage.json EntHomeAccess.identity-security.json EntHomeAccess.observability-platform.json
  ```

- **Trust principal must match the role's partition.** The Ent account ARN you supply
  (`ent_aws_account_arn` / `EntAwsAccountArn`) is left exactly as given — it is *not*
  partition-rewritten, because it identifies Ent's account, not your deploy target.
  Cross-partition `AssumeRole` (commercial ↔ GovCloud) is not supported, so a GovCloud
  deployment needs a GovCloud Ent principal ARN. Ask your Ent contact for it.

## Directory Structure

```
aws-ent-deploy-role/
├── .github/
│   └── workflows/
│       ├── publish.yml          # tags v* → S3/CloudFront publish
│       └── terraform-check.yml  # size lint + fmt + validate + zero-diff guard
├── cdk/
│   ├── typescript/
│   └── python/
├── cloudformation/
│   ├── template.yaml            # IAM role + policy
│   └── template-autocomplete.yaml  # role + policy + Launch-Stack callback Lambda
├── pulumi/
│   ├── typescript/
│   ├── python/
│   └── go/
├── scripts/
│   └── check-policy-size.sh     # fails if any functional policy nears the 6144-char IAM limit
├── terraform/
│   ├── modules/
│   │   ├── deploy-permissions/      # four functional IAM permission policies (partition-parameterized)
│   │   ├── commercial-trust/        # assume-role trust + role (commercial)
│   │   └── govcloud-rolesanywhere/  # trust anchor + profile + role (GovCloud)
│   ├── commercial/                  # root: deploy-permissions + commercial-trust
│   └── govcloud/                    # root: deploy-permissions + govcloud-rolesanywhere
├── role.json
├── EntHomeAccess.compute-network.json        # functional policy: Compute & Networking
├── EntHomeAccess.data-storage.json           # functional policy: Data & Storage
├── EntHomeAccess.identity-security.json      # functional policy: Identity & Security
├── EntHomeAccess.observability-platform.json # functional policy: Observability & Platform
└── README.md
```

## Managed-policy split

The full permission set exceeds AWS's **6144-character** single-managed-policy hard limit, so it is split across **four functional managed policies** along service-domain boundaries. Each domain is its own authoritative file at the repo root, rendered into its own managed policy and attached to the role:

| File | Managed policy | Domain | Statements |
|------|----------------|--------|-----------|
| `EntHomeAccess.compute-network.json` | `EntHomeAccessCompute` | Compute & Networking (EC2, EKS, ECR, ELB, Route 53) | 7 |
| `EntHomeAccess.data-storage.json` | `EntHomeAccessData` | Data & Storage (S3, RDS, EFS, ElastiCache, Athena, Glue) | 9 |
| `EntHomeAccess.identity-security.json` | `EntHomeAccessSecurity` | Identity & Security (IAM, STS, KMS, Secrets Manager, ACM, WAFv2) | 10 |
| `EntHomeAccess.observability-platform.json` | `EntHomeAccessPlatform` | Observability & Platform (CloudWatch, logs, cost/billing, Service Quotas, SNS, SQS, Bedrock, tagging) | 12 |

The managed-policy names come from a name **prefix** (Terraform `var.policy_name`, default `EntHomeAccess`) suffixed per domain — `${prefix}Compute`, `${prefix}Data`, `${prefix}Security`, `${prefix}Platform`. Overriding the prefix renames all four in lockstep.

A fifth managed policy, `${prefix}Boundary` (file `EntHomeAccess.boundary.json`), is created alongside the four but **not attached to the role** — it is a permissions boundary referenced only by ARN in a Deny condition on `iam:CreateRole`. See [IAM privilege-escalation guard](#iam-privilege-escalation-guard).

The split introduced no permission change: before merge, the Sid-keyed union of the four files was validated set-equal to the pre-split single policy via a throwaway reference file built from the previous `policy.json` (since removed — the four files are now the sole source of truth). The Terraform zero-diff test asserts each rendered managed policy matches its `EntHomeAccess.<domain>.json` file, and `scripts/check-policy-size.sh` (wired into CI) fails the build if any functional file approaches the 6144-character limit.

### Migrating an existing tenant

Earlier versions of this module created a **single** `EntHomeAccess` managed policy. Moving to the functional split **replaces** that single policy with the four functional ones: an existing tenant's `terraform apply` (or CDK/Pulumi update) **destroys the old `EntHomeAccess` policy and creates the four `EntHomeAccess{Compute,Data,Security,Platform}` policies**. This is a replace, not a rename or an in-place shrink — there is deliberately no `moved` block claiming otherwise, because the old single policy genuinely goes away.

The **effective permissions are unchanged** (the union of the four equals the old single policy) and the deploy **role keeps its name and is re-attached to all four**. But because the old policy is detached and deleted mid-apply, **run the migration when no tenant deploy is in flight** — a deploy that assumes the role during the brief window between detach and re-attach could see a partial permission set. Outside a deploy, the apply is safe and the role ends correct.

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
| IAM | `iam:*` | roles/policies/instance-profiles prefixed `e???????????????-`; also `policy/AmazonEKS_*` (EKS pod-identity module creates `AmazonEKS_EBS_CSI-<timestamp>` directly) and `oidc-provider/oidc.eks.*.amazonaws.com/*` (EKS IRSA OIDC providers). Role creation under the glob requires the `EntHomeAccessBoundary` permissions boundary — see [IAM privilege-escalation guard](#iam-privilege-escalation-guard). |
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
| Service Quotas | `servicequotas:GetServiceQuota`, `servicequotas:GetAWSDefaultServiceQuota`, `servicequotas:ListRequestedServiceQuotaChangeHistoryByQuota`, `servicequotas:RequestServiceQuotaIncrease` | EC2-family quotas (`ec2/*`) — lets ent-platform's capability-aware GPU profile selection read the On-Demand G/VT vCPU quota (the applied value, or the AWS default when the account has no applied override) and file an increase instead of wedging the GPU rollout (quota ARNs are account-global, not tenant-prefixed) |
| Service Quotas (list) | `servicequotas:ListServiceQuotas` | unscoped (`Resource: "*"`) — the list API enumerates a service's quotas and has no resource-level support |
| S3 | `s3:*` | buckets prefixed `e???????????????-` |
| S3 (list buckets) | `s3:ListAllMyBuckets` | unscoped (account-level API; Terraform's `aws_canonical_user_id` data source calls it and it doesn't support resource-level permissions) |
| S3 (account public-access block) | `s3:GetAccountPublicAccessBlock` | unscoped (account-level API with no resource-level support) — lets `ent-platform` verify the account enforces Block Public Access when the tenant sets `manageBucketPublicAccessBlock=false` |
| Secrets Manager | `secretsmanager:*` | secrets prefixed `e???????????????-`, `mks` (macOS SSH keys), `rds!` (RDS-managed master-password secrets), or `grafana/<tenant-uuid>-<env>/*` (Grafana OAuth config in `platform-monitoring`) |
| SNS | `sns:*` | topics prefixed `e???????????????-` and `db-event-notifications` (hardcoded default in `ent-platform`'s `db_event_subscription` module) |
| SQS | `sqs:*` | queues prefixed `e???????????????-` |
| STS (assume role) | `sts:AssumeRole`, `sts:TagSession`, `sts:AssumeRoleWithWebIdentity` | roles prefixed `e???????????????-` |
| STS (identity) | `sts:GetCallerIdentity`, `sts:DecodeAuthorizationMessage`, `sts:GetAccessKeyInfo` | unscoped (these calls don't take resources) |
| WAFv2 | `wafv2:*` | regional/global web-ACLs prefixed `e???????????????-` |
| Resource Tagging API | `tag:*` | unscoped (multi-resource API) |

### IAM privilege-escalation guard

The IAM row above grants `iam:CreateRole`/`iam:PutRolePolicy`/`iam:AttachRolePolicy` on `role/e???????????????-*`, and the STS row grants `sts:AssumeRole` on the same glob. IAM authorizes those `iam:*` calls against the *target role resource*, not the content of whatever policy later gets attached to it — so, without a further guard, this role could create a new role matching the glob, attach an unbounded policy to it, then immediately `sts:AssumeRole` into it: a privilege escalation using only permissions this role already holds.

Two Deny statements close this gap:

- `IAMBoundaryEnforcement` denies `iam:CreateRole` under the glob unless the caller sets `iam:PermissionsBoundary` to the `EntHomeAccessBoundary` policy. A permissions boundary caps a role's *effective* permissions to the intersection of its identity policies and the boundary, regardless of what gets attached to it afterward — so `iam:PutRolePolicy`/`iam:AttachRolePolicy` need no additional condition once the boundary is enforced at creation time.
- `IAMBoundaryProtection` denies `iam:PutRolePermissionsBoundary`/`iam:DeleteRolePermissionsBoundary` under the glob, so a role's boundary can't be stripped or swapped after creation.

`EntHomeAccessBoundary` is a fifth managed policy, created alongside the four functional policies (see [Managed-policy split](#managed-policy-split)) but **never attached to this role itself** — every IaC variant's outputs table above marks it as such. It denies `iam:*` and `sts:AssumeRole`/`sts:AssumeRoleWithWebIdentity`/`sts:TagSession` outright, which is deliberately too restrictive for this deploy role's own needs; it exists solely to be referenced by ARN in `IAMBoundaryEnforcement`'s condition, capping whatever role this deploy role creates under the glob.

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
