import * as fs from 'fs';
import * as path from 'path';
import * as pulumi from '@pulumi/pulumi';
import * as aws from '@pulumi/aws';

const config = new pulumi.Config();

const entAwsAccountArn =
  config.get('entAwsAccountArn') ?? 'arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005';
const roleName = config.get('roleName') ?? 'HomeProdAssumeAdmin';
const rolePath = config.get('rolePath') ?? '/';
const roleDescription =
  config.get('roleDescription') ??
  'Role that allows Ent Home to assume AdministratorAccess role';
const tags = config.getObject<Record<string, string>>('tags') ?? {};
const permissionsBoundaryArn = config.get('permissionsBoundaryArn') ?? '';

const policyNamePrefix = 'EntHomeAccess';
const policyDescription =
  'Custom policy for permissions needed by Ent Home to deploy and manage resources in customer accounts. This policy is attached to the role that Ent Home assumes when deploying resources in customer accounts.';

// The permission set is split across four functional managed policies so each stays under AWS's
// 6144-character managed-policy limit. Each entry is [authoritative file, name suffix]; the policy
// is named `${prefix}${suffix}` (EntHomeAccess{Compute,Data,Security,Platform}). The union of the
// four is the complete permission set. Keep this in lockstep with the Terraform
// statement_group map and the files.
const POLICY_FILES: ReadonlyArray<readonly [string, string]> = [
  ['EntHomeAccess.compute-network.json', 'Compute'],
  ['EntHomeAccess.data-storage.json', 'Data'],
  ['EntHomeAccess.identity-security.json', 'Security'],
  ['EntHomeAccess.observability-platform.json', 'Platform'],
];
// Suffix of the functional policy whose ARN backs the deprecated single-ARN `policyArn` export.
const COMPAT_POLICY_SUFFIX = 'Security';

// Resolve repo root: pulumi/typescript/ -> pulumi/ -> repo root
const repoRoot = path.resolve(__dirname, '..', '..');
const partition = aws.getPartitionOutput().partition;
const trustJson = fs
  .readFileSync(path.join(repoRoot, 'role.json'), 'utf-8')
  .replaceAll('<ENT_AWS_ACCOUNT_ARN>', entAwsAccountArn);

// The functional policy files hold the canonical (commercial) `arn:aws:` ARNs. Rewrite the
// partition to the one we're deploying into so the policies work in commercial and GovCloud
// (aws-us-gov) alike. Each file becomes its own managed policy, mirroring the Terraform module.
export const policies = POLICY_FILES.map(([filename, suffix]) => {
  const policyRaw = fs.readFileSync(path.join(repoRoot, filename), 'utf-8');
  const policyJson = partition.apply((p) => policyRaw.replaceAll('arn:aws:', `arn:${p}:`));
  return new aws.iam.Policy(`EntHomeAccess${suffix}`, {
    name: `${policyNamePrefix}${suffix}`,
    description: policyDescription,
    path: '/',
    policy: policyJson,
  });
});

// Ent's default permissions boundary: pass its ARN as permissionsBoundaryArn to enforce it. NOT
// attached to the deploy role itself below -- it would strip the deploy role's own
// iam:*/sts:AssumeRole grants on the glob, breaking it. No partition rewrite needed: its
// Action/Resource entries carry no ARNs.
export const boundaryPolicy = new aws.iam.Policy('EntHomeAccessBoundary', {
  name: `${policyNamePrefix}Boundary`,
  description:
    'Permissions boundary for IAM roles created by the deploy role under role/e???????????????-*. Not attached to the deploy role itself.',
  path: '/',
  policy: fs.readFileSync(path.join(repoRoot, 'EntHomeAccess.boundary.json'), 'utf-8'),
});

/**
 * Opt-in privilege-escalation guard (PLA-6063): the BoundaryGuard policy JSON rendered from
 * EntHomeAccess.boundary-guard.json, or undefined when boundaryArn is empty. Every role ent-platform
 * creates falls under the e???????????????-* glob, so turn it on only once Ent Home sends the same
 * boundary ARN for the tenant. See the README.
 */
export function boundaryGuardPolicy(p: string, boundaryArn: string): string | undefined {
  if (!boundaryArn) {
    return undefined;
  }
  return fs
    .readFileSync(path.join(repoRoot, 'EntHomeAccess.boundary-guard.json'), 'utf-8')
    .replaceAll('arn:aws:', `arn:${p}:`)
    .replaceAll('<PERMISSIONS_BOUNDARY_ARN>', boundaryArn);
}

export const guards = permissionsBoundaryArn
  ? [
      new aws.iam.Policy('EntHomeAccessBoundaryGuard', {
        name: `${policyNamePrefix}BoundaryGuard`,
        description: policyDescription,
        path: '/',
        policy: partition.apply((p) => boundaryGuardPolicy(p, permissionsBoundaryArn)!),
      }),
    ]
  : [];

export const role = new aws.iam.Role('EntDeployRole', {
  name: roleName,
  path: rolePath,
  description: roleDescription,
  assumeRolePolicy: trustJson,
  tags,
});

// One attachment per functional policy.
export const attachments = policies.map(
  (policy, i) =>
    new aws.iam.RolePolicyAttachment(`EntDeployRoleAttachment${POLICY_FILES[i][1]}`, {
      role: role.name,
      policyArn: policy.arn,
    }),
).concat(
  guards.map(
    (guard) =>
      new aws.iam.RolePolicyAttachment('EntDeployRoleAttachmentBoundaryGuard', {
        role: role.name,
        policyArn: guard.arn,
      }),
  ),
);

export const roleArn = role.arn;
export const policyArns = policies.map((p) => p.arn);
// Backward-compat single ARN: EntHomeAccessSecurity. Deprecated — use policyArns.
export const policyArn = policies[POLICY_FILES.findIndex(([, s]) => s === COMPAT_POLICY_SUFFIX)].arn;
export const boundaryPolicyArn = boundaryPolicy.arn;
