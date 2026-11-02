import * as fs from 'fs';
import * as path from 'path';
import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export interface EntDeployRoleStackProps extends cdk.StackProps {
  readonly entAwsAccountArn?: string;
  readonly roleName?: string;
  readonly rolePath?: string;
  readonly roleDescription?: string;
  readonly entTags?: { [key: string]: string };
}

const DEFAULTS = {
  entAwsAccountArn: 'arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005',
  roleName: 'HomeProdAssumeAdmin',
  rolePath: '/',
  roleDescription: 'Role that allows Ent Home to assume AdministratorAccess role',
  policyNamePrefix: 'EntHomeAccess',
  policyDescription:
    'Custom policy for permissions needed by Ent Home to deploy and manage resources in customer accounts. This policy is attached to the role that Ent Home assumes when deploying resources in customer accounts.',
};

// The permission set is split across four functional managed policies so each stays under AWS's
// 6144-character managed-policy limit. Each entry is [authoritative file, name suffix]; the policy
// is named `${prefix}${suffix}` (default EntHomeAccess{Compute,Data,Security,Platform}). The union
// of the four is the complete permission set. Keep this in lockstep with the Terraform
// statement_group map and the files.
const POLICY_FILES: ReadonlyArray<readonly [string, string]> = [
  ['EntHomeAccess.compute-network.json', 'Compute'],
  ['EntHomeAccess.data-storage.json', 'Data'],
  ['EntHomeAccess.identity-security.json', 'Security'],
  ['EntHomeAccess.observability-platform.json', 'Platform'],
];

// Index of the functional policy whose ARN backs the deprecated single-ARN `policyArn` output.
const COMPAT_POLICY_INDEX = POLICY_FILES.findIndex(([, suffix]) => suffix === 'Security');

export class EntDeployRoleStack extends cdk.Stack {
  public readonly roleArn: string;
  public readonly roleName: string;
  public readonly policyArns: string[];
  /** @deprecated The full permission set spans four policies — use policyArns. Points at EntHomeAccessSecurity. */
  public readonly policyArn: string;
  public readonly boundaryPolicyArn: string;

  constructor(scope: Construct, id: string, props: EntDeployRoleStackProps = {}) {
    super(scope, id, props);

    const entAwsAccountArn = props.entAwsAccountArn ?? DEFAULTS.entAwsAccountArn;
    const roleName = props.roleName ?? DEFAULTS.roleName;
    const rolePath = props.rolePath ?? DEFAULTS.rolePath;
    const roleDescription = props.roleDescription ?? DEFAULTS.roleDescription;

    // Resolve repo root: cdk/typescript/lib/ -> cdk/typescript/ -> cdk/ -> repo root
    const repoRoot = path.resolve(__dirname, '..', '..', '..');
    // The functional policy files hold the canonical (commercial) `arn:aws:` ARNs. Rewrite the
    // partition to the AWS::Partition pseudo-param so the synthesized policies work in commercial
    // and GovCloud (aws-us-gov) alike. Each file becomes its own managed policy, mirroring the
    // Terraform module.
    const managedPolicies = POLICY_FILES.map(([filename, suffix]) => {
      const policyRaw = fs.readFileSync(path.join(repoRoot, filename), 'utf-8');
      const policyJson = JSON.parse(policyRaw.replaceAll('arn:aws:', `arn:${cdk.Aws.PARTITION}:`));
      return new iam.CfnManagedPolicy(this, `EntHomeAccess${suffix}Policy`, {
        managedPolicyName: `${DEFAULTS.policyNamePrefix}${suffix}`,
        description: DEFAULTS.policyDescription,
        path: '/',
        policyDocument: policyJson,
      });
    });

    // Permissions boundary for IAMBoundaryEnforcement (in EntHomeAccess.identity-security.json).
    // NOT attached to the deploy role itself below -- it would strip the deploy role's own
    // iam:*/sts:AssumeRole grants on the glob, breaking it. It exists only to be referenced by ARN
    // when the deploy role creates a new role under role/e???????????????-*, capping that new
    // role's effective permissions regardless of what policy gets attached to it. No partition
    // rewrite needed: its Action/Resource entries carry no ARNs.
    const boundaryJson = JSON.parse(fs.readFileSync(path.join(repoRoot, 'EntHomeAccess.boundary.json'), 'utf-8'));
    const boundaryPolicy = new iam.CfnManagedPolicy(this, 'EntHomeAccessBoundaryPolicy', {
      managedPolicyName: `${DEFAULTS.policyNamePrefix}Boundary`,
      description:
        'Permissions boundary for IAM roles created by the deploy role under role/e???????????????-*. Not attached to the deploy role itself.',
      path: '/',
      policyDocument: boundaryJson,
    });

    const trustJsonRaw = fs.readFileSync(path.join(repoRoot, 'role.json'), 'utf-8');
    const trustJson = JSON.parse(trustJsonRaw.replaceAll('<ENT_AWS_ACCOUNT_ARN>', entAwsAccountArn));

    const role = new iam.CfnRole(this, 'EntDeployRole', {
      roleName,
      path: rolePath,
      description: roleDescription,
      assumeRolePolicyDocument: trustJson,
      managedPolicyArns: managedPolicies.map((p) => p.ref),
      tags: props.entTags
        ? Object.entries(props.entTags).map(([key, value]) => ({ key, value }))
        : undefined,
    });

    this.roleArn = role.attrArn;
    this.roleName = role.ref;
    this.policyArns = managedPolicies.map((p) => p.ref);
    // Backward-compat single ARN: EntHomeAccessSecurity. Deprecated — use policyArns.
    this.policyArn = managedPolicies[COMPAT_POLICY_INDEX].ref;
    this.boundaryPolicyArn = boundaryPolicy.ref;

    new cdk.CfnOutput(this, 'RoleArn', { value: this.roleArn });
    new cdk.CfnOutput(this, 'RoleName', { value: this.roleName });
    this.policyArns.forEach((arn, i) =>
      new cdk.CfnOutput(this, `PolicyArn${POLICY_FILES[i][1]}`, { value: arn }),
    );
    // Deprecated compat output, retained so existing references keep resolving.
    new cdk.CfnOutput(this, 'PolicyArn', { value: this.policyArn });
    new cdk.CfnOutput(this, 'PolicyArnBoundary', { value: this.boundaryPolicyArn });
  }
}
