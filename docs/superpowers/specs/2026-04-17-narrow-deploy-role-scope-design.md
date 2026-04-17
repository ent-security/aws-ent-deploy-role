# Narrow EntHomeAccess Deploy Role Scope

## Context

A customer (Balakumar) flagged that `policy.json` in this repo uses `Resource: "*"` and `Action: service:*` across 34 AWS services and asked for a narrower policy that meets their internal security standards. This spec defines the narrowed policy.

The role is assumed by `ent-platform` services to provision and manage AWS resources inside the customer's account. Scoping must remain loose enough for `ent-platform` to keep working, and must survive first-time deployments where no tagged resources exist yet.

## Goals

- Remove AWS services from the policy that `ent-platform` does not use.
- Replace `Resource: "*"` with ARN-prefix patterns for services that name their resources predictably.
- Keep `Resource: "*"` (with explicit acknowledgement) only where ARN patterns don't work cleanly — VPC/EC2 primitives, load-balancer automation, tag and describe/list APIs.
- Keep the policy expressed in three places — `policy.json`, `terraform/main.tf`, `cloudformation/template.yaml` — and keep them in sync.

## Non-goals

- Enumerating specific action lists per service (stays at `service:*`). That is a follow-up (option #3 in the original discussion).
- Changing the assume-role trust policy (`role.json`) — that was already scoped in earlier PRs.
- Introducing tag-based conditions on creates. Tag conditions were considered and rejected: not every `CreateX` supports `aws:RequestTag`, and a single miss breaks the deploy flow.

## Approach

**Structural-pattern ARN scoping, with carve-outs.**

The `ent-platform` Deployment service auto-generates a per-tenant `name_prefix` at deploy time. The generation happens in tofu itself (`deploy/tofu/platform/regional.tf`):

```hcl
name_prefix = "e${substr(sha256("${var.tenant_id}-${var.environment}-${var.region}"), 0, 15)}-"
```

Every generated prefix has the **exact same shape**: the letter `e`, followed by 15 lowercase hex characters, followed by `-`. Regex: `^e[0-9a-f]{15}-$`. Example: `e1a2b3c4d5e6f78-`.

The IAM policy can express this shape with a wildcard glob: `e???????????????-*` (one `e`, fifteen `?` single-char wildcards, a literal `-`, then `*`). This is looser than the regex (it also matches non-hex characters in those 15 slots), but it is dramatically tighter than `*` and matches every prefix the generator can produce. No parameterization is required — the customer deploys the role before Ent generates the prefix, and the policy still fits whatever prefix is chosen afterward.

Services that don't support predictable ARNs keep `Resource: "*"` but are explicitly called out as carve-outs so the customer can see why.

## Services to remove

Removed from the policy entirely. Evidence: no usage found in `ent-platform` during the code review. If a customer later enables the corresponding Ent feature, they can re-add the statement.

| Sid | Service | Why removed |
|-----|---------|-------------|
| `CostAndUsageReportAccess` | `bcm-data-exports` | Not referenced in `ent-platform`. |
| `CostAndUsageReportLegacyAccess` | `cur` (write) | CUR data is consumed via Athena + Glue, not the CUR API. Read-only actions retained under a new `CostAndUsageReportRead` statement (see below). |
| `CostExplorerAccess` | `ce` | Not referenced; cost data comes from CUR/Athena. |
| `CognitoAccess` | `cognito-idp` | Not referenced; auth uses certificate-based mTLS. |
| `KendraAccess` | `kendra` | Not referenced; search uses OpenSearch. |
| `LambdaAccess` | `lambda` | No Lambda invocations or deployments in `ent-platform`. |
| `SageMakerAccess` | `sagemaker` | Not referenced; ML workloads use Bedrock. |
| `ShieldAccess` | `shield` | Not referenced. Shield Standard is automatic. |
| `WAFAccess` | `wafv2` | Not referenced. |
| `XRayAccess` | `xray` | Not referenced; tracing goes through the OTEL → Prometheus/Tempo stack. |
| `OpenSearchServerlessAccess` | `aoss` | Confirmed unused — Ent uses provisioned OpenSearch, not the serverless variant. |
| `GrafanaAccess` | `grafana` | Confirmed unused — dashboards served by self-hosted Grafana on EKS, not Amazon Managed Grafana. |

Note on `cur`: the code review found a small number of read-only CUR API calls (`DescribeReportDefinitions`, `GetClassicReport`, `GetClassicReportPreferences`) in `ent-home-api`. We retain `cur:Describe*` and `cur:Get*` only, dropping the rest. This is a narrow exception to the "keep `service:*`" rule because CUR's surface is small and the read-only subset is unambiguous.

### Services held pending verification

`resource-groups` had one terraform reference in `home/main.tf` during the code review. Kept in the narrowed policy. Action for the user: confirm before the implementation PR merges whether it can be dropped.

## Services kept with narrowed resources

For each, `Action: service:*` is preserved and `Resource: "*"` is replaced with ARN patterns keyed off `${resource_name_prefix}`. Double-wildcard patterns (`e???????????????-*`) are used for services like S3/ECR where Ent's convention embeds the prefix as a substring rather than a leading token.

| Service | Resource scope |
|---------|----------------|
| `acm` | `*` — ACM certificates use auto-generated UUIDs; scoping by name isn't possible. Action constraint (`acm:*`) is the only control. Carve-out. |
| `athena` | `arn:aws:athena:*:*:workgroup/e???????????????-*`, `arn:aws:athena:*:*:datacatalog/e???????????????-*` |
| `bedrock` | `arn:aws:bedrock:*:*:inference-profile/*`, `arn:aws:bedrock:*:*:application-inference-profile/*` — inference profiles have UUIDs; scoped by resource type only. Carve-out. |
| `cloudwatch` | `arn:aws:cloudwatch:*:*:alarm:e???????????????-*` |
| `cur` (read-only) | `*` — CUR report definitions are account-global. Action scoped to `cur:Describe*`, `cur:Get*`. |
| `ec2` | `*` — VPC/subnet/SG/ENI/EIP operations need broad access; describe APIs don't support resource-level permissions. Carve-out. |
| `ecr` | `arn:aws:ecr:*:*:repository/e???????????????-*` |
| `eks` | `arn:aws:eks:*:*:cluster/e???????????????-*`, `arn:aws:eks:*:*:nodegroup/e???????????????-*/*`, `arn:aws:eks:*:*:access-entry/e???????????????-*/*`, `arn:aws:eks:*:*:addon/e???????????????-*/*/*` |
| `elasticache` | `arn:aws:elasticache:*:*:replicationgroup:e???????????????-*`, `arn:aws:elasticache:*:*:parametergroup:e???????????????-*`, `arn:aws:elasticache:*:*:subnetgroup:e???????????????-*` |
| `elasticloadbalancing` | `*` — ALB Controller creates LBs/TGs with auto-generated names driven by Kubernetes service annotations. Carve-out. |
| `glue` | `arn:aws:glue:*:*:catalog`, `arn:aws:glue:*:*:database/e???????????????-*`, `arn:aws:glue:*:*:table/e???????????????-*/*` |
| `iam` | `arn:aws:iam::*:role/e???????????????-*`, `arn:aws:iam::*:policy/e???????????????-*`, `arn:aws:iam::*:instance-profile/e???????????????-*`, plus `arn:aws:iam::*:role/aws-service-role/*` for `iam:CreateServiceLinkedRole` (scoped by `aws:ServiceName` condition listing the services Ent actually uses). |
| `kms` | `arn:aws:kms:*:*:key/*`, `arn:aws:kms:*:*:alias/e???????????????-*` — keys have UUIDs, so alias-based scoping is the control point. |
| `logs` | `arn:aws:logs:*:*:log-group:e???????????????-*`, `arn:aws:logs:*:*:log-group:e???????????????-*:*`, `arn:aws:logs:*:*:log-group:/aws/eks/e???????????????-*/*` |
| `rds` + `rds-db` | `arn:aws:rds:*:*:db:e???????????????-*`, `arn:aws:rds:*:*:cluster:e???????????????-*`, `arn:aws:rds:*:*:pg:e???????????????-*`, `arn:aws:rds:*:*:subgrp:e???????????????-*`, `arn:aws:rds:*:*:es:e???????????????-*`, `arn:aws:rds-db:*:*:dbuser:*/*` |
| `resource-groups` | `arn:aws:resource-groups:*:*:group/e???????????????-*` — pending verification. |
| `route53` | `*` — hosted-zone list/describe APIs don't support resource-level permissions, and zone IDs are auto-generated. Action constraint only. Carve-out. |
| `s3` | `arn:aws:s3:::e???????????????-*`, `arn:aws:s3:::e???????????????-*/*` |
| `secretsmanager` | `arn:aws:secretsmanager:*:*:secret:e???????????????-*`, `arn:aws:secretsmanager:*:*:secret:mks*` — `mks*` kept because SSH-key secrets for macOS endpoints use that prefix. |
| `sns` | `arn:aws:sns:*:*:e???????????????-*` |
| `sqs` | `arn:aws:sqs:*:*:e???????????????-*` |
| `sts` | `arn:aws:iam::*:role/e???????????????-*` for `sts:AssumeRole`; `*` for `sts:GetCallerIdentity` / `sts:DecodeAuthorizationMessage` (carve-out — these don't take a resource). |
| `tag` | `*` — the Resource Groups Tagging API is inherently multi-resource. Carve-out. |

## The prefix contract

- Shape: `e` + 15 hex characters + `-`. Regex: `^e[0-9a-f]{15}-`.
- Source of truth: `deploy/tofu/platform/regional.tf` in `ent-platform`. If that formula ever changes, the IAM policy must be updated in lockstep.
- Policy glob: `e???????????????-*` (IAM wildcards: `?` = one char, `*` = any). Admits non-hex characters in the 15-char slot, which is looser than the regex but as tight as IAM policy syntax allows without a Condition block. Acceptable because the only actor writing to that slot is the tofu SHA256 output.
- **No customer-facing variable.** The pattern is constant across all Ent deployments; parameterizing it would just invite misconfiguration.

## Expected structure of the new policy

One statement per service (as today). Each statement gets one of:

1. **Scoped:** `Resource: [<arn patterns with e???????????????-*>]`. Most services.
2. **Scoped + read-only action filter:** `Action: [cur:Describe*, cur:Get*]`, `Resource: "*"`. Only `cur`.
3. **Carve-out with comment:** `Resource: "*"` retained with a companion comment explaining why. Services: `acm`, `bedrock`, `ec2`, `elasticloadbalancing`, `route53`, `tag`, and the `sts:GetCallerIdentity` portion.
4. **IAM service-linked role:** separate statement for `iam:CreateServiceLinkedRole` with `Condition: StringLike: aws:AWSServiceName: [<ent-platform-used services>]`. List starts with: `eks.amazonaws.com`, `elasticloadbalancing.amazonaws.com`, `rds.amazonaws.com`, `elasticache.amazonaws.com`, `opensearchservice.amazonaws.com` — exact list to be finalized during implementation by checking each EKS add-on and terraform module.

## Files touched

- `policy.json` — updated JSON with narrowed resources.
- `terraform/main.tf` — narrowed policy statements (no new variables).
- `cloudformation/template.yaml` — narrowed statements (no new parameters).
- `README.md` — document the prefix shape, the lock-step dependency on `ent-platform`'s generator, the list of removed services, and the carve-out rationale. Update the "Permissions" table.

`terraform/variables.tf` is untouched. All three policy representations must stay equivalent after the change; the PR description will include a diff table showing the statements in each.

## Risks

- **Prefix formula drift.** If the `ent-platform` generator in `regional.tf` ever changes shape (different length, different leading char, different character class), every narrowed ARN statement breaks for new deployments. Mitigation: README calls out the lock-step dependency; the generator change should block on a matching policy update. Consider adding a cross-repo link.
- **Non-prefixed resources.** A small number of resources created by `ent-platform` may not embed the prefix (e.g., names derived from external inputs, AWS-managed names like ECR scan-on-push configs). The code-review sweep did not find any, but the pre-release staging deploy is the authoritative check.
- **Pending-verification service (`resource-groups`).** Kept in the narrowed policy until the user confirms; removing it risks breaking a feature the code review missed. The plan includes a verification checkpoint.
- **Future AWS service expansion.** If Ent adds a new service integration, the policy must grow. The README will note this review is a point-in-time snapshot.

## Testing

- `terraform validate` + `terraform plan` against a test AWS account.
- `aws cloudformation validate-template` for the CFN file.
- IAM policy simulator (`aws iam simulate-custom-policy`) for a handful of representative calls against a **generated** prefix value — e.g., `s3:CreateBucket` on `arn:aws:s3:::e1a2b3c4d5e6f78-tfstate`, `eks:CreateCluster` on `arn:aws:eks:us-east-1:123456789012:cluster/e1a2b3c4d5e6f78-home-prod`. Also run a negative test with a non-matching prefix to confirm deny.
- Manual verification that a staging `ent-platform` deploy succeeds end-to-end with the new policy attached. This is the authoritative check — the simulator catches obvious mismatches but not all of them.

## Rollout

1. Release as a new major version (e.g., `v2.0.0`) since this is a breaking change for any customer whose existing resources do not match the generated prefix shape.
2. README migration note: the new policy assumes `ent-platform`'s current prefix generator. Customers running an older `ent-platform` version where prefixes don't match must stay on the v1 tag until they upgrade.
3. Keep the old wildcard policy reachable via the previous tag so customers can revert.
