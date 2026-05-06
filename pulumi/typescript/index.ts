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

// Resolve repo root: pulumi/typescript/ -> pulumi/ -> repo root
const repoRoot = path.resolve(__dirname, '..', '..');
const policyJson = fs.readFileSync(path.join(repoRoot, 'policy.json'), 'utf-8');
const trustJson = fs
  .readFileSync(path.join(repoRoot, 'role.json'), 'utf-8')
  .replaceAll('<ENT_AWS_ACCOUNT_ARN>', entAwsAccountArn);

export const policy = new aws.iam.Policy('EntHomeAccess', {
  name: 'EntHomeAccess',
  description:
    'Custom policy for permissions needed by Ent Home to deploy and manage resources in customer accounts. This policy is attached to the role that Ent Home assumes when deploying resources in customer accounts.',
  path: '/',
  policy: policyJson,
});

export const role = new aws.iam.Role('EntDeployRole', {
  name: roleName,
  path: rolePath,
  description: roleDescription,
  assumeRolePolicy: trustJson,
  tags,
});

new aws.iam.RolePolicyAttachment('EntDeployRoleAttachment', {
  role: role.name,
  policyArn: policy.arn,
});

export const roleArn = role.arn;
export const policyArn = policy.arn;
