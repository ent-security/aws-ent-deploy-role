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
  entAwsAccountArn: 'arn:aws:iam::000000000000:root',
  roleName: 'HomeProdAssumeAdmin',
  rolePath: '/',
  roleDescription: 'Role that allows Ent Home to assume AdministratorAccess role',
  policyName: 'EntHomeAccess',
  policyDescription:
    'Custom policy for permissions needed by Ent Home to deploy and manage resources in customer accounts. This policy is attached to the role that Ent Home assumes when deploying resources in customer accounts.',
};

export class EntDeployRoleStack extends cdk.Stack {
  public readonly roleArn: string;
  public readonly roleName: string;
  public readonly policyArn: string;

  constructor(scope: Construct, id: string, props: EntDeployRoleStackProps = {}) {
    super(scope, id, props);

    const entAwsAccountArn = props.entAwsAccountArn ?? DEFAULTS.entAwsAccountArn;
    const roleName = props.roleName ?? DEFAULTS.roleName;
    const rolePath = props.rolePath ?? DEFAULTS.rolePath;
    const roleDescription = props.roleDescription ?? DEFAULTS.roleDescription;

    // Resolve repo root: cdk/typescript/lib/ -> cdk/typescript/ -> cdk/ -> repo root
    const repoRoot = path.resolve(__dirname, '..', '..', '..');
    const policyJson = JSON.parse(fs.readFileSync(path.join(repoRoot, 'policy.json'), 'utf-8'));
    const trustJsonRaw = fs.readFileSync(path.join(repoRoot, 'role.json'), 'utf-8');
    const trustJson = JSON.parse(trustJsonRaw.replaceAll('<ENT_AWS_ACCOUNT_ARN>', entAwsAccountArn));

    const managedPolicy = new iam.CfnManagedPolicy(this, 'EntHomeAccessPolicy', {
      managedPolicyName: DEFAULTS.policyName,
      description: DEFAULTS.policyDescription,
      path: '/',
      policyDocument: policyJson,
    });

    const role = new iam.CfnRole(this, 'EntDeployRole', {
      roleName,
      path: rolePath,
      description: roleDescription,
      assumeRolePolicyDocument: trustJson,
      managedPolicyArns: [managedPolicy.ref],
      tags: props.entTags
        ? Object.entries(props.entTags).map(([key, value]) => ({ key, value }))
        : undefined,
    });

    this.roleArn = role.attrArn;
    this.roleName = role.ref;
    this.policyArn = managedPolicy.ref;

    new cdk.CfnOutput(this, 'RoleArn', { value: this.roleArn });
    new cdk.CfnOutput(this, 'RoleName', { value: this.roleName });
    new cdk.CfnOutput(this, 'PolicyArn', { value: this.policyArn });
  }
}
