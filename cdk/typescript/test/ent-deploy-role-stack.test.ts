import * as cdk from 'aws-cdk-lib';
import { Match, Template } from 'aws-cdk-lib/assertions';
import { EntDeployRoleStack, EntDeployRoleStackProps } from '../lib/ent-deploy-role-stack';

describe('EntDeployRoleStack', () => {
  const makeTemplate = (props: Partial<EntDeployRoleStackProps> = {}) => {
    const app = new cdk.App();
    const stack = new EntDeployRoleStack(app, 'TestStack', {
      entAwsAccountArn: 'arn:aws:iam::123456789012:root',
      ...props,
    });
    return Template.fromStack(stack);
  };

  test('creates the four functional managed policies plus the boundary policy', () => {
    const template = makeTemplate();
    // Four functional managed policies (all attached to the role) plus the boundary policy.
    template.resourceCountIs('AWS::IAM::ManagedPolicy', 5);
    for (const name of [
      'EntHomeAccessCompute',
      'EntHomeAccessData',
      'EntHomeAccessSecurity',
      'EntHomeAccessPlatform',
      'EntHomeAccessBoundary',
    ]) {
      template.hasResourceProperties('AWS::IAM::ManagedPolicy', {
        ManagedPolicyName: name,
      });
    }
  });

  test('attaches only the four functional managed policies to the role', () => {
    const template = makeTemplate();
    const policies = template.findResources('AWS::IAM::ManagedPolicy', {
      Properties: Match.objectLike({ ManagedPolicyName: Match.not('EntHomeAccessBoundary') }),
    });
    const policyRefs = Object.keys(policies).map((logicalId) => ({ Ref: logicalId }));
    expect(policyRefs).toHaveLength(4);
    template.hasResourceProperties('AWS::IAM::Role', {
      ManagedPolicyArns: Match.arrayWith(policyRefs),
    });
    const role = template.findResources('AWS::IAM::Role');
    const [roleProps] = Object.values(role).map((r: any) => r.Properties);
    expect(roleProps.ManagedPolicyArns).toHaveLength(4);
  });

  test('creates a role with the default name HomeProdAssumeAdmin', () => {
    const template = makeTemplate();
    template.hasResourceProperties('AWS::IAM::Role', {
      RoleName: 'HomeProdAssumeAdmin',
    });
  });

  test('substitutes the configured account ARN into the trust policy', () => {
    const template = makeTemplate();
    template.hasResourceProperties('AWS::IAM::Role', {
      AssumeRolePolicyDocument: Match.objectLike({
        Statement: Match.arrayWith([
          Match.objectLike({
            Principal: { AWS: 'arn:aws:iam::123456789012:root' },
          }),
        ]),
      }),
    });
  });

  test('honors role_name override', () => {
    const template = makeTemplate({ roleName: 'CustomRoleName' });
    template.hasResourceProperties('AWS::IAM::Role', {
      RoleName: 'CustomRoleName',
    });
  });

  test('parameterizes policy ARNs by partition for GovCloud compatibility', () => {
    const template = makeTemplate();
    const json = JSON.stringify(template.toJSON());
    // Permission-policy ARNs must resolve the partition via the AWS::Partition
    // pseudo-param rather than hardcoding the commercial `aws` partition.
    expect(json).toContain('AWS::Partition');
    expect(json).not.toContain('arn:aws:athena');
  });
});
