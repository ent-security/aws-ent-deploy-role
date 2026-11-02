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

  it('creates a separate boundary policy not attached to the role', (done) => {
    // The boundary policy caps roles the deploy role creates -- it must not be
    // attached to the deploy role, so it lives outside the `policies` array.
    assert.strictEqual(infra.policies.length, 4);
    infra.boundaryPolicy.name.apply((name: string | undefined) => {
      try {
        assert.strictEqual(name, 'EntHomeAccessBoundary');
        done();
      } catch (e) {
        done(e);
      }
    });
  });

  it('does not set or attach the boundary on the deploy role', (done) => {
    // Setting the boundary on the deploy role (or attaching it as a managed policy) would cap the
    // deploy role's own iam:*/sts:AssumeRole access. Assert the role carries no boundary and its
    // registered attachments are exactly the four functional policies.
    pulumi
      .all([
        infra.boundaryPolicy.arn,
        infra.role.permissionsBoundary,
        pulumi.all(infra.policies.map((p) => p.arn)),
        // Wait for every attachment to register before reading `registered`.
        pulumi.all(infra.attachments.map((a) => a.policyArn)),
      ])
      .apply(([boundaryArn, permissionsBoundary, functionalArns]) => {
        try {
          assert.strictEqual(permissionsBoundary, undefined);
          const attached = registered
            .filter((r) => r.type === 'aws:iam/rolePolicyAttachment:RolePolicyAttachment')
            .map((r) => r.inputs.policyArn as string);
          assert.ok(!attached.includes(boundaryArn), 'boundary policy must not be attached to the deploy role');
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
});
