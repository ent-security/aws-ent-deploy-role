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

// Policy ARNs of every RolePolicyAttachment registered against the named role.
const attachedTo = (roleName: string): string[] =>
  registered
    .filter((r) => r.type === 'aws:iam/rolePolicyAttachment:RolePolicyAttachment' && r.inputs.role === roleName)
    .map((r) => r.inputs.policyArn as string);

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
  let infra: typeof import('../infra');

  before(() => {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    infra = require('../infra');
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
          const attached = attachedTo('HomeProdAssumeAdmin');
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

  it('exports only the stack outputs from the entrypoint', () => {
    // Every index.ts export becomes a stack output; test hooks (guards, attachments, the renderer)
    // must stay in infra.ts so the guard-off stack keeps the outputs it had.
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    assert.deepStrictEqual(Object.keys(require('../index')).sort(), [
      'policies',
      'policyArn',
      'policyArns',
      'role',
      'roleArn',
    ]);
  });
});

describe('EntDeployRole (Pulumi TS) with permissionsBoundaryArn set', () => {
  const boundaryArn = 'arn:aws:iam::123456789012:policy/CustomerWorkloadBoundary';
  let guarded: typeof import('../infra');

  before(() => {
    // Config is read when the program loads, so load a second copy with the guard on. A distinct
    // role name keeps its attachments apart from the guard-off copy's in `registered`.
    pulumi.runtime.setConfig('ent-deploy-role:permissionsBoundaryArn', boundaryArn);
    pulumi.runtime.setConfig('ent-deploy-role:roleName', 'GuardedRole');
    delete require.cache[require.resolve('../infra')];
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    guarded = require('../infra');
  });

  it('creates the guard policy, attaches it, and lists it in policyArns', (done) => {
    assert.strictEqual(guarded.guards.length, 1);
    pulumi
      .all([
        guarded.guards[0].arn,
        guarded.guards[0].policy,
        pulumi.all(guarded.policies.map((p) => p.arn)),
        pulumi.all(guarded.policyArns),
        // Wait for every attachment to register before reading `registered`.
        pulumi.all(guarded.attachments.map((a) => a.policyArn)),
      ])
      .apply(([guardArn, guardPolicy, functionalArns, policyArns]) => {
        try {
          assert.ok(guardPolicy.includes(boundaryArn), 'guard policy should carry the boundary ARN');
          assert.deepStrictEqual(policyArns, [...functionalArns, guardArn]);
          assert.deepStrictEqual(attachedTo('GuardedRole').sort(), [...functionalArns, guardArn].sort());
          done();
        } catch (e) {
          done(e);
        }
      });
  });
});
