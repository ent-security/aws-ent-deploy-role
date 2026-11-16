import * as assert from 'assert';

process.env.PULUMI_NODEJS_PROJECT = 'ent-deploy-role';
process.env.PULUMI_NODEJS_STACK = 'test';
process.env.PULUMI_CONFIG = JSON.stringify({
  'ent-deploy-role:entAwsAccountArn': 'arn:aws:iam::123456789012:root',
});

// eslint-disable-next-line import/first
import * as pulumi from '@pulumi/pulumi';

// Inputs of every resource registered with the mocks, so tests can assert what was actually wired
// up (e.g. every RolePolicyAttachment) rather than only what the module exposes.
const registered: { type: string; inputs: Record<string, unknown> }[] = [];

pulumi.runtime.setMocks(
  {
    newResource: (args: pulumi.runtime.MockResourceArgs) => {
      registered.push({ type: args.type, inputs: args.inputs });
      return {
        id: `${args.name}_id`,
        state: { ...args.inputs, arn: `arn:aws:iam::123456789012:${args.type}/${args.name}` },
      };
    },
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

  it('creates the four functional managed policies', (done) => {
    // The permission set is split across four functional managed policies, all attached to the role.
    assert.strictEqual(infra.policies.length, 4);
    pulumi
      .all(infra.policies.map((p) => p.name))
      .apply((names: (string | undefined)[]) => {
        try {
          assert.deepStrictEqual(
            [...names].sort(),
            ['EntHomeAccessCompute', 'EntHomeAccessData', 'EntHomeAccessPlatform', 'EntHomeAccessSecurity'],
          );
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

  it('does not set or attach the boundary on the deploy role', (done) => {
    // A boundary on the deploy role itself would cap its own iam:*/sts:AssumeRole access. Assert the
    // role carries none and, with the guard off, its registered attachments are exactly the four
    // functional policies.
    pulumi
      .all([
        infra.role.permissionsBoundary,
        pulumi.all(infra.policies.map((p) => p.arn)),
        // Wait for every attachment to register before reading `registered`.
        pulumi.all(infra.attachments.map((a) => a.policyArn)),
      ])
      .apply(([permissionsBoundary, functionalArns]) => {
        try {
          assert.strictEqual(permissionsBoundary, undefined);
          const attached = registered
            .filter((r) => r.type === 'aws:iam/rolePolicyAttachment:RolePolicyAttachment')
            .map((r) => r.inputs.policyArn as string);
          assert.deepStrictEqual([...attached].sort(), [...functionalArns].sort());
          done();
        } catch (e) {
          done(e);
        }
      });
  });

  it('rewrites policy ARNs to the deploy partition', (done) => {
    // The S3 statement lives in the Data & Storage functional policy (index 1). Assert its ARNs are
    // rewritten to the deploy partition rather than left as the commercial `aws` partition.
    const dataPolicy = infra.policies[1];
    dataPolicy.policy.apply((policyStr: string | undefined) => {
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

  it('creates no guard policy by default', () => {
    assert.strictEqual(infra.guards.length, 0);
    assert.strictEqual(infra.boundaryGuardPolicy('aws', ''), undefined);
  });

  it('renders the boundary guard fragment with the partition and ARN substituted', () => {
    const rendered = infra.boundaryGuardPolicy(
      'aws-us-gov',
      'arn:aws-us-gov:iam::123456789012:policy/CustomerWorkloadBoundary',
    )!;
    const enforcement = JSON.parse(rendered).Statement[0];
    assert.strictEqual(enforcement.Resource, 'arn:aws-us-gov:iam::*:role/e???????????????-*');
    assert.strictEqual(
      enforcement.Condition.StringNotEquals['iam:PermissionsBoundary'],
      'arn:aws-us-gov:iam::123456789012:policy/CustomerWorkloadBoundary',
    );
    assert.ok(!rendered.includes('<'));
  });

  it('rejects a boundary ARN that is not a policy', () => {
    assert.throws(() => infra.boundaryGuardPolicy('aws', 'arn:aws:iam::123456789012:role/NotAPolicy'), /IAM policy ARN/);
  });
});
