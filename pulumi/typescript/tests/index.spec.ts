import * as assert from 'assert';

process.env.PULUMI_NODEJS_PROJECT = 'ent-deploy-role';
process.env.PULUMI_NODEJS_STACK = 'test';
process.env.PULUMI_CONFIG = JSON.stringify({
  'ent-deploy-role:entAwsAccountArn': 'arn:aws:iam::123456789012:root',
});

// eslint-disable-next-line import/first
import * as pulumi from '@pulumi/pulumi';

pulumi.runtime.setMocks(
  {
    newResource: (args: pulumi.runtime.MockResourceArgs) => ({
      id: `${args.name}_id`,
      state: { ...args.inputs, arn: `arn:aws:iam::123456789012:${args.type}/${args.name}` },
    }),
    // aws.getPartition() — return a non-commercial partition so the test proves
    // the policy ARNs are rewritten dynamically rather than left as `aws`.
    call: (args: pulumi.runtime.MockCallArgs) => ({ ...args.inputs, partition: 'aws-us-gov' }),
  },
  'ent-deploy-role',
  'test',
  false,
);

describe('EntDeployRole (Pulumi TS)', () => {
  let infra: typeof import('../index');

  before(() => {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    infra = require('../index');
  });

  it('creates a managed policy named EntHomeAccess', (done) => {
    infra.policy.name.apply((name: string) => {
      try {
        assert.strictEqual(name, 'EntHomeAccess');
        done();
      } catch (e) {
        done(e);
      }
    });
  });

  it('creates a role named HomeProdAssumeAdmin by default', (done) => {
    infra.role.name.apply((name: string) => {
      try {
        assert.strictEqual(name, 'HomeProdAssumeAdmin');
        done();
      } catch (e) {
        done(e);
      }
    });
  });

  it('substitutes the account ARN in the trust policy', (done) => {
    infra.role.assumeRolePolicy.apply((policyStr: string | undefined) => {
      try {
        assert.ok(
          policyStr && policyStr.includes('arn:aws:iam::123456789012:root'),
          `expected trust policy to contain configured ARN, got: ${policyStr}`,
        );
        done();
      } catch (e) {
        done(e);
      }
    });
  });

  it('rewrites policy ARNs to the deploy partition', (done) => {
    infra.policy.policy.apply((policyStr: string | undefined) => {
      try {
        assert.ok(
          policyStr && policyStr.includes('arn:aws-us-gov:s3:::'),
          `expected gov-partition ARNs, got: ${policyStr}`,
        );
        assert.ok(
          !policyStr!.includes('arn:aws:s3:::'),
          'commercial-partition ARN should have been rewritten',
        );
        done();
      } catch (e) {
        done(e);
      }
    });
  });
});
