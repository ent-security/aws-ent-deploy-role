# Narrow EntHomeAccess Deploy Role Scope

## Context

A customer (Balakumar) flagged that `policy.json` in this repo uses `Resource: "*"` and `Action: service:*` across 34 AWS services and asked for a narrower policy that meets their internal security standards. This spec defines the narrowed policy.

The role is assumed by `ent-platform` services to provision and manage AWS resources inside the customer's account. Scoping must remain loose enough for `ent-platform` to keep working, and must survive first-time deployments where no tagged resources exist yet.

## Goals

- Remove AWS services from the policy that `ent-platform` does not use.
- Replace `Resource: "*"` with ARN-prefix patterns for services that name their resources predictably.
- Keep `Resource: "*"` (with explicit acknowledgement) only where ARN patterns don't work cleanly — VPC/EC2 primitives, load-balancer automation, tag and describe/list APIs.
- Parameterize the name prefix so customers can match it to their naming convention.
- Keep the policy expressed in three places — `policy.json`, `terraform/main.tf`, `cloudformation/template.yaml` — and keep them in sync.

## Non-goals

- Enumerating specific action lists per service (stays at `service:*`). That is a follow-up (option #3 in the original discussion).
- Changing the assume-role trust policy (`role.json`) — that was already scoped in earlier PRs.
- Introducing tag-based conditions on creates. Tag conditions were considered and rejected: not every `CreateX` supports `aws:RequestTag`, and a single miss breaks the deploy flow.

## Approach

**Name-prefix ARN patterns, with carve-outs.**

Add a configurable `resource_name_prefix` (default `ent`) to the Terraform and CloudFormation inputs. The policy references this prefix in every ARN pattern where scoping is practical. Services that don't support predictable ARNs keep `Resource: "*"` but are explicitly commented in-line so the customer can see why.

The plain-JSON `policy.json` cannot be parameterized; it ships with the default prefix (`ent`) baked in and is documented as the example for customers deploying via the AWS CLI path.

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

Note on `cur`: the code review found a small number of read-only CUR API calls (`DescribeReportDefinitions`, `GetClassicReport`, `GetClassicReportPreferences`) in `ent-home-api`. We retain `cur:Describe*` and `cur:Get*` only, dropping the rest. This is a narrow exception to the "keep `service:*`" rule because CUR's surface is small and the read-only subset is unambiguous.

### Services held pending verification

These had uncertain evidence in the code review. They are kept in the narrowed policy unless the user confirms they can be removed:

- `aoss` (OpenSearch Serverless) — verify whether any ent-platform deployment uses serverless vs. provisioned OpenSearch.
- `resource-groups` — one terraform reference in `home/main.tf`.
- `grafana` — Amazon Managed Grafana is used in some regions only.

Action for the user: confirm (or disconfirm) each of these before the implementation PR merges. If confirmed unused, they can be dropped during the plan.

## Services kept with narrowed resources

For each, `Action: service:*` is preserved and `Resource: "*"` is replaced with ARN patterns keyed off `${resource_name_prefix}`. Double-wildcard patterns (`*${prefix}*`) are used for services like S3/ECR where Ent's convention embeds the prefix as a substring rather than a leading token.

| Service | Resource scope |
|---------|----------------|
| `acm` | `*` — ACM certificates use auto-generated UUIDs; scoping by name isn't possible. Action constraint (`acm:*`) is the only control. Carve-out. |
| `athena` | `arn:aws:athena:*:*:workgroup/*${prefix}*`, `arn:aws:athena:*:*:datacatalog/*${prefix}*` |
| `bedrock` | `arn:aws:bedrock:*:*:inference-profile/*`, `arn:aws:bedrock:*:*:application-inference-profile/*` — inference profiles have UUIDs; scoped by resource type only. Carve-out. |
| `cloudwatch` | `arn:aws:cloudwatch:*:*:alarm:*${prefix}*` |
| `cur` (read-only) | `*` — CUR report definitions are account-global. Action scoped to `cur:Describe*`, `cur:Get*`. |
| `ec2` | `*` — VPC/subnet/SG/ENI/EIP operations need broad access; describe APIs don't support resource-level permissions. Carve-out. |
| `ecr` | `arn:aws:ecr:*:*:repository/*${prefix}*` |
| `eks` | `arn:aws:eks:*:*:cluster/*${prefix}*`, `arn:aws:eks:*:*:nodegroup/*${prefix}*/*`, `arn:aws:eks:*:*:access-entry/*${prefix}*/*`, `arn:aws:eks:*:*:addon/*${prefix}*/*/*` |
| `elasticache` | `arn:aws:elasticache:*:*:replicationgroup:*${prefix}*`, `arn:aws:elasticache:*:*:parametergroup:*${prefix}*`, `arn:aws:elasticache:*:*:subnetgroup:*${prefix}*` |
| `elasticloadbalancing` | `*` — ALB Controller creates LBs/TGs with auto-generated names driven by Kubernetes service annotations. Carve-out. |
| `glue` | `arn:aws:glue:*:*:catalog`, `arn:aws:glue:*:*:database/*${prefix}*`, `arn:aws:glue:*:*:table/*${prefix}*/*` |
| `grafana` | `*` — Grafana workspace IDs are UUIDs. Carve-out. (Pending verification.) |
| `iam` | `arn:aws:iam::*:role/*${prefix}*`, `arn:aws:iam::*:policy/*${prefix}*`, `arn:aws:iam::*:instance-profile/*${prefix}*`, plus `arn:aws:iam::*:role/aws-service-role/*` for `iam:CreateServiceLinkedRole` (scoped by `aws:ServiceName` condition listing the services Ent actually uses). |
| `kms` | `arn:aws:kms:*:*:key/*`, `arn:aws:kms:*:*:alias/*${prefix}*` — keys have UUIDs, so alias-based scoping is the control point. |
| `logs` | `arn:aws:logs:*:*:log-group:*${prefix}*`, `arn:aws:logs:*:*:log-group:*${prefix}*:*`, `arn:aws:logs:*:*:log-group:/aws/eks/*${prefix}*/*` |
| `rds` + `rds-db` | `arn:aws:rds:*:*:db:*${prefix}*`, `arn:aws:rds:*:*:cluster:*${prefix}*`, `arn:aws:rds:*:*:pg:*${prefix}*`, `arn:aws:rds:*:*:subgrp:*${prefix}*`, `arn:aws:rds:*:*:es:*${prefix}*`, `arn:aws:rds-db:*:*:dbuser:*/*` |
| `resource-groups` | `arn:aws:resource-groups:*:*:group/*${prefix}*` — pending verification. |
| `route53` | `*` — hosted-zone list/describe APIs don't support resource-level permissions, and zone IDs are auto-generated. Action constraint only. Carve-out. |
| `s3` | `arn:aws:s3:::*${prefix}*`, `arn:aws:s3:::*${prefix}*/*` |
| `secretsmanager` | `arn:aws:secretsmanager:*:*:secret:*${prefix}*`, `arn:aws:secretsmanager:*:*:secret:mks*` — `mks*` kept because SSH-key secrets for macOS endpoints use that prefix. |
| `sns` | `arn:aws:sns:*:*:*${prefix}*` |
| `sqs` | `arn:aws:sqs:*:*:*${prefix}*` |
| `sts` | `arn:aws:iam::*:role/*${prefix}*` for `sts:AssumeRole`; `*` for `sts:GetCallerIdentity` / `sts:DecodeAuthorizationMessage` (carve-out — these don't take a resource). |
| `tag` | `*` — the Resource Groups Tagging API is inherently multi-resource. Carve-out. |

## The `${prefix}` contract

- Default: `ent`.
- Type: string, validated as `^[a-z][a-z0-9-]{0,31}$` (lowercase, starts with a letter, max 32 chars — conservative for S3/RDS/ECR naming constraints).
- Exposed in Terraform as `var.resource_name_prefix`, in CloudFormation as `ResourceNamePrefix`.
- Used by substitution: the module/template builds the policy JSON by interpolating the prefix into each ARN.
- `policy.json` (the standalone file for AWS CLI users) ships with the baked-in default `ent`. README documents how to search-and-replace if a different prefix is required.

**Ent-platform side:** `ent-platform` already uses a `name_prefix` variable across its tofu modules (surfaced during the code review as the `NamePrefix` tag). The customer is responsible for passing a matching value when they configure Ent's deployment, or both this policy's prefix and ent-platform's `name_prefix` need to share a default. That coordination is out of scope for this repo but must be called out in the README.

## Expected structure of the new policy

One statement per service (as today). Each statement gets one of:

1. **Scoped:** `Resource: [<patterns with ${prefix}>]`. Most services.
2. **Scoped + read-only action filter:** `Action: [cur:Describe*, cur:Get*]`, `Resource: "*"`. Only `cur`.
3. **Carve-out with comment:** `Resource: "*"` retained with an inline `Sid` suffix like `AcmAccessUnscoped` or a companion comment explaining why. Services: `acm`, `bedrock`, `ec2`, `elasticloadbalancing`, `grafana`, `route53`, `tag`, and the `sts:GetCallerIdentity` portion.
4. **IAM service-linked role:** separate statement for `iam:CreateServiceLinkedRole` with `Condition: StringLike: aws:AWSServiceName: [<ent-platform-used services>]`. List starts with: `eks.amazonaws.com`, `elasticloadbalancing.amazonaws.com`, `rds.amazonaws.com`, `elasticache.amazonaws.com`, `grafana.amazonaws.com`, `opensearchservice.amazonaws.com` — exact list to be finalized during implementation by checking each EKS add-on and terraform module.

## Files touched

- `policy.json` — updated JSON with narrowed resources (baked prefix = `ent`).
- `terraform/main.tf` — parameterized policy; new `resource_name_prefix` variable.
- `terraform/variables.tf` — add `resource_name_prefix` variable with validation.
- `cloudformation/template.yaml` — new `ResourceNamePrefix` parameter; narrowed statements.
- `README.md` — document the prefix contract, the coordination with ent-platform's `name_prefix`, the list of removed services, and the carve-out rationale.

All three representations must stay equivalent after the change; the PR description will include a diff table showing the statements in each.

## Risks

- **Naming drift in ent-platform.** If ent-platform creates a resource without the prefix in the name, deployment fails with AccessDenied. Mitigation: the code review pass found usage of a `NamePrefix` variable in ent-platform's tofu — consistent, but not exhaustively verified. The implementation plan will include a dry-run against a staging deployment before release.
- **Pending-verification services (`aoss`, `resource-groups`, `grafana`).** Leaving them in costs nothing; removing them risks breaking features the code review missed. The plan includes a verification checkpoint before we decide.
- **CloudFormation parameter support for lists.** CFN templates can interpolate a scalar parameter into strings (`!Sub`) — confirmed this works with embedded policy documents.
- **Future AWS service expansion.** If Ent adds a new service integration, the policy must grow. The README will note this review is a point-in-time snapshot.

## Testing

- `terraform validate` + `terraform plan` against a test AWS account.
- `aws cloudformation validate-template` for the CFN file.
- IAM policy simulator (`aws iam simulate-custom-policy`) for a handful of representative calls (`s3:CreateBucket` on `arn:aws:s3:::ent-tfstate-abc`, `eks:CreateCluster` on `arn:aws:eks:us-east-1:123:cluster/ent-home-prod`, etc.) to confirm allow/deny shapes.
- Manual verification that a staging ent-platform deploy succeeds end-to-end with the new policy attached. This is the authoritative check — the simulator catches obvious mismatches but not all of them.

## Rollout

1. Release as a new minor version (e.g., `v2.0.0`) since existing consumers pinned to `main` would see a breaking semantic change (their resources must match the prefix).
2. README migration note: "If your resources don't match the default `ent` prefix, set `resource_name_prefix` to your actual prefix before upgrading."
3. Keep the old wildcard policy reachable via the previous tag so customers can revert.
