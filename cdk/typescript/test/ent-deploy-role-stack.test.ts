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

  test('creates a managed policy named EntHomeAccess', () => {
    const template = makeTemplate();
    template.hasResourceProperties('AWS::IAM::ManagedPolicy', {
      ManagedPolicyName: 'EntHomeAccess',
    });
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
});
